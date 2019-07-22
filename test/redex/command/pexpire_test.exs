defmodule Redex.Command.PexpireTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Redex.DataGenerators
  import Redex.Command.PEXPIRE

  setup :verify_on_exit!

  property "PEXPIRE a non existing or expired key" do
    check all state = %{db: db} <- state(),
              nodes <- nodes(state),
              ex <- positive_integer(),
              key <- binary(),
              no_record <- no_or_expired_record(state, key: key) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)
      |> expect(:sync_transaction, fn f -> {:atomic, f.()} end)
      |> expect(:read, fn :redex, {^db, ^key}, :write -> no_record end)

      ProtocolMock
      |> expect(:reply, fn 0, ^state -> state end)

      assert state == exec([key, "#{ex}"], state)
    end
  end

  property "PEXPIRE an existing key" do
    check all state <- state(),
              nodes <- nodes(state),
              ex <- positive_integer(),
              record = {:redex, {db, key}, value, _} <- record(state),
              expiry = System.os_time(:millisecond) + ex do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)
      |> expect(:sync_transaction, fn f -> {:atomic, f.()} end)
      |> expect(:read, fn :redex, {^db, ^key}, :write -> [record] end)
      |> expect(:write, fn :redex, {:redex, {^db, ^key}, ^value, x}, :write ->
        assert (x - expiry) in 0..100
        :ok
      end)

      ProtocolMock
      |> expect(:reply, fn 1, ^state -> state end)

      assert state == exec([key, "#{ex}"], state)
    end
  end

  property "PEXPIRE a key in readonly mode" do
    error = {:error, "READONLY You can't write against a read only replica."}

    check all state <- state(),
              nodes <- nodes(state, readonly: true),
              key <- binary(),
              ex <- positive_integer() do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)

      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec([key, "#{ex}"], state)
    end
  end

  property "PEXPIRE with wrong arguments" do
    error = {:error, "ERR value is not an integer or out of range"}

    check all state <- state(),
              key <- binary(),
              ex <- binary(min_length: 3) do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec([key, "#{ex}"], state)
    end
  end

  property "PEXPIRE with wrong number of arguments" do
    error = {:error, "ERR wrong number of arguments for 'PEXPIRE' command"}

    check all args <- filter(list_of(binary()), &(length(&1) != 2)),
              state <- state() do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec(args, state)
    end
  end
end
