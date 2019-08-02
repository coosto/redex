defmodule Redex.Command.LindexTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Redex.DataGenerators
  import Redex.Command.LINDEX

  setup :verify_on_exit!

  property "LINDEX non existing or expired key" do
    check all key <- binary(),
              state = %{db: db} <- state(),
              index <- integer(),
              no_record <- no_or_expired_record(state, key: key) do
      MnesiaMock
      |> expect(:dirty_read, fn :redex, {^db, ^key} -> no_record end)

      ProtocolMock
      |> expect(:reply, fn nil, ^state -> state end)

      assert state == exec([key, "#{index}"], state)
    end
  end

  property "LINDEX existing key" do
    check all state <- state(),
              index <- integer(),
              record = {:redex, {db, key}, list, _} <- record(state, type: :list) do
      MnesiaMock
      |> expect(:dirty_read, fn :redex, {^db, ^key} -> [record] end)

      value = Enum.at(list, index)

      ProtocolMock
      |> expect(:reply, fn ^value, ^state -> state end)

      assert state == exec([key, "#{index}"], state)
    end
  end

  property "LINDEX with a non integer index" do
    error = {:error, "ERR value is not an integer or out of range"}

    check all state <- state(),
              key <- binary(),
              index <- binary(min_length: 3) do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec([key, index], state)
    end
  end

  property "LINDEX a key with a wrong kind of value" do
    error = {:error, "WRONGTYPE Operation against a key holding the wrong kind of value"}

    check all state <- state(),
              index <- integer(),
              record = {:redex, {db, key}, _, _} <- record(state) do
      MnesiaMock
      |> expect(:dirty_read, fn :redex, {^db, ^key} -> [record] end)

      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec([key, "#{index}"], state)
    end
  end

  property "LINDEX with wrong number of arguments" do
    error = {:error, "ERR wrong number of arguments for 'LINDEX' command"}

    check all args <- filter(list_of(binary()), &(length(&1) != 2)),
              state <- state() do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec(args, state)
    end
  end
end
