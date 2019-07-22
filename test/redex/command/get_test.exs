defmodule Redex.Command.GetTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Redex.DataGenerators
  import Redex.Command.GET

  setup :verify_on_exit!

  property "GET non existing key" do
    check all key <- binary(),
              state = %{db: db} <- state() do
      MnesiaMock
      |> expect(:dirty_read, fn :redex, {^db, ^key} -> [] end)

      ProtocolMock
      |> expect(:reply, fn nil, ^state -> state end)

      assert state == exec([key], state)
    end
  end

  property "GET existing key" do
    check all state <- state(),
              record = {:redex, {db, key}, value, _} <- record(state) do
      MnesiaMock
      |> expect(:dirty_read, fn :redex, {^db, ^key} -> [record] end)

      ProtocolMock
      |> expect(:reply, fn ^value, ^state -> state end)

      assert state == exec([key], state)
    end
  end

  property "GET expired key" do
    check all state <- state(),
              record = {:redex, {db, key}, _, _} <- record(state, expired: true) do
      MnesiaMock
      |> expect(:dirty_read, fn :redex, {^db, ^key} -> [record] end)

      ProtocolMock
      |> expect(:reply, fn nil, ^state -> state end)

      assert state == exec([key], state)
    end
  end

  property "GET a key with a wrong kind of value" do
    error = {:error, "WRONGTYPE Operation against a key holding the wrong kind of value"}

    check all state <- state(),
              record = {:redex, {db, key}, _, _} <- record(state, type: :list) do
      MnesiaMock
      |> expect(:dirty_read, fn :redex, {^db, ^key} -> [record] end)

      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec([key], state)
    end
  end

  property "GET with wrong number of arguments" do
    error = {:error, "ERR wrong number of arguments for 'GET' command"}

    check all args <- filter(list_of(binary()), &(length(&1) != 1)),
              state <- state() do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec(args, state)
    end
  end
end
