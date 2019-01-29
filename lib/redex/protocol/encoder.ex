defmodule Redex.Protocol.Encoder do
  def encode(:ok), do: "+OK\r\n"
  def encode(value) when is_binary(value), do: "$#{byte_size(value)}\r\n#{value}\r\n"
  def encode(value) when is_integer(value), do: ":#{value}\r\n"
  def encode(nil), do: "$-1\r\n"
  def encode(:pong), do: "+PONG\r\n"
  def encode({:error, msg}), do: "-#{msg}\r\n"
  def encode(list) when is_list(list), do: encode(list, "*#{length(list)}\r\n")

  defp encode([item | rest], acc), do: encode(rest, acc <> encode(item))
  defp encode([], acc), do: acc
end
