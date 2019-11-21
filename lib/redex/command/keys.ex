defmodule Redex.Command.KEYS do
  use Redex.Command

  def exec([pattern], state = %State{db: db}) do
    now = System.os_time(:millisecond)

    "^#{pattern}$"
    |> String.replace("?", ".")
    |> String.replace("*", ".*")
    |> Regex.compile()
    |> case do
      {:ok, pattern} ->
        Mnesia.dirty_select(:redex, [
          {{:redex, {db, :"$1"}, :_, :"$2"}, [{:>, :"$2", now}], [:"$1"]}
        ])
        |> Enum.filter(&String.match?(&1, pattern))

      {:error, _} ->
        {:error, "Invalid pattern"}
    end
    |> reply(state)
  end

  def exec(_, state), do: wrong_arg_error("KEYS") |> reply(state)
end
