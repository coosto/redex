defmodule Redex.Command.TtlTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Redex.DataGenerators
  import Redex.Command.TTL

  setup :verify_on_exit!

  property "TTL of a non existing or expired key" do
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

  property "TTL of an existing key without expiry" do
    check all state <- state(),
              record = {:redex, {db, key}, _, _} <- record(state, expired: nil) do
      MnesiaMock
      |> expect(:dirty_read, fn :redex, {^db, ^key} -> [record] end)

      ProtocolMock
      |> expect(:reply, fn -1, ^state -> state end)

      assert state == exec([key], state)
    end
  end

  property "TTL of an existing key with expiry" do
    check all state <- state(),
              record = {:redex, {db, key}, _, expiry} <- record(state, expired: integer(10..1000)) do
      MnesiaMock
      |> expect(:dirty_read, fn :redex, {^db, ^key} -> [record] end)

      ex = (expiry - System.os_time(:millisecond)) / 1000
      ex = ex |> Float.ceil() |> trunc

      ProtocolMock
      |> expect(:reply, fn ^ex, ^state -> state end)

      assert state == exec([key], state)
    end
  end

  property "TTL with wrong number of arguments" do
    error = {:error, "ERR wrong number of arguments for 'TTL' command"}

    check all args <- filter(list_of(binary()), &(length(&1) != 1)),
              state <- state() do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec(args, state)
    end
  end
end
