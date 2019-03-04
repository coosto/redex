defmodule Redex.Protocol.Parser do
  import NimbleParsec
  import Redex.Protocol.State

  crlf = string("\r\n")
  empty_bulk_string = string("$0\r\n\r\n")

  short_bulk_strings =
    for len <- 1..24 do
      string("$#{len}\r\n")
      |> ignore()
      |> ascii_string([], len)
      |> ignore(crlf)
    end

  bulk_string = choice([empty_bulk_string | short_bulk_strings])

  large_bulk_string =
    string("$")
    |> ignore()
    |> integer(min: 2, max: 9)
    |> ignore(crlf)

  defparsecp :parse_array,
             string("*")
             |> ignore()
             |> integer(min: 1, max: 6)
             |> ignore(crlf)
             |> label("a * followed by a number terminated with a CRLF")
             |> repeat(bulk_string)

  defparsecp :parse_string,
             choice([large_bulk_string, times(bulk_string, min: 1)])
             |> label("a RESP array of bulk strings")

  def parse(state = state(buffer: buffer)) do
    case parse_array(buffer) do
      {:ok, acc, buffer, _, _, _} ->
        state
        |> state(acc: acc, buffer: buffer)
        |> parse_cont(length(acc) - 1)

      {:error, _, buffer, _, _, _} when buffer in ["", "\r"] ->
        state
        |> recv(0)
        |> parse()

      {:error, error, _, _, _, _} ->
        case buffer do
          <<"*", _::bytes>> -> {:error, "ERR Protocol error: #{error}"}
          _ -> parse_inline(state)
        end
    end
  end

  def parse(error = {:error, _}), do: error

  def parse_inline(state = state(buffer: buffer)) do
    buffer
    |> String.replace("\r\n", "\n")
    |> String.split("\n", parts: 2, trim: false)
    |> case do
      [_buffer] ->
        state
        |> recv(0)
        |> parse()

      [line, buffer] ->
        {:ok, String.split(line), state(state, buffer: buffer)}
    end
  end

  defp parse_cont(state = state(acc: [len | cmd]), len) do
    {:ok, cmd, state(state, acc: [])}
  end

  defp parse_cont(state = state(acc: acc, buffer: ""), len) when len < hd(acc) do
    state
    |> recv(0)
    |> parse_cont(len)
  end

  defp parse_cont(state = state(acc: acc, buffer: buffer), len) when len < hd(acc) do
    case parse_string(buffer) do
      {:ok, [size], buffer, _, _, _} when is_integer(size) and byte_size(buffer) >= size + 2 ->
        case buffer do
          <<string::bytes-size(size), "\r\n", rest::bytes>> ->
            state
            |> state(acc: acc ++ [string], buffer: rest)
            |> parse_cont(len + 1)

          _ ->
            {:error, "ERR Protocol error: expected bulk string terminated with a CRLF"}
        end

      {:ok, [size], buffer, _, _, _} when is_integer(size) ->
        state
        |> state(buffer: buffer)
        |> recv(size + 2 - byte_size(buffer))
        |> case do
          state(buffer: <<string::bytes-size(size), "\r\n">>) ->
            state
            |> state(acc: acc ++ [string], buffer: "")
            |> parse_cont(len + 1)

          state() ->
            {:error, "ERR Protocol error: expected bulk string terminated with a CRLF"}

          error = {:error, _} ->
            error
        end

      {:ok, strings, buffer, _, _, _} ->
        state
        |> state(acc: acc ++ strings, buffer: buffer)
        |> parse_cont(len + length(strings))

      {:error, _, _, _, _, _} when byte_size(buffer) < 32 ->
        state
        |> recv(0)
        |> parse_cont(len)

      {:error, error, _, _, _, _} ->
        {:error, "ERR Protocol error: #{error}"}
    end
  end

  defp parse_cont(state(), _), do: {:error, "ERR Protocol error"}
  defp parse_cont(error = {:error, _}, _), do: error
end
