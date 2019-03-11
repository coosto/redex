defmodule Redex.Command.DEL do
  use Redex.Command

  def exec(keys = [_ | _], state = state(quorum: quorum, db: db)) do
    if readonly?(quorum) do
      {:error, "READONLY You can't write against a read only replica."}
    else
      delete(db, keys)
    end
    |> reply(state)
  end

  def exec(_, state), do: wrong_arg_error("DEL") |> reply(state)

  defp delete(db, keys) do
    case :mnesia.sync_transaction(fn -> delete(db, keys, 0) end) do
      {:atomic, deleted} -> deleted
      _ -> {:error, "ERR delete operation failed"}
    end
  end

  defp delete(_db, [], acc), do: acc

  defp delete(db, [key | rest], acc) do
    now = System.os_time(:millisecond)

    case :mnesia.wread({:redex, {db, key}}) do
      [{:redex, {^db, ^key}, _value, expiry}] when expiry > now ->
        :mnesia.delete({:redex, {db, key}})
        delete(db, rest, acc + 1)

      _ ->
        delete(db, rest, acc)
    end
  end
end
