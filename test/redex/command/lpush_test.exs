defmodule Redex.Command.LpushTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Redex.DataGenerators
  import Redex.Command.LPUSH

  setup :verify_on_exit!

  property "LPUSH a non existing or expired key" do
    check all state = %{db: db} <- state(),
              nodes <- nodes(state),
              key <- binary(),
              args <- list_of(binary(), min_length: 1),
              list = Enum.reverse(args),
              len = length(args),
              no_record <- no_or_expired_record(state, key: key) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)
      |> expect(:sync_transaction, fn f -> {:atomic, f.()} end)
      |> expect(:read, fn :redex, {^db, ^key}, :write -> no_record end)
      |> expect(:write, fn :redex, {:redex, {^db, ^key}, ^list, nil}, :write -> :ok end)

      ProtocolMock
      |> expect(:reply, fn ^len, ^state -> state end)

      assert state == exec([key | args], state)
    end
  end

  property "LPUSH an existing key" do
    check all state <- state(),
              nodes <- nodes(state),
              record = {:redex, {db, key}, value, expiry} <- record(state, type: :list),
              args <- list_of(binary(), min_length: 1),
              list = Enum.reverse(args) ++ value,
              len = length(list) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)
      |> expect(:sync_transaction, fn f -> {:atomic, f.()} end)
      |> expect(:read, fn :redex, {^db, ^key}, :write -> [record] end)
      |> expect(:write, fn :redex, {:redex, {^db, ^key}, ^list, ^expiry}, :write -> :ok end)

      ProtocolMock
      |> expect(:reply, fn ^len, ^state -> state end)

      assert state == exec([key | args], state)
    end
  end

  property "LPUSH a key with a wrong kind of value" do
    error = {:error, "WRONGTYPE Operation against a key holding the wrong kind of value"}

    check all state <- state(),
              nodes <- nodes(state),
              args <- list_of(binary(), min_length: 1),
              record = {:redex, {db, key}, _, _} <- record(state) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)
      |> expect(:sync_transaction, fn f -> {:atomic, f.()} end)
      |> expect(:read, fn :redex, {^db, ^key}, :write -> [record] end)

      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec([key | args], state)
    end
  end

  property "LPUSH in readonly mode" do
    error = {:error, "READONLY You can't write against a read only replica."}

    check all state <- state(),
              nodes <- nodes(state, readonly: true),
              args <- list_of(binary(), min_length: 2) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)

      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec(args, state)
    end
  end

  property "LPUSH with wrong number of arguments" do
    error = {:error, "ERR wrong number of arguments for 'LPUSH' command"}

    check all state <- state(),
              args <- list_of(binary(), max_length: 1) do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec(args, state)
    end
  end
end
