defmodule Redex.Command.PttlTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Redex.DataGenerators
  import Redex.Command.PTTL

  setup :verify_on_exit!

  property "PTTL of a non existing or expired key" do
    check all key <- binary(),
              state = %{db: db} <- state(),
              no_record = no_or_expired_record(state, key: key) do
      MnesiaMock
      |> expect(:dirty_read, fn :redex, {^db, ^key} -> no_record end)

      ProtocolMock
      |> expect(:reply, fn -2, ^state -> state end)

      assert state == exec([key], state)
    end
  end

  property "PTTL of an existing key without expiry" do
    check all state <- state(),
              record = {:redex, {db, key}, _, _} <- record(state, expired: nil) do
      MnesiaMock
      |> expect(:dirty_read, fn :redex, {^db, ^key} -> [record] end)

      ProtocolMock
      |> expect(:reply, fn -1, ^state -> state end)

      assert state == exec([key], state)
    end
  end

  property "PTTL of an existing key with expiry" do
    check all state <- state(),
              record = {:redex, {db, key}, _, expiry} <- record(state, expired: integer(10..1000)) do
      MnesiaMock
      |> expect(:dirty_read, fn :redex, {^db, ^key} -> [record] end)

      expected_px = expiry - System.os_time(:millisecond)

      ProtocolMock
      |> expect(:reply, fn px, ^state ->
        assert (expected_px - px) in 0..100
        state
      end)

      assert state == exec([key], state)
    end
  end

  property "PTTL with wrong number of arguments" do
    error = {:error, "ERR wrong number of arguments for 'PTTL' command"}

    check all args <- filter(list_of(binary()), &(length(&1) != 1)),
              state <- state() do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec(args, state)
    end
  end
end
