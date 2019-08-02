defmodule Redex.Command.MsetTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Redex.DataGenerators
  import Redex.Command.MSET

  setup :verify_on_exit!

  property "MSET key/value pairs" do
    check all state = %{db: db} <- state(),
              nodes <- nodes(state),
              keys <- list_of(binary(), min_length: 1),
              values <- list_of(binary(), length: length(keys)),
              pairs = Enum.zip(keys, values) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)
      |> expect(:sync_transaction, fn f -> {:atomic, f.()} end)

      for {key, value} <- pairs do
        MnesiaMock
        |> expect(:write, fn :redex, {:redex, {^db, ^key}, ^value, nil}, :write -> :ok end)
      end

      ProtocolMock
      |> expect(:reply, fn :ok, ^state -> state end)

      assert state == exec(Enum.flat_map(pairs, fn {k, v} -> [k, v] end), state)
    end
  end

  property "MSET in readonly mode" do
    error = {:error, "READONLY You can't write against a read only replica."}

    check all state <- state(),
              nodes <- nodes(state, readonly: true),
              pairs_count <- positive_integer(),
              args <- list_of(binary(), length: pairs_count * 2) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)

      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec(args, state)
    end
  end

  property "MSET with wrong number of arguments" do
    error = {:error, "ERR wrong number of arguments for 'MSET' command"}

    check all state <- state(),
              pairs_count <- positive_integer(),
              args <- list_of(binary(), length: pairs_count * 2 - 1) do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec(args, state)
    end
  end
end
