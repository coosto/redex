defmodule Redex.Command.DEL do
  def delete(db, keys) do
    case :mnesia.transaction(fn -> delete(db, keys, 0) end) do
      {:atomic, deleted} -> deleted
      _ -> {:error, "ERR delete operation failed"}
    end
  end

  def delete(_db, [], acc), do: acc

  def delete(db, [key | rest], acc) do
    now = System.system_time(:milliseconds)

    case :mnesia.wread({:redex, {db, key}}) do
      [{:redex, {^db, ^key}, _value, expiry}] when expiry > now ->
        :mnesia.delete({:redex, {db, key}})
        delete(db, rest, acc + 1)

      _ ->
        delete(db, rest, acc)
    end
  end
end
