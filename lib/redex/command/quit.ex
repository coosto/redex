defmodule Redex.Command.QUIT do
  use Redex.Command

  def exec(_args, state = %State{transport: transport, socket: socket}) do
    reply(:ok, state)
    transport.close(socket)
    state
  end
end
