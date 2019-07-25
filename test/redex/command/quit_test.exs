defmodule Redex.Command.QuitTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Redex.DataGenerators
  import Redex.Command.QUIT

  setup :verify_on_exit!

  property "QUIT" do
    check all state <- state(),
              args <- list_of(binary()) do
      ProtocolMock
      |> expect(:reply, fn :ok, ^state -> state end)

      TransportMock
      |> expect(:close, fn :socket -> :ok end)

      assert state == exec(args, state)
    end
  end
end
