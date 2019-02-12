defmodule Redex.Command.MGET do
  use Redex.Command

  def exec(keys = [_ | _], state = state(db: db)) do
    keys
    |> mget(db, System.system_time(:millisecond), [])
    |> reply(state)
  end

  def exec(_, state), do: wrong_arg_error("MGET") |> reply(state)

  def mget([key | keys], db, now, acc) do
    case :mnesia.dirty_read(:redex, {db, key}) do
      [{:redex, {^db, ^key}, value, expiry}] when expiry > now ->
        mget(keys, db, now, [value | acc])

      _ ->
        mget(keys, db, now, [nil | acc])
    end
  end

  def mget([], _db, _now, acc), do: Enum.reverse(acc)
end
