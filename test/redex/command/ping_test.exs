defmodule Redex.Command.PingTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Redex.DataGenerators
  import Redex.Command.PING

  setup :verify_on_exit!

  property "PING without message" do
    check all state <- state() do
      ProtocolMock
      |> expect(:reply, fn :pong, ^state -> state end)

      assert state == exec([], state)
    end
  end

  property "PING with message" do
    check all state <- state(),
              message <- binary() do
      ProtocolMock
      |> expect(:reply, fn ^message, ^state -> state end)

      assert state == exec([message], state)
    end
  end

  property "PING with wrong number of arguments" do
    error = {:error, "ERR wrong number of arguments for 'PING' command"}

    check all state <- state(),
              args <- list_of(binary(), min_length: 2) do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec(args, state)
    end
  end
end
