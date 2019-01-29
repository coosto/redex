defmodule Redex.Command.SUBSCRIBE do
  use Redex.Command

  def exec(channels, state) when channels != [] do
    subscribe(channels, state)
  end

  defp subscribe([], state), do: state

  defp subscribe([ch | channels], state = state(channels: subscribed)) do
    subscribed =
      if ch in subscribed do
        subscribed
      else
        [ch | subscribed]
      end

    reply(["subscribe", ch, length(subscribed)], state)
    subscribe(channels, state)
  end
end
