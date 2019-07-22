defmodule Redex.Command.INFO do
  use Redex.Command

  @sections ["keyspace"]

  defp exec([]), do: section(:all)
  defp exec([section]), do: String.downcase(section) |> section()
  defp exec(_), do: wrong_arg_error("INFO")

  defp section(:all) do
    @sections
    |> Enum.map(&section/1)
    |> Enum.join()
  end

  for section <- @sections do
    defp section(unquote(section)) do
      unquote(:"#{section}")()
    end
  end

  defp section(_section), do: ""

  defp keyspace do
    now = System.os_time(:millisecond)
    first = Mnesia.dirty_first(:redex)

    keyspace =
      keyspace(now, first, %{})
      |> Enum.map(fn {db, info} ->
        "db#{db}:keys=#{info.keys},expires=#{info.expires},avg_ttl=#{info.avg_ttl}\r\n"
      end)
      |> Enum.join()

    "# Keyspace\r\n#{keyspace}"
  end

  defp keyspace(_now, :"$end_of_table", acc), do: acc

  defp keyspace(now, key, acc) do
    next = Mnesia.dirty_next(:redex, key)

    acc =
      case Mnesia.dirty_read(:redex, key) do
        [{:redex, {db, _key}, _value, expiry}] when expiry > now ->
          acc = Map.put_new(acc, db, %{keys: 0, expires: 0, avg_ttl: 0})
          acc = update_in(acc[db].keys, &(&1 + 1))

          if expiry do
            ttl = expiry - now
            acc = update_in(acc[db].expires, &(&1 + 1))

            update_in(
              acc[db].avg_ttl,
              &Float.ceil((&1 * (acc[db].expires - 1) + ttl) / acc[db].expires)
            )
          else
            acc
          end

        _ ->
          acc
      end

    keyspace(now, next, acc)
  end
end
