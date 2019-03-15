defmodule Redex.Command.SetTest do
  use ExUnit.Case

  import Redex.Protocol.State
  import Redex.Mock.State
  import Redex.Command.SET

  setup_all do
    [state: mock_state()]
  end

  setup %{state: state} do
    {:atomic, :ok} = :mnesia.clear_table(:redex)
    reset_state(state)
    :ok
  end

  test "SET a non existing key", %{state: state} do
    result = exec(["a", "1"], state) |> get_output()
    assert result == "+OK\r\n"
    assert [{:redex, {0, "a"}, "1", nil}] == :mnesia.dirty_read(:redex, {0, "a"})
  end

  test "SET an existing key", %{state: state} do
    :ok = :mnesia.dirty_write({:redex, {0, "a"}, "123", nil})
    result = exec(["a", "1"], state) |> get_output()
    assert result == "+OK\r\n"
    assert [{:redex, {0, "a"}, "1", nil}] == :mnesia.dirty_read(:redex, {0, "a"})
  end

  test "SET a key in db 1", %{state: state} do
    result = exec(["a", "1"], state(state, db: 1)) |> get_output()
    assert result == "+OK\r\n"
    assert [{:redex, {1, "a"}, "1", nil}] == :mnesia.dirty_read(:redex, {1, "a"})
  end

  test "SET a key in readonly mode", %{state: state} do
    result = exec(["a", "1"], state(state, quorum: 2)) |> get_output()
    assert result == "-READONLY You can't write against a read only replica.\r\n"
  end

  test "SET a key with expire time in seconds", %{state: state} do
    result = exec(["a", "1", "ex", "1"], state) |> get_output()
    assert result == "+OK\r\n"
    ex = System.os_time(:millisecond) + 1000
    assert [{:redex, {0, "a"}, "1", ex}] == :mnesia.dirty_read(:redex, {0, "a"})
  end

  test "SET a key with expire time in milliseconds", %{state: state} do
    result = exec(["a", "1", "px", "50"], state) |> get_output()
    assert result == "+OK\r\n"
    ex = System.os_time(:millisecond) + 50
    assert [{:redex, {0, "a"}, "1", ex}] == :mnesia.dirty_read(:redex, {0, "a"})
  end

  test "SET a key with NX option", %{state: state} do
    result = exec(["a", "1", "nx"], state) |> get_output()
    assert result == "+OK\r\n"
    assert [{:redex, {0, "a"}, "1", nil}] == :mnesia.dirty_read(:redex, {0, "a"})

    result = exec(["a", "2", "nx"], reset_state(state)) |> get_output()
    assert result == "$-1\r\n"
    assert [{:redex, {0, "a"}, "1", nil}] == :mnesia.dirty_read(:redex, {0, "a"})
  end

  test "SET a key with XX option", %{state: state} do
    result = exec(["a", "1", "xx"], state) |> get_output()
    assert result == "$-1\r\n"
    assert [] == :mnesia.dirty_read(:redex, {0, "a"})

    :ok = :mnesia.dirty_write({:redex, {0, "a"}, "123", nil})
    result = exec(["a", "2", "xx"], reset_state(state)) |> get_output()
    assert result == "+OK\r\n"
    assert [{:redex, {0, "a"}, "2", nil}] == :mnesia.dirty_read(:redex, {0, "a"})
  end

  test "SET with wrong arguments", %{state: state} do
    result = exec(["a", "b", "c"], state) |> get_output()
    assert result == "-ERR syntax error\r\n"
  end
end
