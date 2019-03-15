defmodule Redex.Command.PING do
  use Redex.Command

  defp exec([]), do: :pong
  defp exec([message]), do: message
  defp exec(_), do: wrong_arg_error("PING")
end
