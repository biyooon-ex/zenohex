use std::collections::VecDeque;
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::{Arc, Condvar, Mutex};

/// A drop-oldest-when-full channel, mirroring `zenoh::handlers::RingChannel`
/// semantics but with a `Clone`-able handler so it fits the same
/// declare-then-clone-into-forwarder architecture used for `FifoChannel`.
///
/// WHY not use `zenoh::handlers::RingChannelHandler` directly: it only holds a
/// `Weak` reference and does not implement `Clone`, so it cannot be handed to
/// a separate forwarder while the `Subscriber` (holding the strong reference)
/// is stored elsewhere. See PR #217 discussion.
pub struct RingChannel {
    capacity: usize,
}

impl RingChannel {
    pub fn new(capacity: usize) -> Self {
        Self { capacity }
    }
}

struct RingInner<T> {
    buffer: Mutex<VecDeque<T>>,
    not_empty: Condvar,
    // WHY: separate from `not_empty` because async and blocking consumers use
    //      different wait mechanisms; a single consumer uses only one of them.
    not_empty_async: tokio::sync::Notify,
    capacity: usize,
    closed: AtomicBool,
    // WHY: diagnostic-only counter so callers can observe drop-oldest evictions
    //      directly, instead of inferring drops from end-to-end message loss
    //      (which also includes unrelated causes, e.g. Zenoh transport loss).
    dropped: AtomicUsize,
}

pub struct RingChannelHandler<T> {
    inner: Arc<RingInner<T>>,
}

impl<T> Clone for RingChannelHandler<T> {
    fn clone(&self) -> Self {
        Self {
            inner: self.inner.clone(),
        }
    }
}

impl<T> RingChannelHandler<T> {
    /// Blocking iterator, ending once the sender side (the Zenoh callback) is
    /// dropped, e.g. via `undeclare`. Mirrors `FifoChannelHandler::iter`.
    pub fn iter(&self) -> RingIter<'_, T> {
        RingIter {
            inner: &self.inner,
        }
    }

    /// Async counterpart to `iter`, for use on a tokio runtime. Returns `None`
    /// once the sender side is dropped. Mirrors `FifoChannelHandler::recv_async`.
    pub async fn recv_async(&self) -> Option<T> {
        loop {
            // WHY: create the `Notified` future before checking the buffer, so a
            //      `notify_one` from `send`/`Drop` that races with this check is
            //      not lost (tokio stores it as a permit for this waiter).
            let notified = self.inner.not_empty_async.notified();
            {
                let mut buffer = self.inner.buffer.lock().unwrap();
                if let Some(item) = buffer.pop_front() {
                    return Some(item);
                }
                if self.inner.closed.load(Ordering::Acquire) {
                    return None;
                }
            }
            notified.await;
        }
    }

    /// Diagnostic-only: number of items currently buffered.
    pub fn len(&self) -> usize {
        self.inner.buffer.lock().unwrap().len()
    }

    /// Diagnostic-only: total items evicted by drop-oldest so far.
    pub fn dropped_count(&self) -> usize {
        self.inner.dropped.load(Ordering::Relaxed)
    }
}

pub struct RingIter<'a, T> {
    inner: &'a Arc<RingInner<T>>,
}

impl<T> Iterator for RingIter<'_, T> {
    type Item = T;

    fn next(&mut self) -> Option<T> {
        let mut buffer = self.inner.buffer.lock().unwrap();
        loop {
            if let Some(item) = buffer.pop_front() {
                return Some(item);
            }
            if self.inner.closed.load(Ordering::Acquire) {
                return None;
            }
            buffer = self.inner.not_empty.wait(buffer).unwrap();
        }
    }
}

/// Sole owner of the producer side; its `Drop` marks the channel closed so
/// `RingIter` stops blocking instead of waiting forever.
struct RingSender<T> {
    inner: Arc<RingInner<T>>,
}

impl<T> RingSender<T> {
    fn send(&self, item: T) {
        let mut buffer = self.inner.buffer.lock().unwrap();
        // WHY: never block the caller (the Zenoh callback thread). Drop the
        // oldest sample instead, preserving order for what remains.
        if buffer.len() >= self.inner.capacity {
            buffer.pop_front();
            self.inner.dropped.fetch_add(1, Ordering::Relaxed);
        }
        buffer.push_back(item);
        drop(buffer);
        self.inner.not_empty.notify_one();
        self.inner.not_empty_async.notify_one();
    }
}

impl<T> Drop for RingSender<T> {
    fn drop(&mut self) {
        self.inner.closed.store(true, Ordering::Release);
        self.inner.not_empty.notify_all();
        self.inner.not_empty_async.notify_one();
    }
}

impl<T: Send + 'static> zenoh::handlers::IntoHandler<T> for RingChannel {
    type Handler = RingChannelHandler<T>;

    fn into_handler(self) -> (zenoh::handlers::Callback<T>, Self::Handler) {
        let inner = Arc::new(RingInner {
            buffer: Mutex::new(VecDeque::with_capacity(self.capacity)),
            not_empty: Condvar::new(),
            not_empty_async: tokio::sync::Notify::new(),
            capacity: self.capacity,
            closed: AtomicBool::new(false),
            dropped: AtomicUsize::new(0),
        });

        let sender = RingSender {
            inner: inner.clone(),
        };
        let handler = RingChannelHandler { inner };

        (
            zenoh::handlers::Callback::from(move |item: T| sender.send(item)),
            handler,
        )
    }
}
