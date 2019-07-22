defmodule Redex.Command.MgetTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Redex.DataGenerators
  import Redex.Command.MGET

  setup :verify_on_exit!

  property "MGET non existing keys" do
    check all state = %{db: db} <- state(),
              keys <- list_of(binary(), min_length: 1) do
      result =
        for key <- keys do
          no_record = no_or_expired_record(state, key: key) |> Enum.at(0)

          MnesiaMock
          |> expect(:dirty_read, fn :redex, {^db, ^key} -> no_record end)

          nil
        end

      ProtocolMock
      |> expect(:reply, fn ^result, ^state -> state end)

      assert state == exec(keys, state)
    end
  end

  property "MGET existing keys" do
    check all state = %{db: db} <- state(),
              keys <- list_of(binary(), min_length: 1) do
      values =
        for key <- keys do
          record = {:redex, {^db, ^key}, value, _} = record(state, key: key) |> Enum.at(0)

          MnesiaMock
          |> expect(:dirty_read, fn :redex, {^db, ^key} -> [record] end)

          value
        end

      ProtocolMock
      |> expect(:reply, fn ^values, ^state -> state end)

      assert state == exec(keys, state)
    end
  end

  property "MGET a combination of existing and non exsisting keys" do
    check all state = %{db: db} <- state(),
              keys <- uniq_list_of(binary(), min_length: 2),
              existing_keys = Enum.take_random(keys, Enum.random(1..(length(keys) - 1))) do
      values =
        for key <- keys do
          record =
            if key in existing_keys do
              record(state, key: key) |> Enum.take(1)
            else
              no_or_expired_record(state, key: key) |> Enum.at(0)
            end

          MnesiaMock
          |> expect(:dirty_read, fn :redex, {^db, ^key} -> record end)

          if key in existing_keys do
            [{:redex, {^db, ^key}, value, _}] = record
            value
          end
        end

      ProtocolMock
      |> expect(:reply, fn ^values, ^state -> state end)

      assert state == exec(keys, state)
    end
  end

  property "MGET keys with a wrong kind of value" do
    check all state = %{db: db} <- state(),
              keys <- uniq_list_of(binary(), min_length: 1) do
      result =
        for key <- keys do
          record = record(state, key: key, type: :list) |> Enum.at(0)

          MnesiaMock
          |> expect(:dirty_read, fn :redex, {^db, ^key} -> [record] end)

          nil
        end

      ProtocolMock
      |> expect(:reply, fn ^result, ^state -> state end)

      assert state == exec(keys, state)
    end
  end

  test "MGET with wrong number of arguments" do
    error = {:error, "ERR wrong number of arguments for 'MGET' command"}

    state = state()

    ProtocolMock
    |> expect(:reply, fn ^error, ^state -> state end)

    assert state == exec([], state)
  end
end
