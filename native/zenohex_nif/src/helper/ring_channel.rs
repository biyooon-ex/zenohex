use std::collections::VecDeque;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Condvar, Mutex};

/// A drop-oldest-when-full channel, mirroring `zenoh::handlers::RingChannel`
/// semantics but with a `Clone`-able handler, since `RingChannelHandler` only
/// holds a `Weak` reference and isn't `Clone`, which doesn't fit the
/// declare-then-clone-into-forwarder architecture used for `FifoChannel`.
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
    capacity: usize,
    closed: AtomicBool,
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
        }
        buffer.push_back(item);
        drop(buffer);
        self.inner.not_empty.notify_one();
    }
}

impl<T> Drop for RingSender<T> {
    fn drop(&mut self) {
        self.inner.closed.store(true, Ordering::Release);
        self.inner.not_empty.notify_all();
    }
}

impl<T: Send + 'static> zenoh::handlers::IntoHandler<T> for RingChannel {
    type Handler = RingChannelHandler<T>;

    fn into_handler(self) -> (zenoh::handlers::Callback<T>, Self::Handler) {
        let inner = Arc::new(RingInner {
            buffer: Mutex::new(VecDeque::with_capacity(self.capacity)),
            not_empty: Condvar::new(),
            capacity: self.capacity,
            closed: AtomicBool::new(false),
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
