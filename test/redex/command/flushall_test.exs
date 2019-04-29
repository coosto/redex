defmodule Redex.Command.FlushallTest do
  use ExUnit.Case

  import Redex.Protocol.State
  import Redex.Mock.State
  import Redex.Command.FLUSHALL

  setup_all do
    [state: mock_state()]
  end

  setup %{state: state} do
    {:atomic, :ok} = :mnesia.clear_table(:redex)
    reset_state(state)
    :ok
  end

  test "FLUSHALL", %{state: state} do
    :ok = :mnesia.dirty_write({:redex, {0, "a"}, "123", nil})
    :ok = :mnesia.dirty_write({:redex, {1, "a"}, "123", nil})
    result = exec([], state) |> get_output()
    assert result == "+OK\r\n"
    assert [] == :mnesia.dirty_all_keys(:redex)
  end

  test "FLUSHALL in readonly mode", %{state: state} do
    :ok = :mnesia.dirty_write({:redex, {0, "a"}, "123", nil})
    result = exec([], state(state, quorum: 2)) |> get_output()
    assert result == "-READONLY You can't write against a read only replica.\r\n"
    assert [{0, "a"}] == :mnesia.dirty_all_keys(:redex)
  end

  test "FLUSHALL with wrong number of arguments", %{state: state} do
    result = exec(["a"], state) |> get_output()
    assert result == "-ERR wrong number of arguments for 'FLUSHALL' command\r\n"
  end
end
