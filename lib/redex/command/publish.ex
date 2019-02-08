defmodule Redex.Command.PUBLISH do
  use Redex.Command

  def exec([ch, msg], state) do
    case :pg2.get_members(ch) do
      {:error, _} ->
        0

      subscribers ->
        for pid <- subscribers, do: send(pid, {:push, ["message", ch, msg]})
        length(subscribers)
    end
    |> reply(state)
  end

  def exec(_, state), do: wrong_arg_error("PUBLISH") |> reply(state)
end
