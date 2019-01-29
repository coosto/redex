defmodule Redex.Command.PING do
  use Redex.Command

  def exec([]), do: :pong
  def exec([message]), do: message
  def exec(_), do: wrong_arg_error("PING")
end
