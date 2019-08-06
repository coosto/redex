defmodule Redex.Command.InfoTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Redex.DataGenerators
  import Redex.Command.INFO

  setup :verify_on_exit!

  property "INFO all sections" do
    check all state <- state() do
      SystemMock
      |> expect(:os_time, fn :millisecond -> System.os_time(:millisecond) end)

      MnesiaMock
      |> expect(:dirty_select, fn :redex, _ -> [] end)

      ProtocolMock
      |> expect(:reply, fn "# Keyspace\r\n", ^state -> state end)

      assert state == exec([], state)
    end
  end

  property "INFO keyspace" do
    now = System.os_time(:millisecond)

    check all state <- state(),
              select_result <-
                list_of({integer(0..100), one_of([nil, integer((now + 1)..(now + 1000))])}) do
      SystemMock
      |> expect(:os_time, fn :millisecond -> now end)

      MnesiaMock
      |> expect(:dirty_select, fn :redex, _ -> select_result end)

      keyspace =
        select_result
        |> Enum.group_by(fn {db, _} -> db end, fn {_, expiry} -> expiry end)
        |> Enum.map(fn {db, expiry_list} ->
          keys = Enum.count(expiry_list)
          expiry_list = Enum.filter(expiry_list, fn expiry -> expiry != nil end)
          expires = Enum.count(expiry_list)

          ttl =
            expiry_list
            |> Enum.map(fn expiry -> expiry - now end)
            |> Enum.sum()

          avg_ttl = if expires > 0, do: div(ttl, expires), else: 0

          "db#{db}:keys=#{keys},expires=#{expires},avg_ttl=#{avg_ttl}\r\n"
        end)
        |> Enum.join()

      ProtocolMock
      |> expect(:reply, fn "# Keyspace\r\n" <> ^keyspace, ^state -> state end)

      assert state == exec(["keyspace"], state)
    end
  end

  property "INFO with invalid section" do
    check all section <- binary(),
              state <- state() do
      ProtocolMock
      |> expect(:reply, fn "", ^state -> state end)

      assert state == exec([section], state)
    end
  end

  property "INFO with wrong number of arguments" do
    error = {:error, "ERR syntax error"}

    check all args <- list_of(binary(), min_length: 2),
              state <- state() do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec(args, state)
    end
  end
end
