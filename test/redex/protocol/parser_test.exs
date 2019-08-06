defmodule Redex.Protocol.ParserTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Redex.DataGenerators
  import Redex.Protocol.Parser

  alias Redex.Protocol.State

  setup :verify_on_exit!

  defp cmd(cmd), do: Enum.join(cmd, "\r\n") <> "\r\n"

  test "parse" do
    state = %State{buffer: cmd(~w/*3 $3 SET $1 a $1 1/)}
    assert parse(state) == {:ok, ["SET", "a", "1"], %{state | buffer: ""}}

    state = %State{buffer: cmd(~w/*5 $3 SET $1 a $1 1 $2 EX $2 10/)}
    assert parse(state) == {:ok, ["SET", "a", "1", "EX", "10"], %{state | buffer: ""}}

    state = %State{buffer: cmd(~w/*2 $3 GET $1 a *2 $3 GET $1 b/)}
    assert parse(state) == {:ok, ["GET", "a"], %{state | buffer: cmd(~w/*2 $3 GET $1 b/)}}

    state = %State{buffer: "*0\r\n"}
    assert parse(state) == {:ok, [], %{state | buffer: ""}}

    ProtocolMock
    |> expect(:recv, 3, fn %State{}, 0 -> {:error, :closed} end)

    assert {:error, _} = %State{buffer: "*12x\r\n"} |> parse()
    assert {:error, _} = %State{buffer: "*12\n"} |> parse()
    assert {:error, _} = %State{buffer: "*12"} |> parse()
    assert {:error, _} = %State{buffer: "*2\r\n12"} |> parse()
    assert {:error, _} = %State{buffer: "*2\r\n$1x"} |> parse()
    assert {:error, _} = %State{buffer: "*2\r\n$1\r\nx1234567890123456"} |> parse()

    ProtocolMock
    |> expect(:recv, fn %State{}, 9 -> {:error, :closed} end)

    assert {:error, _} = %State{buffer: "*2\r\n$10\r\n123"} |> parse()
    assert {:error, _} = %State{buffer: cmd(~w/*2 $3 SET $1 a $1 1/)} |> parse()
  end

  property "parse with randomly generated data" do
    check all state <- state(),
              cmd <- list_of(binary()),
              len = length(cmd) do
      buffer =
        cmd
        |> Enum.map(fn data -> "$#{byte_size(data)}\r\n#{data}\r\n" end)
        |> Enum.join()

      state = %{state | buffer: "*#{len}\r\n#{buffer}"}
      assert parse(state) == {:ok, cmd, %{state | buffer: ""}}
    end
  end

  property "parse partial data" do
    check all state <- state(),
              cmd <- list_of(binary()),
              len = length(cmd) do
      buffer =
        cmd
        |> Enum.map(fn data -> "$#{byte_size(data)}\r\n#{data}\r\n" end)
        |> Enum.join()

      buffer = "*#{len}\r\n#{buffer}"

      recv = fn state = %{transport: recv, socket: socket, buffer: buffer}, size ->
        size = if size == 0, do: Enum.at(positive_integer(), 0), else: size
        <<data::bytes-size(size), socket::bytes>> = socket

        if socket != "" do
          ProtocolMock
          |> expect(:recv, recv)
        end

        %{state | socket: socket, buffer: buffer <> data}
      end

      ProtocolMock
      |> expect(:recv, recv)

      state = %{state | transport: recv, socket: buffer}

      assert parse(state) == {:ok, cmd, %{state | socket: ""}}
    end
  end

  test "parse_inline" do
    state = %State{buffer: "SET a 1\r\n"}
    assert parse(state) == {:ok, ["SET", "a", "1"], %{state | buffer: ""}}

    state = %State{buffer: "SET  a 1\n"}
    assert parse(state) == {:ok, ["SET", "a", "1"], %{state | buffer: ""}}

    state = %State{buffer: "\r\nSET a 1\r\n"}
    assert parse(state) == {:ok, [], %{state | buffer: "SET a 1\r\n"}}

    state = %State{buffer: "SET key val\r\nGET key\r\n"}
    assert parse(state) == {:ok, ["SET", "key", "val"], %{state | buffer: "GET key\r\n"}}

    state = %State{buffer: "SET key val"}

    ProtocolMock
    |> expect(:recv, fn ^state, 0 ->
      %{state | buffer: state.buffer <> "\r\nGET val\r\n"}
    end)

    assert parse(state) == {:ok, ["SET", "key", "val"], %{state | buffer: "GET val\r\n"}}

    state = %State{buffer: "SET key val\r"}

    ProtocolMock
    |> expect(:recv, fn ^state, 0 ->
      %{state | buffer: state.buffer <> "\nGET val\r\n"}
    end)

    assert parse(state) == {:ok, ["SET", "key", "val"], %{state | buffer: "GET val\r\n"}}
  end
end
