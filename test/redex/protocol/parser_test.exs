defmodule Redex.Protocol.ParserTest do
  use ExUnit.Case
  use ExUnitProperties

  import Redex.Protocol.State
  import Redex.Protocol.Parser

  defp cmd(cmd), do: Enum.join(cmd, "\r\n") <> "\r\n"

  defp reset_socket(state(socket: socket), input) do
    Agent.cast(socket, fn _ -> %{in: input, out: ""} end)
  end

  setup_all do
    {:ok, socket} = start_supervised({Agent, fn -> %{in: "", out: ""} end})
    [state: state(transport: Redex.Mock.Transport, socket: socket)]
  end

  test "parse", %{state: state} do
    result = parse(state(state, buffer: cmd(~w/*3 $3 SET $1 a $1 1/)))
    assert result == {:ok, ["SET", "a", "1"], state}

    result = parse(state(state, buffer: cmd(~w/*5 $3 SET $1 a $1 1 $2 EX $2 10/)))
    assert result == {:ok, ["SET", "a", "1", "EX", "10"], state}

    result = parse(state(state, buffer: cmd(~w/*2 $3 GET $1 a *2 $3 GET $1 b/)))
    assert result == {:ok, ["GET", "a"], state(state, buffer: cmd(~w/*2 $3 GET $1 b/))}

    result = parse(state(state, buffer: "*0\r\n"))
    assert result == {:ok, [], state}

    assert {:error, _} = parse(state(state, buffer: "*12x\r\n"))
    assert {:error, _} = parse(state(state, buffer: "*12\n"))
    assert {:error, _} = parse(state(state, buffer: "*12"))
    assert {:error, _} = parse(state(state, buffer: "*2\r\n12"))
    assert {:error, _} = parse(state(state, buffer: "*2\r\n$1x"))
    assert {:error, _} = parse(state(state, buffer: "*2\r\n$1\r\nx1234567890123456"))
    assert {:error, _} = parse(state(state, buffer: "*2\r\n$10\r\n123"))
    assert {:error, _} = parse(state(state, buffer: cmd(~w/*2 $3 SET $1 a $1 1/)))
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

      reset_socket(state, "*#{len}\r\n#{buffer}")
      assert parse(state) == {:ok, cmd, state}
    end
  end

  test "parse_inline", %{state: state} do
    result = parse(state(state, buffer: "SET a 1\r\n"))
    assert result == {:ok, ["SET", "a", "1"], state}

    result = parse(state(state, buffer: "SET  a 1\n"))
    assert result == {:ok, ["SET", "a", "1"], state}

    result = parse(state(state, buffer: "\r\nSET a 1\r\n"))
    assert result == {:ok, [], state(state, buffer: "SET a 1\r\n")}

    result = parse(state(state, buffer: "SET key val\r\nGET key\r\n"))
    assert result == {:ok, ["SET", "key", "val"], state(state, buffer: "GET key\r\n")}

    reset_socket(state, "\r\nGET val\r\n")
    result = parse(state(state, buffer: "SET key val"))
    assert result == {:ok, ["SET", "key", "val"], state(state, buffer: "GET val\r\n")}

    reset_socket(state, "\nGET val\r\n")
    result = parse(state(state, buffer: "SET key val\r"))
    assert result == {:ok, ["SET", "key", "val"], state(state, buffer: "GET val\r\n")}
  end
end
