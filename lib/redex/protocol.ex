defmodule Redex.Protocol do
  @behaviour :ranch_protocol

  import Redex.Protocol.Parser
  import Redex.Protocol.Encoder

  alias Redex.Command
  alias Redex.Protocol.State

  @callback recv(State.t(), non_neg_integer) :: State.t() | {:error, any}
  @callback reply(any, State.t()) :: State.t()

  def start_link(ref, _socket, transport, quorum) do
    Task.start_link(__MODULE__, :init, [ref, transport, quorum])
  end

  def init(ref, transport, quorum) do
    {:ok, socket} = :ranch.handshake(ref)

    %State{transport: transport, socket: socket, quorum: quorum}
    |> loop()
  end

  def loop(state = %State{transport: transport, socket: socket, buffer: ""}) do
    transport.setopts(socket, active: :once)

    receive do
      {:push, data} ->
        data
        |> reply(state)
        |> loop()

      {:tcp, ^socket, buffer} ->
        %{state | buffer: buffer}
        |> loop()

      error ->
        error
    end
  end

  def loop(state = %State{transport: transport, socket: socket}) do
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

  def recv(state = %State{transport: transport, socket: socket, buffer: buffer}, size) do
    case transport.recv(socket, size, :infinity) do
      {:ok, data} ->
        %{state | buffer: buffer <> data}

      error = {:error, _} ->
        error
    end
  end

  def reply(data, state = %State{transport: transport, socket: socket}) do
    transport.send(socket, encode(data))
    state
  end
end
