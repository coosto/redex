defmodule Redex.Command.QUIT do
  use Redex.Command

  def exec(_args, state = state(transport: transport, socket: socket)) do
    reply(:ok, state)
    transport.close(socket)
    state
  end
end
