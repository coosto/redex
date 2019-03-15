defmodule Redex.Command.IncrTest do
  use ExUnit.Case

  import Redex.Protocol.State
  import Redex.Mock.State
  import Redex.Command.INCR

  setup_all do
    [state: mock_state()]
  end

  setup %{state: state} do
    {:atomic, :ok} = :mnesia.clear_table(:redex)
    reset_state(state)
    :ok
  end

  test "INCR non existing key", %{state: state} do
    result = exec(["a"], state) |> get_output()
    assert result == ":1\r\n"
  end

  test "INCR existing key", %{state: state} do
    :ok = :mnesia.dirty_write({:redex, {0, "a"}, "2", nil})
    result = exec(["a"], state) |> get_output()
    assert result == ":3\r\n"
  end

  test "INCR in readonly mode", %{state: state} do
    result = exec(["a"], state(state, quorum: 2)) |> get_output()
    assert result == "-READONLY You can't write against a read only replica.\r\n"
  end

  test "INCR a key in db 1", %{state: state} do
    :ok = :mnesia.dirty_write({:redex, {1, "a"}, "5", nil})
    result = exec(["a"], state(state, db: 1)) |> get_output()
    assert result == ":6\r\n"
  end

  test "INCR an expired key", %{state: state} do
    expiry = System.os_time(:millisecond) - 1
    :ok = :mnesia.dirty_write({:redex, {0, "a"}, "123", expiry})
    result = exec(["a"], state) |> get_output()
    assert result == ":1\r\n"
  end

  test "INCR a key with a wrong kind of value", %{state: state} do
    :ok = :mnesia.dirty_write({:redex, {0, "a"}, ["123"], nil})
    result = exec(["a"], state) |> get_output()
    assert result == "-WRONGTYPE Operation against a key holding the wrong kind of value\r\n"
  end

  test "INCR with wrong number of arguments", %{state: state} do
    result = exec(["a", "b"], state) |> get_output()
    assert result == "-ERR wrong number of arguments for 'INCR' command\r\n"
  end
end
