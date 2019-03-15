defmodule Redex.Command.MgetTest do
  use ExUnit.Case

  import Redex.Protocol.State
  import Redex.Mock.State
  import Redex.Command.MGET

  setup_all do
    [state: mock_state()]
  end

  setup %{state: state} do
    {:atomic, :ok} = :mnesia.clear_table(:redex)
    reset_state(state)
    :ok
  end

  test "MGET non existing keys", %{state: state} do
    result = exec(["a", "b"], state) |> get_output()
    assert result == "*2\r\n$-1\r\n$-1\r\n"
  end

  test "MGET existing keys", %{state: state} do
    :ok = :mnesia.dirty_write({:redex, {0, "a"}, "123", nil})
    :ok = :mnesia.dirty_write({:redex, {0, "b"}, "456", nil})
    result = exec(["a", "b"], state) |> get_output()
    assert result == "*2\r\n$3\r\n123\r\n$3\r\n456\r\n"
  end

  test "MGET a combination of existing and non exsisting keys", %{state: state} do
    :ok = :mnesia.dirty_write({:redex, {0, "a"}, "123", nil})
    result = exec(["a", "b"], state) |> get_output()
    assert result == "*2\r\n$3\r\n123\r\n$-1\r\n"
  end

  test "MGET keys from db 1", %{state: state} do
    :ok = :mnesia.dirty_write({:redex, {1, "a"}, "123", nil})
    :ok = :mnesia.dirty_write({:redex, {1, "b"}, "123", nil})
    result = exec(["a", "b"], state(state, db: 1)) |> get_output()
    assert result == "*2\r\n$3\r\n123\r\n$3\r\n123\r\n"
  end

  test "MGET expired keys", %{state: state} do
    expiry = System.os_time(:millisecond) - 1
    :ok = :mnesia.dirty_write({:redex, {0, "a"}, "123", expiry})
    :ok = :mnesia.dirty_write({:redex, {0, "b"}, "123", expiry})
    result = exec(["a", "b"], state) |> get_output()
    assert result == "*2\r\n$-1\r\n$-1\r\n"
  end

  test "MGET keys with a wrong kind of value", %{state: state} do
    :ok = :mnesia.dirty_write({:redex, {0, "a"}, ["123"], nil})
    :ok = :mnesia.dirty_write({:redex, {0, "b"}, "123", nil})
    result = exec(["a", "b"], state) |> get_output()
    assert result == "*2\r\n$-1\r\n$3\r\n123\r\n"
  end

  test "MGET with wrong number of arguments", %{state: state} do
    result = exec([], state) |> get_output()
    assert result == "-ERR wrong number of arguments for 'MGET' command\r\n"
  end
end
