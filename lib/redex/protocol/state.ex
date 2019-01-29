defmodule Redex.Protocol.State do
  require Record

  import Redex.Protocol.Encoder

  Record.defrecord(:state,
    transport: nil,
    socket: nil,
    buffer: "",
    acc: [],
    quorum: 2,
    db: 0,
    channels: []
  )

  def recv(state = state(transport: transport, socket: socket, buffer: buffer), size) do
    case transport.recv(socket, size, :infinity) do
      {:ok, data} ->
        state(state, buffer: buffer <> data)

      error = {:error, _} ->
        error
    end
  end

  def reply(data, state = state(transport: transport, socket: socket)) do
    transport.send(socket, encode(data))
    state
  end
end
