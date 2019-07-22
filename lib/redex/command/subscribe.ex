defmodule Redex.Command.SUBSCRIBE do
  use Redex.Command

  def exec(channels, state) when channels != [] do
    subscribe(channels, state)
  end

  def exec(_, state), do: wrong_arg_error("SUBSCRIBE") |> reply(state)

  defp subscribe([], state), do: state

  defp subscribe([ch | channels], state = %State{channels: subscribed}) do
    subscribed =
      if ch in subscribed do
        subscribed
      else
        :pg2.create(ch)
        :pg2.join(ch, self())
        [ch | subscribed]
      end

    reply(["subscribe", ch, length(subscribed)], state)
    subscribe(channels, state)
  end
end
