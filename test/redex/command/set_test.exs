defmodule Redex.Command.SetTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Redex.DataGenerators
  import Redex.Command.SET

  setup :verify_on_exit!

  property "SET a key" do
    check all state <- state(),
              nodes <- nodes(state),
              record = {:redex, {_, key}, value, _} <- record(state, expired: nil) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)

      if length(nodes) == 1 do
        MnesiaMock
        |> expect(:dirty_write, fn :redex, ^record -> :ok end)
      else
        MnesiaMock
        |> expect(:sync_transaction, fn f -> {:atomic, f.()} end)
        |> expect(:write, fn :redex, ^record, :write -> :ok end)
      end

      ProtocolMock
      |> expect(:reply, fn :ok, ^state -> state end)

      assert state == exec([key, value], state)
    end
  end

  property "SET a key in readonly mode" do
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

  property "SET a key with expire time in seconds" do
    check all state <- state(quorum: 1),
              ex <- positive_integer(),
              {:redex, {db, key}, value, expiry} <- record(state, expired: ex * 1000) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> [node()] end)
      |> expect(:dirty_write, fn :redex, {:redex, {^db, ^key}, ^value, x} ->
        assert (x - expiry) in 0..100
        :ok
      end)

      ProtocolMock
      |> expect(:reply, fn :ok, ^state -> state end)

      assert state == exec([key, value, "ex", "#{ex}"], state)
    end
  end

  property "SET a key with expire time in milliseconds" do
    check all state <- state(quorum: 1),
              px <- positive_integer(),
              {:redex, {db, key}, value, expiry} <- record(state, expired: px) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> [node()] end)
      |> expect(:dirty_write, fn :redex, {:redex, {^db, ^key}, ^value, x} ->
        assert (x - expiry) in 0..100
        :ok
      end)

      ProtocolMock
      |> expect(:reply, fn :ok, ^state -> state end)

      assert state == exec([key, value, "px", "#{px}"], state)
    end
  end

  property "SET a key with invalid expire argument" do
    error = {:error, "ERR value is not an integer or out of range"}

    check all state <- state(),
              {:redex, {_, key}, value, _} <- record(state),
              arg <- member_of(["ex", "px"]) do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec([key, value, arg, "invalid_value"], state)
    end
  end

  property "SET a key with NX option" do
    check all state <- state(quorum: 1),
              record = {:redex, {db, key}, value, _} <- record(state, expired: nil),
              no_record <- no_or_expired_record(state, key: key) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> [node()] end)
      |> expect(:sync_transaction, fn f -> {:atomic, f.()} end)
      |> expect(:read, fn :redex, {^db, ^key}, :write -> no_record end)
      |> expect(:write, fn :redex, ^record, :write -> :ok end)

      ProtocolMock
      |> expect(:reply, fn :ok, ^state -> state end)

      assert state == exec([key, value, "nx"], state)
    end
  end

  property "SET an existing key with NX option" do
    check all state <- state(quorum: 1),
              old_record = {:redex, {db, key}, _, _} <- record(state),
              value <- binary() do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> [node()] end)
      |> expect(:sync_transaction, fn f -> {:atomic, f.()} end)
      |> expect(:read, fn :redex, {^db, ^key}, :write -> [old_record] end)

      ProtocolMock
      |> expect(:reply, fn nil, ^state -> state end)

      assert state == exec([key, value, "nx"], state)
    end
  end

  property "SET a key with XX option" do
    check all state <- state(quorum: 1),
              {:redex, {db, key}, value, _} <- record(state),
              no_record <- no_or_expired_record(state, key: key) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> [node()] end)
      |> expect(:sync_transaction, fn f -> {:atomic, f.()} end)
      |> expect(:read, fn :redex, {^db, ^key}, :write -> no_record end)

      ProtocolMock
      |> expect(:reply, fn nil, ^state -> state end)

      assert state == exec([key, value, "xx"], state)
    end
  end

  property "SET an existing key with XX option" do
    check all state <- state(quorum: 1),
              new_record = {:redex, {db, key}, value, _} <- record(state, expired: nil),
              old_record <- record(state, key: key) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> [node()] end)
      |> expect(:sync_transaction, fn f -> {:atomic, f.()} end)
      |> expect(:read, fn :redex, {^db, ^key}, :write -> [old_record] end)
      |> expect(:write, fn :redex, ^new_record, :write -> :ok end)

      ProtocolMock
      |> expect(:reply, fn :ok, ^state -> state end)

      assert state == exec([key, value, "xx"], state)
    end
  end

  property "SET a key with both NX and XX options" do
    error = {:error, "ERR syntax error"}

    check all state <- state(),
              {:redex, {_, key}, value, _} <- record(state) do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec([key, value, "nx", "xx"], state)
    end
  end

  property "SET with wrong arguments" do
    error = {:error, "ERR syntax error"}

    check all state <- state(),
              {:redex, {_, key}, value, _} <- record(state),
              args <- list_of(binary(), min_length: 1) do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec([key, value | args], state)
    end
  end

  property "SET with wrong number of arguments" do
    error = {:error, "ERR wrong number of arguments for 'SET' command"}

    check all state <- state(),
              arg <- binary() do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec(arg, state)
    end
  end
end
