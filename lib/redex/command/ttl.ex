defmodule Redex.Command.TTL do
  use Redex.Command

  def exec([key], state) do
    case PTTL.pttl(key, state) do
      ttl when ttl > 0 ->
        Float.ceil(ttl / 1000) |> trunc()

      result ->
        result
    end
    |> reply(state)
  end

  def exec(_, state), do: wrong_arg_error("TTL") |> reply(state)
end
