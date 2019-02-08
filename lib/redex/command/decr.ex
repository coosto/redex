defmodule Redex.Command.DECR do
  use Redex.Command

  def exec([key], state), do: INCRBY.inc(key, -1, state)
  def exec(_, state), do: wrong_arg_error("DECR") |> reply(state)
end
