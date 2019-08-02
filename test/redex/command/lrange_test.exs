defmodule Redex.Command.LrangeTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Redex.DataGenerators
  import Redex.Command.LRANGE

  setup :verify_on_exit!

  property "LRANGE non existing or expired key" do
    check all key <- binary(),
              state = %{db: db} <- state(),
              start <- integer(),
              stop <- integer(),
              no_record <- no_or_expired_record(state, key: key) do
      MnesiaMock
      |> expect(:dirty_read, fn :redex, {^db, ^key} -> no_record end)

      ProtocolMock
      |> expect(:reply, fn [], ^state -> state end)

      assert state == exec([key, "#{start}", "#{stop}"], state)
    end
  end

  property "LRANGE existing key" do
    check all state <- state(),
              start <- integer(),
              stop <- integer(),
              record = {:redex, {db, key}, list, _} <- record(state, type: :list) do
      MnesiaMock
      |> expect(:dirty_read, fn :redex, {^db, ^key} -> [record] end)

      value = Enum.slice(list, start..stop)

      ProtocolMock
      |> expect(:reply, fn ^value, ^state -> state end)

      assert state == exec([key, "#{start}", "#{stop}"], state)
    end
  end

  property "LRANGE with a non integer start/stop" do
    error = {:error, "ERR value is not an integer or out of range"}

    check all state <- state(),
              key <- binary(),
              start <- binary(min_length: 3),
              stop <- binary(min_length: 3) do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec([key, start, stop], state)
    end
  end

  property "LRANGE a key with a wrong kind of value" do
    error = {:error, "WRONGTYPE Operation against a key holding the wrong kind of value"}

    check all state <- state(),
              start <- integer(),
              stop <- integer(),
              record = {:redex, {db, key}, _, _} <- record(state) do
      MnesiaMock
      |> expect(:dirty_read, fn :redex, {^db, ^key} -> [record] end)

      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec([key, "#{start}", "#{stop}"], state)
    end
  end

  property "LRANGE with wrong number of arguments" do
    error = {:error, "ERR wrong number of arguments for 'LRANGE' command"}

    check all args <- filter(list_of(binary()), &(length(&1) != 3)),
              state <- state() do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec(args, state)
    end
  end
end
