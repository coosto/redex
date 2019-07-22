defmodule Redex.Command.GetsetTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Redex.DataGenerators
  import Redex.Command.GETSET

  setup :verify_on_exit!

  property "GETSET a non existing key" do
    check all state <- state(),
              nodes <- nodes(state),
              record = {:redex, {db, key}, value, _} <- record(state, expired: nil),
              no_record <- no_or_expired_record(state, key: key) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)
      |> expect(:sync_transaction, fn f -> {:atomic, f.()} end)
      |> expect(:read, fn :redex, {^db, ^key}, :write -> no_record end)
      |> expect(:write, fn :redex, ^record, :write -> :ok end)

      ProtocolMock
      |> expect(:reply, fn nil, ^state -> state end)

      assert state == exec([key, value], state)
    end
  end

  property "GETSET an existing key" do
    check all state <- state(),
              nodes <- nodes(state),
              old_record = {:redex, {db, key}, old_value, _} <- record(state),
              value <- binary() do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)
      |> expect(:sync_transaction, fn f -> {:atomic, f.()} end)
      |> expect(:read, fn :redex, {^db, ^key}, :write -> [old_record] end)
      |> expect(:write, fn :redex, {:redex, {^db, ^key}, ^value, nil}, :write -> :ok end)

      ProtocolMock
      |> expect(:reply, fn ^old_value, ^state -> state end)

      assert state == exec([key, value], state)
    end
  end

  property "GETSET a key in readonly mode" do
    error = {:error, "READONLY You can't write against a read only replica."}

    check all state <- state(),
              nodes <- nodes(state, readonly: true),
              {:redex, {_, key}, value, _} <- record(state) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)

      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec([key, value], state)
    end
  end

  property "GETSET a key with a wrong kind of value" do
    error = {:error, "WRONGTYPE Operation against a key holding the wrong kind of value"}

    check all state <- state(),
              nodes <- nodes(state),
              record = {:redex, {db, key}, _, _} <- record(state, type: :list),
              value <- binary() do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)
      |> expect(:sync_transaction, fn f -> {:atomic, f.()} end)
      |> expect(:read, fn :redex, {^db, ^key}, :write -> [record] end)

      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec([key, value], state)
    end
  end

  property "GETSET with wrong number of arguments" do
    error = {:error, "ERR wrong number of arguments for 'GETSET' command"}

    check all args <- filter(list_of(binary()), &(length(&1) != 2)),
              state <- state() do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec(args, state)
    end
  end
end
