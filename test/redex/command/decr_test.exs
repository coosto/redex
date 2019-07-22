defmodule Redex.Command.DecrTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Redex.DataGenerators
  import Redex.Command.DECR

  setup :verify_on_exit!

  property "DECR a non existing or expired key" do
    check all state = %{db: db} <- state(),
              key <- binary(),
              nodes <- nodes(state),
              no_record <- no_or_expired_record(state, key: key) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)
      |> expect(:sync_transaction, fn f -> {:atomic, f.()} end)
      |> expect(:read, fn :redex, {^db, ^key}, :write -> no_record end)
      |> expect(:write, fn :redex, {:redex, {^db, ^key}, "-1", nil}, :write -> :ok end)

      ProtocolMock
      |> expect(:reply, fn -1, ^state -> state end)

      assert state == exec([key], state)
    end
  end

  property "DECR an existing key" do
    check all state <- state(),
              nodes <- nodes(state),
              record = {:redex, {db, key}, old_value, expiry} <- record(state, type: :int),
              new_value = String.to_integer(old_value) - 1,
              str_value = to_string(new_value) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)
      |> expect(:sync_transaction, fn f -> {:atomic, f.()} end)
      |> expect(:read, fn :redex, {^db, ^key}, :write -> [record] end)
      |> expect(:write, fn :redex, {:redex, {^db, ^key}, ^str_value, ^expiry}, :write -> :ok end)

      ProtocolMock
      |> expect(:reply, fn ^new_value, ^state -> state end)

      assert state == exec([key], state)
    end
  end

  property "DECR in readonly mode" do
    error = {:error, "READONLY You can't write against a read only replica."}

    check all state <- state(),
              nodes <- nodes(state, readonly: true),
              key <- binary() do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)

      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec([key], state)
    end
  end

  property "DECR a key with a wrong kind of value" do
    error = {:error, "WRONGTYPE Operation against a key holding the wrong kind of value"}

    check all state <- state(),
              nodes <- nodes(state),
              record = {:redex, {db, key}, _, _} <- record(state, type: :list) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)
      |> expect(:sync_transaction, fn f -> {:atomic, f.()} end)
      |> expect(:read, fn :redex, {^db, ^key}, :write -> [record] end)

      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec([key], state)
    end
  end

  property "DECR a key with a non integer value" do
    error = {:error, "ERR value is not an integer or out of range"}

    check all state <- state(),
              nodes <- nodes(state),
              record = {:redex, {db, key}, _, _} <- record(state, type: binary(min_length: 3)) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)
      |> expect(:sync_transaction, fn f -> {:atomic, f.()} end)
      |> expect(:read, fn :redex, {^db, ^key}, :write -> [record] end)

      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec([key], state)
    end
  end

  property "DECR with wrong number of arguments" do
    error = {:error, "ERR wrong number of arguments for 'DECR' command"}

    check all args <- filter(list_of(binary()), &(length(&1) != 1)),
              state <- state() do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec(args, state)
    end
  end
end
