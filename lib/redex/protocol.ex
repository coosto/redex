defmodule Redex.Protocol do
  @behaviour :ranch_protocol

  import Redex.Protocol.State
  import Redex.Protocol.Parser
  import Redex.Protocol.Encoder

  alias Redex.Command

  def start_link(ref, _socket, transport, quorum: quorum) do
    Task.start_link(__MODULE__, :init, [ref, transport, quorum])
  end

  def init(ref, transport, quorum) do
    {:ok, socket} = :ranch.handshake(ref)

    state(transport: transport, socket: socket, quorum: quorum)
    |> loop()
  end

  def loop(state = state(transport: transport, socket: socket, buffer: "")) do
    transport.setopts(socket, active: :once)

    receive do
      {:push, data} ->
        data
        |> reply(state)
        |> loop()

      {:tcp, ^socket, buffer} ->
        state(state, buffer: buffer)
        |> loop()

      error ->
        error
    end
  end

  def loop(state = state(transport: transport, socket: socket)) do
    case parse(state) do
      {:ok, cmd, state} ->
        cmd
        |> Command.exec(state)
        |> loop()

      error = {:error, _} ->
        transport.send(socket, encode(error))
        transport.close(socket)
    end
  end
end
