defmodule Redex.Command.PTTL do
  use Redex.Command

  def exec([key], state) do
    key
    |> pttl(state)
    |> reply(state)
  end

  def exec(_, state), do: wrong_arg_error("PTTL") |> reply(state)

  def pttl(key, state(db: db)) do
    now = System.os_time(:millisecond)

    case :mnesia.dirty_read(:redex, {db, key}) do
      [{:redex, {^db, ^key}, _value, nil}] ->
        -1

      [{:redex, {^db, ^key}, _value, expiry}] when expiry > now ->
        expiry - now

      _ ->
        -2
    end
  end
end
