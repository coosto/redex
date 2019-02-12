defmodule Redex.Command.SETEX do
  use Redex.Command

  def exec([key, ex, value], state) do
    [key, value, %{expiry: System.os_time(:millisecond) + String.to_integer(ex) * 1000}]
    |> SET.exec(state)
  end

  def exec(_, state), do: wrong_arg_error("SETEX") |> reply(state)
end
