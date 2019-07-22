defmodule Redex.Command.DelTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Redex.DataGenerators
  import Redex.Command.DEL

  setup :verify_on_exit!

  property "DEL non existing keys" do
    check all state = %{db: db} <- state(),
              nodes <- nodes(state),
              keys <- list_of(binary(), min_length: 1) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)
      |> expect(:sync_transaction, fn f -> {:atomic, f.()} end)

      for key <- keys do
        no_record = no_or_expired_record(state, key: key) |> Enum.at(0)

        MnesiaMock
        |> expect(:read, fn :redex, {^db, ^key}, :write -> no_record end)
      end

      ProtocolMock
      |> expect(:reply, fn 0, ^state -> state end)

      assert state == exec(keys, state)
    end
  end

  property "DEL existing keys" do
    check all state = %{db: db} <- state(),
              nodes <- nodes(state),
              keys <- list_of(binary(), min_length: 1),
              result = length(keys) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)
      |> expect(:sync_transaction, fn f -> {:atomic, f.()} end)

      for key <- keys do
        MnesiaMock
        |> expect(:read, fn :redex, {^db, ^key}, :write ->
          record(state, key: key) |> Enum.take(1)
        end)
        |> expect(:delete, fn :redex, {^db, ^key}, :write -> :ok end)
      end

      ProtocolMock
      |> expect(:reply, fn ^result, ^state -> state end)

      assert state == exec(keys, state)
    end
  end

  property "DEL a combination of existing and non existing keys" do
    check all state = %{db: db} <- state(),
              nodes <- nodes(state),
              keys <- uniq_list_of(binary(), min_length: 2),
              del_count = Enum.random(1..(length(keys) - 1)),
              del_keys = Enum.take_random(keys, del_count) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)
      |> expect(:sync_transaction, fn f -> {:atomic, f.()} end)

      for key <- keys do
        if key in del_keys do
          MnesiaMock
          |> expect(:read, fn :redex, {^db, ^key}, :write ->
            record(state, key: key) |> Enum.take(1)
          end)
          |> expect(:delete, fn :redex, {^db, ^key}, :write -> :ok end)
        else
          no_record = no_or_expired_record(state, key: key) |> Enum.at(0)

          MnesiaMock
          |> expect(:read, fn :redex, {^db, ^key}, :write -> no_record end)
        end
      end

      ProtocolMock
      |> expect(:reply, fn ^del_count, ^state -> state end)

      assert state == exec(keys, state)
    end
  end

  property "DEL keys in readonly mode" do
    error = {:error, "READONLY You can't write against a read only replica."}

    check all state <- state(),
              nodes <- nodes(state, readonly: true),
              keys <- list_of(binary(), min_length: 1) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)

      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec(keys, state)
    end
  end

  test "DEL with wrong number of arguments" do
    error = {:error, "ERR wrong number of arguments for 'DEL' command"}

    state = state()

    ProtocolMock
    |> expect(:reply, fn ^error, ^state -> state end)

    assert state == exec([], state)
  end
end
