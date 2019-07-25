defmodule Redex.Command.PublishTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Redex.DataGenerators
  import Redex.Command.PUBLISH

  setup :verify_on_exit!

  property "PUBLISH a message to a channel" do
    check all state <- state(),
              ch <- binary(),
              msg <- binary(),
              subscribers <- uniq_list_of(binary()),
              result = length(subscribers) do
      Pg2Mock
      |> expect(:create, fn ^ch -> :ok end)
      |> expect(:get_members, fn ^ch -> subscribers end)

      ProtocolMock
      |> expect(:reply, fn ^result, ^state -> state end)

      ManifoldMock
      |> expect(:send, fn ^subscribers, {:push, ["message", ^ch, ^msg]} -> :ok end)

      assert state == exec([ch, msg], state)
    end
  end

  property "PUBLISH with wrong number of arguments" do
    error = {:error, "ERR wrong number of arguments for 'PUBLISH' command"}

    check all args <- filter(list_of(binary()), &(length(&1) != 2)),
              state <- state() do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec(args, state)
    end
  end
end
