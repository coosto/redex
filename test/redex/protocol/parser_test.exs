defmodule Redex.Protocol.ParserTest do
  use ExUnit.Case
  use ExUnitProperties

  import Redex.Protocol.State
  alias Redex.Protocol.Parser

  @state state(transport: Redex.Mock.Transport, socket: %{data: ""})

  defp cmd(cmd), do: Enum.join(cmd, "\r\n") <> "\r\n"

  test "test parse" do
    result = Parser.parse(state(@state, buffer: cmd(~w/*3 $3 SET $1 a $1 1/)))
    assert result == {:ok, ["SET", "a", "1"], @state}

    result = Parser.parse(state(@state, buffer: cmd(~w/*5 $3 SET $1 a $1 1 $2 EX $2 10/)))
    assert result == {:ok, ["SET", "a", "1", "EX", "10"], @state}

    result = Parser.parse(state(@state, buffer: cmd(~w/*2 $3 GET $1 a *2 $3 GET $1 b/)))
    assert result == {:ok, ["GET", "a"], state(@state, buffer: cmd(~w/*2 $3 GET $1 b/))}

    result = Parser.parse(state(@state, buffer: "*0\r\n"))
    assert result == {:ok, [], @state}
  end

  test "test parse with randomly generated data" do
    check all len <- StreamData.integer(0..100) do
      cmd =
        StreamData.binary()
        |> Enum.take(len)

      buffer =
        cmd
        |> Enum.map(fn data -> "$#{byte_size(data)}\r\n#{data}\r\n" end)
        |> Enum.join()

      buffer = "*#{len}\r\n#{buffer}"
      result = Parser.parse(state(@state, buffer: buffer))
      assert result == {:ok, cmd, @state}
    end
  end

  test "test parse_inline" do
    result = Parser.parse(state(@state, buffer: "SET a 1\r\n"))
    assert result == {:ok, ["SET", "a", "1"], @state}

    result = Parser.parse(state(@state, buffer: "SET  a 1\n"))
    assert result == {:ok, ["SET", "a", "1"], @state}

    result = Parser.parse(state(@state, buffer: "\r\nSET a 1\r\n"))
    assert result == {:ok, [], state(@state, buffer: "SET a 1\r\n")}

    result = Parser.parse(state(@state, buffer: "SET key val\r\nGET key\r\n"))
    assert result == {:ok, ["SET", "key", "val"], state(@state, buffer: "GET key\r\n")}

    state = state(@state, socket: %{data: "\r\nGET val\r\n"}, buffer: "SET key val")
    result = Parser.parse(state)
    assert result == {:ok, ["SET", "key", "val"], state(state, buffer: "GET val\r\n")}

    state = state(@state, socket: %{data: "\nGET val\r\n"}, buffer: "SET key val\r")
    result = Parser.parse(state)
    assert result == {:ok, ["SET", "key", "val"], state(state, buffer: "GET val\r\n")}
  end
end
