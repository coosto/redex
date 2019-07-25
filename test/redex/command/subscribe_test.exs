defmodule Redex.Command.SubscribeTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Redex.DataGenerators
  import Redex.Command.SUBSCRIBE

  setup :verify_on_exit!

  property "SUBSCRIBE to some channels" do
    check all state <- state(channels: true),
              channels <- list_of(binary(), min_length: 1) do
      new_state =
        for ch <- channels, reduce: state do
          state = %{channels: channels} ->
            channels =
              if ch in channels do
                channels
              else
                Pg2Mock
                |> expect(:create, fn ^ch -> :ok end)
                |> expect(:join, fn ^ch, pid when pid == self() -> :ok end)

                [ch | channels]
              end

            state = %{state | channels: channels}
            subscribed = length(channels)

            ProtocolMock
            |> expect(:reply, fn ["subscribe", ^ch, ^subscribed], ^state -> state end)

            state
        end

      assert new_state == exec(channels, state)
    end
  end

  test "SUBSCRIBE with wrong number of arguments" do
    error = {:error, "ERR wrong number of arguments for 'SUBSCRIBE' command"}

    state = state()

    ProtocolMock
    |> expect(:reply, fn ^error, ^state -> state end)

    assert state == exec([], state)
  end
end
