defmodule Redex.CommandTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Redex.DataGenerators

  alias Redex.Command

  setup :verify_on_exit!

  property "exec an unknown command" do
    check all state <- state(),
              cmd <- list_of(binary()) do
      if cmd != [] do
        error = {:error, "ERR unknown command '#{hd(cmd)}'"}

        ProtocolMock
        |> expect(:reply, fn ^error, ^state -> state end)
      end

      assert state == Command.exec(cmd, state)
    end
  end

  test "exec a valid command" do
    state = state() |> Enum.at(0)

    ProtocolMock
    |> expect(:reply, 3, fn :pong, ^state -> state end)

    assert state == Command.exec(["PING"], state)
    assert state == Command.exec(["ping"], state)
    assert state == Command.exec(["Ping"], state)
  end
end
