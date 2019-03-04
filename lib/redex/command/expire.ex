defmodule Redex.Command.EXPIRE do
  use Redex.Command

  def exec([key, timeout], state) do
    String.to_integer(timeout)
  rescue
    ArgumentError -> reply({:error, "ERR value is not an integer or out of range"}, state)
  else
    timeout -> PEXPIRE.expire(key, timeout * 1000, state)
  end

  def exec(_, state), do: wrong_arg_error("EXPIRE") |> reply(state)
end
