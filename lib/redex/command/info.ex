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

    keyspace =
      Mnesia.dirty_select(:redex, [
        {{:redex, {:"$1", :_}, :_, :"$2"}, [{:>, :"$2", now}], [{{:"$1", :"$2"}}]}
      ])
      |> Enum.reduce(%{}, fn {db, expiry}, acc ->
        stats =
          acc
          |> Map.get(db, %{keys: 0, expires: 0, ttl: 0})
          |> Map.update!(:keys, &(&1 + 1))

        stats =
          if expiry do
            stats
            |> Map.update!(:expires, &(&1 + 1))
            |> Map.update!(:ttl, &(&1 + expiry - now))
          else
            stats
          end

        Map.put(acc, db, stats)
      end)
      |> Enum.map(fn {db, %{keys: keys, expires: expires, ttl: ttl}} ->
        avg_ttl = div(ttl, expires)
        "db#{db}:keys=#{keys},expires=#{expires},avg_ttl=#{avg_ttl}\r\n"
      end)
      |> Enum.join()

    "# Keyspace\r\n#{keyspace}"
  end
end
