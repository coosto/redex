defmodule Redex.ProtocolTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox

  alias Redex.Protocol
  alias Redex.Protocol.State

  setup :verify_on_exit!

  test "Protocol connction close" do
    RanchMock
    |> expect(:handshake, fn :ref -> {:ok, :socket} end)

    TransportMock
    |> expect(:setopts, fn :socket, active: :once -> :ok end)

    {:ok, pid} = Protocol.start_link(:ref, :socket, TransportMock, 1)
    ref = Process.monitor(pid)

    send(pid, {:tcp_closed, :socket})

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
  end

  test "Protocol connction error" do
    RanchMock
    |> expect(:handshake, fn :ref -> {:ok, :socket} end)

    TransportMock
    |> expect(:setopts, fn :socket, active: :once -> :ok end)

    {:ok, pid} = Protocol.start_link(:ref, :socket, TransportMock, 1)
    ref = Process.monitor(pid)

    send(pid, {:tcp_error, :socket, :timeout})

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
  end

  property "Protocol command parsing and execution" do
    RanchMock
    |> expect(:handshake, fn :ref -> {:ok, :socket} end)

    TransportMock
    |> expect(:setopts, fn :socket, active: :once -> :ok end)

    state = %State{transport: TransportMock, socket: :socket}
    {:ok, pid} = Protocol.start_link(:ref, :socket, TransportMock, state.quorum)
    ref = Process.monitor(pid)

    check all msg <- one_of([{:tcp, :socket, binary(min_length: 1)}, {:push, binary()}]) do
      case msg do
        {:tcp, :socket, data} ->
          ParserMock
          |> expect(:parse, fn state = %State{buffer: ^data} ->
            {:ok, [data], %{state | buffer: ""}}
          end)

          CommandMock
          |> expect(:exec, fn [^data], ^state -> state end)

          TransportMock
          |> expect(:setopts, fn :socket, active: :once -> :ok end)

        {:push, data} ->
          EncoderMock
          |> expect(:encode, fn ^data -> "+#{data}" end)

          TransportMock
          |> expect(:send, fn :socket, "+" <> ^data -> :ok end)
      end

      send(pid, msg)
    end

    ParserMock
    |> expect(:parse, fn %State{buffer: "invalid command"} -> {:error, "failed"} end)

    EncoderMock
    |> expect(:encode, fn {:error, "failed"} -> "-failed\r\n" end)

    TransportMock
    |> expect(:send, fn :socket, "-failed\r\n" -> :ok end)
    |> expect(:close, fn :socket -> :ok end)

    send(pid, {:tcp, :socket, "invalid command"})

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
  end

  test "Protocol receive data in passive mode" do
    state = %State{transport: TransportMock, socket: :socket, buffer: "123"}

    TransportMock
    |> expect(:recv, fn :socket, 5, :infinity -> {:ok, "456"} end)

    assert %{state | buffer: "123456"} == Protocol.recv(state, 5)

    TransportMock
    |> expect(:recv, fn :socket, 5, :infinity -> {:error, :closed} end)

    assert {:error, :closed} == Protocol.recv(state, 5)
  end
end
