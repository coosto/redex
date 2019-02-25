defmodule Redex.Command.GET do
  use Redex.Command

  def exec([key], state = state(db: db)) do
    now = System.os_time(:millisecond)

    case :mnesia.dirty_read(:redex, {db, key}) do
      [{:redex, {^db, ^key}, value, expiry}] when expiry > now and is_binary(value) ->
        value

      [{:redex, {^db, ^key}, _value, expiry}] when expiry > now ->
        {:error, "WRONGTYPE Operation against a key holding the wrong kind of value"}

      _ ->
        nil
    end
    |> reply(state)
  end

  def exec(_, state), do: wrong_arg_error("GET") |> reply(state)
end
