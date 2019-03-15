defmodule Redex.Command.GetTest do
  use ExUnit.Case

  import Redex.Protocol.State
  import Redex.Mock.State
  import Redex.Command.GET

  setup_all do
    [state: mock_state()]
  end

  setup %{state: state} do
    {:atomic, :ok} = :mnesia.clear_table(:redex)
    reset_state(state)
    :ok
  end

  test "GET non existing key", %{state: state} do
    result = exec(["a"], state) |> get_output()
    assert result == "$-1\r\n"
  end

  test "GET existing key", %{state: state} do
    :ok = :mnesia.dirty_write({:redex, {0, "a"}, "123", nil})
    result = exec(["a"], state) |> get_output()
    assert result == "$3\r\n123\r\n"
  end

  test "GET a key from db 1", %{state: state} do
    :ok = :mnesia.dirty_write({:redex, {1, "a"}, "123", nil})
    result = exec(["a"], state(state, db: 1)) |> get_output()
    assert result == "$3\r\n123\r\n"
  end

  test "GET an expired key", %{state: state} do
    expiry = System.os_time(:millisecond) - 1
    :ok = :mnesia.dirty_write({:redex, {0, "a"}, "123", expiry})
    result = exec(["a"], state) |> get_output()
    assert result == "$-1\r\n"
  end

  test "GET a key with a wrong kind of value", %{state: state} do
    :ok = :mnesia.dirty_write({:redex, {0, "a"}, ["123"], nil})
    result = exec(["a"], state) |> get_output()
    assert result == "-WRONGTYPE Operation against a key holding the wrong kind of value\r\n"
  end

  test "GET with wrong number of arguments", %{state: state} do
    result = exec(["a", "b"], state) |> get_output()
    assert result == "-ERR wrong number of arguments for 'GET' command\r\n"
  end
end
