defmodule Redex.Command.LINDEX do
  use Redex.Command

  def exec([key, index], state = %State{db: db}) do
    String.to_integer(index)
  rescue
    ArgumentError -> reply({:error, "ERR value is not an integer or out of range"}, state)
  else
    index ->
      now = System.os_time(:millisecond)

      case Mnesia.dirty_read(:redex, {db, key}) do
        [{:redex, {^db, ^key}, list, expiry}] when expiry > now and is_list(list) ->
          Enum.at(list, index)

        [{:redex, {^db, ^key}, _value, expiry}] when expiry > now ->
          {:error, "WRONGTYPE Operation against a key holding the wrong kind of value"}

        _ ->
          nil
      end
      |> reply(state)
  end

  def exec(_, state), do: wrong_arg_error("LINDEX") |> reply(state)
end
