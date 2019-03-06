defmodule Redex.Command.SETEX do
  use Redex.Command

  def exec([key, ex, value], state) do
    String.to_integer(ex)
  rescue
    ArgumentError -> reply({:error, "ERR value is not an integer or out of range"}, state)
  else
    ex ->
      [key, value, %{expiry: System.os_time(:millisecond) + ex * 1000, nx: false, xx: false}]
      |> SET.exec(state)
  end

  def exec(_, state), do: wrong_arg_error("SETEX") |> reply(state)
end
