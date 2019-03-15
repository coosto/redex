defmodule Redex.Protocol.ParserTest do
  use ExUnit.Case
  use ExUnitProperties

  import Redex.Protocol.State
  import Redex.Protocol.Parser
  import Redex.Mock.State

  defp cmd(cmd), do: Enum.join(cmd, "\r\n") <> "\r\n"

  setup_all do
    [state: mock_state()]
  end

  test "parse", %{state: state} do
    result = state |> state(buffer: cmd(~w/*3 $3 SET $1 a $1 1/)) |> parse()
    assert result == {:ok, ["SET", "a", "1"], state}

    result = state |> state(buffer: cmd(~w/*5 $3 SET $1 a $1 1 $2 EX $2 10/)) |> parse()
    assert result == {:ok, ["SET", "a", "1", "EX", "10"], state}

    result = state |> state(buffer: cmd(~w/*2 $3 GET $1 a *2 $3 GET $1 b/)) |> parse()
    assert result == {:ok, ["GET", "a"], state(state, buffer: cmd(~w/*2 $3 GET $1 b/))}

    result = state |> state(buffer: "*0\r\n") |> parse()
    assert result == {:ok, [], state}

    assert {:error, _} = state |> state(buffer: "*12x\r\n") |> parse()
    assert {:error, _} = state |> state(buffer: "*12\n") |> parse()
    assert {:error, _} = state |> state(buffer: "*12") |> parse()
    assert {:error, _} = state |> state(buffer: "*2\r\n12") |> parse()
    assert {:error, _} = state |> state(buffer: "*2\r\n$1x") |> parse()
    assert {:error, _} = state |> state(buffer: "*2\r\n$1\r\nx1234567890123456") |> parse()
    assert {:error, _} = state |> state(buffer: "*2\r\n$10\r\n123") |> parse()
    assert {:error, _} = state |> state(buffer: cmd(~w/*2 $3 SET $1 a $1 1/)) |> parse()
  end

  test "parse with randomly generated data", %{state: state} do
    check all len <- StreamData.integer(0..100) do
      cmd =
        StreamData.binary()
        |> Enum.take(len)

      buffer =
        cmd
        |> Enum.map(fn data -> "$#{byte_size(data)}\r\n#{data}\r\n" end)
        |> Enum.join()

      reset_state(state, "*#{len}\r\n#{buffer}")
      assert parse(state) == {:ok, cmd, state}
    end
  end

  test "parse_inline", %{state: state} do
    result = state |> state(buffer: "SET a 1\r\n") |> parse()
    assert result == {:ok, ["SET", "a", "1"], state}

    result = state |> state(buffer: "SET  a 1\n") |> parse()
    assert result == {:ok, ["SET", "a", "1"], state}

    result = state |> state(buffer: "\r\nSET a 1\r\n") |> parse()
    assert result == {:ok, [], state(state, buffer: "SET a 1\r\n")}

    result = state |> state(buffer: "SET key val\r\nGET key\r\n") |> parse()
    assert result == {:ok, ["SET", "key", "val"], state(state, buffer: "GET key\r\n")}

    result = state |> reset_state("\r\nGET val\r\n") |> state(buffer: "SET key val") |> parse()
    assert result == {:ok, ["SET", "key", "val"], state(state, buffer: "GET val\r\n")}

    result = state |> reset_state("\nGET val\r\n") |> state(buffer: "SET key val\r") |> parse()
    assert result == {:ok, ["SET", "key", "val"], state(state, buffer: "GET val\r\n")}
  end
end
