defmodule Redex.Protocol do
  @behaviour :ranch_protocol

  @crlf "\r\n"
  @cr "\r"
  @lf "\n"

  alias Redex.Command

  def start_link(ref, _socket, transport, _opts) do
    Task.start_link(__MODULE__, :init, [ref, transport])
  end

  def init(ref, transport) do
    {:ok, socket} = :ranch.handshake(ref)

    consistent = Application.get_env(:redex, :consistency) != "EVENTUAL"

    loop(
      transport,
      socket,
      %{consistent: consistent, db: 0, channels: []},
      "",
      &parse/1
    )

    transport.close(socket)
  end

  defp loop(transport, socket, state, "", parser) do
    transport.setopts(socket, active: :once)

    receive do
      {:push, data} ->
        transport.send(socket, encode(data))
        loop(transport, socket, state, "", parser)

      {:tcp, ^socket, buffer} ->
        loop(transport, socket, state, buffer, parser)

      _ ->
        :ok
    end
  end

  defp loop(transport, socket, state, buffer, parser) do
    case parser.(buffer) do
      {:ok, cmd, buffer} ->
        {response, state} = Command.process(cmd, state)
        transport.send(socket, encode(response))
        loop(transport, socket, state, buffer, &parse/1)

      {:cont, parser} ->
        loop(transport, socket, state, "", parser)

      {:error, msg} ->
        transport.send(socket, encode_error(msg))
        transport.close(socket)
    end
  end

  def parse(""), do: {:cont, &parse/1}
  def parse("+" <> rest), do: parse_simple_string(rest)
  def parse("-" <> rest), do: parse_error(rest)
  def parse(":" <> rest), do: parse_integer(rest)
  def parse("$" <> rest), do: parse_bulk_string(rest)
  def parse("*" <> rest), do: parse_array(rest)
  def parse(@crlf), do: {:cont, &parse/1}
  def parse(@crlf <> rest), do: parse(rest)
  def parse(data), do: parse_inline(data)

  def parse_simple_string(data, buffer \\ "") do
    crlf_split(data, buffer, &parse_simple_string/2, & &1)
  end

  def parse_error(data, buffer \\ "") do
    crlf_split(data, buffer, &parse_error/2, & &1)
  end

  def parse_integer(data, buffer \\ "") do
    crlf_split(data, buffer, &parse_integer/2, &String.to_integer/1)
  end

  def parse_bulk_string(data, buffer \\ "") do
    case parse_integer(data, buffer) do
      {:ok, -1, rest} -> {:ok, nil, rest}
      {:ok, length, rest} when length >= 0 -> parse_bulk_string_content(rest, length)
      {:ok, _, _} -> {:error, "ERR invalid bulk string"}
      {:cont, _} -> {:cont, &parse_bulk_string(&1, buffer <> data)}
      {:error, _} -> {:error, "ERR invalid bulk string"}
    end
  end

  def parse_bulk_string_content(data, length) do
    case data do
      <<string::bytes-size(length), @crlf, rest::bytes>> ->
        {:ok, string, rest}

      data when byte_size(data) < length + 2 ->
        {:cont, &parse_bulk_string_content(data <> &1, length)}

      _ ->
        {:error, "ERR invalid bulk string"}
    end
  end

  def parse_array(data, buffer \\ "") do
    case parse_integer(data, buffer) do
      {:ok, -1, rest} -> {:ok, nil, rest}
      {:ok, length, rest} when length >= 0 -> parse_array_elements(rest, length)
      {:ok, _, _} -> {:error, "ERR invalid resp array"}
      {:cont, _} -> {:cont, &parse_array(&1, buffer <> data)}
    end
  end

  def parse_array_elements(data, length, acc \\ [], parser \\ &parse/1)

  def parse_array_elements(data, 0, acc, _parser) do
    {:ok, Enum.reverse(acc), data}
  end

  def parse_array_elements(data, length, acc, parser) do
    case parser.(data) do
      {:ok, item, rest} -> parse_array_elements(rest, length - 1, [item | acc])
      {:cont, parser} -> {:cont, &parse_array_elements(&1, length, acc, parser)}
      error -> error
    end
  end

  def parse_inline(data, buffer \\ "") do
    crlf_split(data, buffer, &parse_inline/2, &String.split/1)
  end

  def encode(nil), do: "$-1#{@crlf}"
  def encode(:noreply), do: ""
  def encode(:ok), do: encode_simple_string("OK")
  def encode(:pong), do: encode_simple_string("PONG")
  def encode({:error, msg}), do: encode_error(msg)
  def encode({:binary, data}), do: data
  def encode(value) when is_integer(value), do: encode_integer(value)
  def encode(value) when is_binary(value), do: encode_bulk_string(value)
  def encode(value) when is_list(value), do: encode_array(value)

  def encode_simple_string(value), do: "+#{value}#{@crlf}"
  def encode_error(value), do: "-#{value}#{@crlf}"
  def encode_integer(value), do: ":#{value}#{@crlf}"
  def encode_bulk_string(value), do: "$#{byte_size(value)}#{@crlf}#{value}#{@crlf}"

  def encode_array(list) do
    encoded = list |> Enum.map(&encode/1) |> Enum.join()
    "*#{length(list)}#{@crlf}#{encoded}"
  end

  defp crlf_split(data, buffer, parser, decoder) do
    size = byte_size(buffer) - 1

    case {buffer, data} do
      {<<value::bytes-size(size), @cr>>, <<@lf, rest::bytes>>} ->
        {:ok, decoder.(value), rest}

      _ ->
        case String.split(data, @crlf, parts: 2, trim: false) do
          [^data] -> {:cont, &parser.(&1, buffer <> data)}
          [value, rest] -> {:ok, decoder.(buffer <> value), rest}
        end
    end
  rescue
    _ -> {:error, "ERR failed parsing command"}
  end
end
