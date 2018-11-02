defmodule Redex.Command.SET do
  def args(args, acc \\ %{})

  def args([], acc), do: {:ok, acc}

  def args(["EX", ex | rest], acc),
    do: args(rest, Map.put(acc, "PX", String.to_integer(ex) * 1000))

  def args(["PX", px | rest], acc),
    do: args(rest, Map.put(acc, "PX", String.to_integer(px)))

  def args(["NX" | rest], acc), do: args(rest, Map.put(acc, "NX", true))
  def args(["XX" | rest], acc), do: args(rest, Map.put(acc, "XX", true))
  def args(_args, _acc), do: {:error, "ERR syntax error"}
end
