defmodule Redex.Command.DECRBY do
  use Redex.Command

  def exec([key, dec], state) do
    String.to_integer(dec)
  rescue
    ArgumentError -> reply({:error, "ERR value is not an integer or out of range"}, state)
  else
    dec -> INCRBY.inc(key, -dec, state)
  end

  def exec(_, state), do: wrong_arg_error("DECRBY") |> reply(state)
end
