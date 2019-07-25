defmodule Redex.Command.SUBSCRIBE do
  use Redex.Command

  import Injector

  inject :pg2, as: Pg2

  def exec(channels, state) when channels != [] do
    subscribe(channels, state)
  end

  def exec(_, state), do: wrong_arg_error("SUBSCRIBE") |> reply(state)

  defp subscribe([], state), do: state

  defp subscribe([ch | channels], state = %State{channels: subscribed}) do
    state =
      if ch in subscribed do
        state
      else
        Pg2.create(ch)
        Pg2.join(ch, self())
        %{state | channels: [ch | subscribed]}
      end

    reply(["subscribe", ch, length(state.channels)], state)
    subscribe(channels, state)
  end
end
