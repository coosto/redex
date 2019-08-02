defmodule Redex.Command.LlenTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Redex.DataGenerators
  import Redex.Command.LLEN

  setup :verify_on_exit!

  property "LLEN non existing or expired key" do
    check all key <- binary(),
              state = %{db: db} <- state(),
              no_record <- no_or_expired_record(state, key: key) do
      MnesiaMock
      |> expect(:dirty_read, fn :redex, {^db, ^key} -> no_record end)

      ProtocolMock
      |> expect(:reply, fn 0, ^state -> state end)

      assert state == exec([key], state)
    end
  end

  property "LLEN existing key" do
    check all state <- state(),
              record = {:redex, {db, key}, value, _} <- record(state, type: :list),
              len = length(value) do
      MnesiaMock
      |> expect(:dirty_read, fn :redex, {^db, ^key} -> [record] end)

      ProtocolMock
      |> expect(:reply, fn ^len, ^state -> state end)

      assert state == exec([key], state)
    end
  end

  property "LLEN a key with a wrong kind of value" do
    error = {:error, "WRONGTYPE Operation against a key holding the wrong kind of value"}

    check all state <- state(),
              record = {:redex, {db, key}, _, _} <- record(state) do
      MnesiaMock
      |> expect(:dirty_read, fn :redex, {^db, ^key} -> [record] end)

      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec([key], state)
    end
  end

  property "LLEN with wrong number of arguments" do
    error = {:error, "ERR wrong number of arguments for 'LLEN' command"}

    check all args <- filter(list_of(binary()), &(length(&1) != 1)),
              state <- state() do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec(args, state)
    end
  end
end
