defmodule Redex.Command.PUBLISH do
  use Redex.Command

  import Injector

  inject :pg2, as: Pg2
  inject Manifold

  def exec([ch, msg], state) do
    Pg2.create(ch)

    case Pg2.get_members(ch) do
      {:error, _} ->
        0

      subscribers ->
        Manifold.send(subscribers, {:push, ["message", ch, msg]})
        length(subscribers)
    end
    |> reply(state)
  end

  def exec(_, state), do: wrong_arg_error("PUBLISH") |> reply(state)
end
