defmodule Redex.Command.PingTest do
  use ExUnit.Case

  import Redex.Mock.State
  import Redex.Command.PING

  setup_all do
    [state: mock_state()]
  end

  setup %{state: state} do
    reset_state(state)
    :ok
  end

  test "PING without message", %{state: state} do
    result = exec([], state) |> get_output()
    assert result == "+PONG\r\n"
  end

  test "PING with message", %{state: state} do
    result = exec(["hello"], state) |> get_output()
    assert result == "$5\r\nhello\r\n"
  end

  test "PING with wrong number of arguments", %{state: state} do
    result = exec(["hello", "world"], state) |> get_output()
    assert result == "-ERR wrong number of arguments for 'PING' command\r\n"
  end
end
