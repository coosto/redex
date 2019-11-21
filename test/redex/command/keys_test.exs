defmodule Redex.Command.KeysTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Redex.DataGenerators
  import Redex.Command.KEYS

  setup :verify_on_exit!

  @patterns %{
    "?" => ~r/^.$/,
    "*" => ~r/^.*$/,
    "a*" => ~r/^a.*$/,
    "[^a-z]" => ~r/^[^a-z]$/,
    "[^a]?" => ~r/^[^a].$/,
    "[a-z]" => ~r/^[a-z]$/,
    "[0-9]*" => ~r/^[0-9].*$/
  }

  property "KEYS with a pattern" do
    check all pattern <- member_of(Map.keys(@patterns)),
              keys <- list_of(string(:alphanumeric)),
              state <- state() do
      MnesiaMock
      |> expect(:dirty_select, fn :redex, _ -> keys end)

      result = Enum.filter(keys, &String.match?(&1, @patterns[pattern]))

      ProtocolMock
      |> expect(:reply, fn ^result, ^state -> state end)

      assert state == exec([pattern], state)
    end
  end

  property "KEYS with wrong number of arguments" do
    error = {:error, "ERR wrong number of arguments for 'KEYS' command"}

    check all args <- filter(list_of(binary()), &(length(&1) != 1)),
              state <- state() do
      ProtocolMock
      |> expect(:reply, fn ^error, ^state -> state end)

      assert state == exec(args, state)
    end
  end
end
