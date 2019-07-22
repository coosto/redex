defmodule Redex.Command.IncrbyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Redex.DataGenerators
  import Redex.Command.INCRBY

  setup :verify_on_exit!

  property "INCRBY a non existing or expired key" do
    check all state = %{db: db} <- state(),
              nodes <- nodes(state),
              key <- binary(),
              no_record <- no_or_expired_record(state, key: key),
              value <- integer(),
              str_val = to_string(value) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)
      |> expect(:sync_transaction, fn f -> {:atomic, f.()} end)
      |> expect(:read, fn :redex, {^db, ^key}, :write -> no_record end)
      |> expect(:write, fn :redex, {:redex, {^db, ^key}, ^str_val, nil}, :write -> :ok end)

      ProtocolMock
      |> expect(:reply, fn ^value, ^state -> state end)

      assert state == exec([key, str_val], state)
    end
  end

  property "INCRBY an existing key" do
    check all state <- state(),
              nodes <- nodes(state),
              record = {:redex, {db, key}, old_value, expiry} <- record(state, type: :int),
              incrby <- integer(),
              new_value = String.to_integer(old_value) + incrby,
              str_val = to_string(new_value) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)
      |> expect(:sync_transaction, fn f -> {:atomic, f.()} end)
      |> expect(:read, fn :redex, {^db, ^key}, :write -> [record] end)
      |> expect(:write, fn :redex, {:redex, {^db, ^key}, ^str_val, ^expiry}, :write -> :ok end)

      ProtocolMock
      |> expect(:reply, fn ^new_value, ^state -> state end)

      assert state == exec([key, to_string(incrby)], state)
    end
  end

  property "INCRBY in readonly mode" do
    error = {:error, "READONLY You can't write against a read only replica."}

    check all state <- state(),
              nodes <- nodes(state, readonly: true),
              {:redex, {_, key}, value, _} <- record(state, type: :int) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)

      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec([key, value], state)
    end
  end

  property "INCRBY a key with a wrong kind of value" do
    error = {:error, "WRONGTYPE Operation against a key holding the wrong kind of value"}

    check all state <- state(),
              nodes <- nodes(state),
              record = {:redex, {db, key}, _, _} <- record(state, type: :list),
              incrby <- integer(),
              str_val = to_string(incrby) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)
      |> expect(:sync_transaction, fn f -> {:atomic, f.()} end)
      |> expect(:read, fn :redex, {^db, ^key}, :write -> [record] end)

      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec([key, str_val], state)
    end
  end

  property "INCRBY a key having a non integer value" do
    error = {:error, "ERR value is not an integer or out of range"}

    check all state <- state(),
              nodes <- nodes(state),
              record = {:redex, {db, key}, _, _} <- record(state, type: binary(min_length: 3)),
              incrby <- integer(),
              str_val = to_string(incrby) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)
      |> expect(:sync_transaction, fn f -> {:atomic, f.()} end)
      |> expect(:read, fn :redex, {^db, ^key}, :write -> [record] end)

      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec([key, str_val], state)
    end
  end

  property "INCRBY a key by a non integer value" do
    error = {:error, "ERR value is not an integer or out of range"}

    check all state <- state(),
              key <- binary(),
              value <- binary(min_length: 3) do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec([key, value], state)
    end
  end

  property "INCRBY with wrong number of arguments" do
    error = {:error, "ERR wrong number of arguments for 'INCRBY' command"}

    check all args <- filter(list_of(binary()), &(length(&1) != 2)),
              state <- state() do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec(args, state)
    end
  end
end
