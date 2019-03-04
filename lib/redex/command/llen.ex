defmodule Redex.Command.LLEN do
  use Redex.Command

  def exec([key], state = state(db: db)) do
    now = System.os_time(:millisecond)

    case :mnesia.dirty_read(:redex, {db, key}) do
      [{:redex, {^db, ^key}, list, expiry}] when expiry > now and is_list(list) ->
        length(list)

      [{:redex, {^db, ^key}, _value, expiry}] when expiry > now ->
        {:error, "WRONGTYPE Operation against a key holding the wrong kind of value"}

      _ ->
        0
    end
    |> reply(state)
  end

  def exec(_, state), do: wrong_arg_error("LLEN") |> reply(state)
end
