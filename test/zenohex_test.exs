defmodule ZenohexTestModeCommon do
  defmacro tests(mode) do
    quote do
      setup context do
        {:ok, session_id} =
          context.config
          |> Zenohex.Test.Support.TestHelper.mode(unquote(mode))
          |> Zenohex.Session.open()

        on_exit(fn -> Zenohex.Session.close(session_id) end)

        %{session_id: session_id}
      end

      test "pub/sub", %{session_id: session_id} do
        {:ok, subscriber_id} =
          Zenohex.Session.declare_subscriber(session_id, "key/expr", self())

        {:ok, publisher_id} = Zenohex.Session.declare_publisher(session_id, "key/expr")

        :ok = Zenohex.Publisher.put(publisher_id, "Hello Zenoh Dragon")

        assert_receive %Zenohex.Sample{
          encoding: "zenoh/bytes",
          key_expr: "key/expr",
          payload: "Hello Zenoh Dragon"
        }

        # WHY: Explicitly undeclare `subscriber_id`.
        #      Otherwise, the Elixir GC may release `subscriber_id` if it appears unused,
        #      which triggers Rust's `Drop`, so the callback is no longer called, and Samples stop being sent.
        :ok = Zenohex.Subscriber.undeclare(subscriber_id)
      end

      test "get/reply without ReplyError", %{session_id: session_id} do
        {:ok, queryable_id} = Zenohex.Session.declare_queryable(session_id, "key/expr", self())

        task =
          Task.async(Zenohex.Session, :get, [
            session_id,
            "key/expr/**",
            100,
            [attachment: <<0>>]
          ])

        assert_receive %Zenohex.Query{
          attachment: <<0>>,
          encoding: nil,
          key_expr: "key/expr/**",
          parameters: "",
          payload: nil,
          zenoh_query: zenoh_query
        }

        :ok = Zenohex.Query.reply(zenoh_query, "key/expr/1", <<1>>, final?: false)
        :ok = Zenohex.Query.reply(zenoh_query, "key/expr/2", <<2>>, final?: false)
        :ok = Zenohex.Query.reply_delete(zenoh_query, "key/expr/3", final?: true)

        assert {:ok, replies} = Task.await(task)

        # Check equality ignoring order
        assert MapSet.new(replies) ==
                 MapSet.new([
                   %Zenohex.Sample{
                     key_expr: "key/expr/1",
                     payload: <<1>>
                   },
                   %Zenohex.Sample{
                     key_expr: "key/expr/2",
                     payload: <<2>>
                   },
                   %Zenohex.Sample{
                     key_expr: "key/expr/3",
                     kind: :delete,
                     payload: ""
                   }
                 ])

        # WHY: Explicitly undeclare `queryable_id`.
        #      Otherwise, the Elixir GC may release `queryable_id` if it appears unused,
        #      which triggers Rust's `Drop`, so the callback is no longer called, and Query stop being sent.
        :ok = Zenohex.Queryable.undeclare(queryable_id)
      end

      test "get/reply with ReplyError", %{session_id: session_id} do
        {:ok, queryable_id} = Zenohex.Session.declare_queryable(session_id, "key/expr", self())

        task = Task.async(Zenohex.Session, :get, [session_id, "key/expr/**", 100])

        assert_receive %Zenohex.Query{
          encoding: nil,
          key_expr: "key/expr/**",
          parameters: "",
          payload: nil,
          zenoh_query: zenoh_query
        }

        :ok = Zenohex.Query.reply(zenoh_query, "key/expr/1", <<1>>, final?: false)
        :ok = Zenohex.Query.reply_error(zenoh_query, <<2>>, final?: false)
        :ok = Zenohex.Query.reply(zenoh_query, "key/expr/3", <<3>>, final?: true)

        assert {:ok, replies} = Task.await(task)

        # Check equality ignoring order
        assert MapSet.new(replies) ==
                 MapSet.new([
                   %Zenohex.Sample{
                     key_expr: "key/expr/1",
                     payload: <<1>>
                   },
                   %Zenohex.Query.ReplyError{
                     payload: <<2>>,
                     encoding: "zenoh/bytes"
                   },
                   %Zenohex.Sample{
                     key_expr: "key/expr/3",
                     payload: <<3>>
                   }
                 ])

        # WHY: Explicitly undeclare `queryable_id`.
        #      Otherwise, the Elixir GC may release `queryable_id` if it appears unused,
        #      which triggers Rust's `Drop`, so the callback is no longer called, and Query stop being sent.
        :ok = Zenohex.Queryable.undeclare(queryable_id)
      end
    end
  end
end

defmodule ZenohexTest do
  use ExUnit.Case

  require ZenohexTestModeCommon

  setup do
    config =
      Zenohex.Config.default()
      |> Zenohex.Test.Support.TestHelper.scouting_delay(0)

    %{config: config}
  end

  describe "peer mode" do
    ZenohexTestModeCommon.tests("peer")
  end

  describe "client mode with zenohd" do
    @describetag :skip
    ZenohexTestModeCommon.tests("client")
  end
end
