defmodule Redex.Command.RpopTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Redex.DataGenerators
  import Redex.Command.RPOP

  setup :verify_on_exit!

  property "RPOP a non existing or expired key" do
    check all state = %{db: db} <- state(),
              nodes <- nodes(state),
              key <- binary(),
              no_record <- no_or_expired_record(state, key: key) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)
      |> expect(:sync_transaction, fn f -> {:atomic, f.()} end)
      |> expect(:read, fn :redex, {^db, ^key}, :write -> no_record end)

      ProtocolMock
      |> expect(:reply, fn nil, ^state -> state end)

      assert state == exec([key], state)
    end
  end

  property "RPOP an existing key" do
    check all state <- state(),
              nodes <- nodes(state),
              record = {:redex, {db, key}, value, expiry} <- record(state, type: :list),
              {popped, list} = List.pop_at(value, -1) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)
      |> expect(:sync_transaction, fn f -> {:atomic, f.()} end)
      |> expect(:read, fn :redex, {^db, ^key}, :write -> [record] end)

      if list == [] do
        MnesiaMock
        |> expect(:delete, fn :redex, {^db, ^key}, :write -> :ok end)
      else
        MnesiaMock
        |> expect(:write, fn :redex, {:redex, {^db, ^key}, ^list, ^expiry}, :write -> :ok end)
      end

      ProtocolMock
      |> expect(:reply, fn ^popped, ^state -> state end)

      assert state == exec([key], state)
    end
  end

  property "RPOP a key with a wrong kind of value" do
    error = {:error, "WRONGTYPE Operation against a key holding the wrong kind of value"}

    check all state <- state(),
              nodes <- nodes(state),
              record = {:redex, {db, key}, _, _} <- record(state) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)
      |> expect(:sync_transaction, fn f -> {:atomic, f.()} end)
      |> expect(:read, fn :redex, {^db, ^key}, :write -> [record] end)

      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec([key], state)
    end
  end

  property "RPOP in readonly mode" do
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

  property "RPOP with wrong number of arguments" do
    error = {:error, "ERR wrong number of arguments for 'RPOP' command"}

    check all state <- state(),
              args <- filter(list_of(binary()), &(length(&1) != 1)) do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec(args, state)
    end
  end
end
