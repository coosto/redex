defmodule Redex.Command.FlushallTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Redex.DataGenerators
  import Redex.Command.FLUSHALL

  setup :verify_on_exit!

  property "FLUSHALL" do
    check all state <- state(),
              nodes <- nodes(state) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)
      |> expect(:clear_table, fn :redex -> {:atomic, :ok} end)

      ProtocolMock
      |> expect(:reply, fn :ok, ^state -> state end)

      assert state == exec([], state)
    end
  end

  property "FLUSHALL in readonly mode" do
    error = {:error, "READONLY You can't write against a read only replica."}

    check all state <- state(),
              nodes <- nodes(state, readonly: true) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)

      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec([], state)
    end
  end

  property "FLUSHALL with wrong number of arguments" do
    error = {:error, "ERR syntax error"}

    check all args <- list_of(binary(), min_length: 1),
              state <- state() do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec(args, state)
    end
  end
end
