defmodule Redex.Command.SelectTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Redex.DataGenerators
  import Redex.Command.SELECT

  setup :verify_on_exit!

  property "SELECT a db" do
    check all state <- state(),
              db <- integer(0..100),
              new_state = %{state | db: db} do
      ProtocolMock
      |> expect(:reply, fn :ok, ^new_state -> new_state end)

      assert new_state == exec(["#{db}"], state)
    end
  end

  property "SELECT with invalid DB index" do
    error = {:error, "ERR invalid DB index"}

    check all state <- state(),
              db <- binary(min_length: 3) do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec([db], state)
    end
  end

  property "SELECT with out of range DB index" do
    error = {:error, "ERR DB index is out of range"}

    check all state <- state(),
              db <- integer(101..1000) do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec(["#{db}"], state)
    end
  end

  property "SELECT with wrong number of arguments" do
    error = {:error, "ERR wrong number of arguments for 'SELECT' command"}

    check all state <- state(),
              args <- filter(list_of(binary()), &(length(&1) != 1)) do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec(args, state)
    end
  end
end
