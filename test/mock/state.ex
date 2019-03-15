defmodule Redex.Mock.State do
  import ExUnit.Callbacks
  import Redex.Protocol.State
  alias Redex.Mock.Transport

  def mock_state() do
    {:ok, socket} = start_supervised({Agent, fn -> %{in: "", out: ""} end})
    state(transport: Transport, socket: socket)
  end

  def reset_state(state(socket: socket), input \\ "") do
    Agent.cast(socket, fn _ -> %{in: input, out: ""} end)
    state(transport: Transport, socket: socket)
  end

  def get_output(state(socket: socket)) do
    Agent.get(socket, fn %{out: out} -> out end)
  end
end
