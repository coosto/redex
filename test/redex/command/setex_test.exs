defmodule Redex.Command.SetexTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Redex.DataGenerators
  import Redex.Command.SETEX

  setup :verify_on_exit!

  property "SETEX a key" do
    check all state <- state(quorum: 1),
              ex <- positive_integer(),
              {:redex, {db, key}, value, expiry} <- record(state, expired: ex * 1000) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> [node()] end)
      |> expect(:dirty_write, fn :redex, {:redex, {^db, ^key}, ^value, x} ->
        assert (x - expiry) in 0..100
        :ok
      end)

      ProtocolMock
      |> expect(:reply, fn :ok, ^state -> state end)

      assert state == exec([key, "#{ex}", value], state)
    end
  end

  property "SETEX a key in readonly mode" do
    error = {:error, "READONLY You can't write against a read only replica."}

    check all state <- state(),
              nodes <- nodes(state, readonly: true),
              ex <- positive_integer(),
              {:redex, {_, key}, value, _} <- record(state) do
      MnesiaMock
      |> expect(:system_info, fn :running_db_nodes -> nodes end)

      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec([key, "#{ex}", value], state)
    end
  end

  property "SETEX with wrong EX argument" do
    error = {:error, "ERR value is not an integer or out of range"}

    check all state <- state(),
              {key, ex, value} <- {binary(), binary(min_length: 3), binary()} do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec([key, ex, value], state)
    end
  end

  property "SETEX with wrong number of arguments" do
    error = {:error, "ERR wrong number of arguments for 'SETEX' command"}

    check all args <- filter(list_of(binary()), &(length(&1) != 3)),
              state <- state() do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec(args, state)
    end
  end
end
