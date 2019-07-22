defmodule Redex.Command.LRANGE do
  use Redex.Command

  def exec([key, start, stop], state = %State{db: db}) do
    String.to_integer(start)..String.to_integer(stop)
  rescue
    ArgumentError -> reply({:error, "ERR value is not an integer or out of range"}, state)
  else
    range ->
      now = System.os_time(:millisecond)

      case Mnesia.dirty_read(:redex, {db, key}) do
        [{:redex, {^db, ^key}, list, expiry}] when expiry > now and is_list(list) ->
          Enum.slice(list, range)

        [{:redex, {^db, ^key}, _value, expiry}] when expiry > now ->
          {:error, "WRONGTYPE Operation against a key holding the wrong kind of value"}

        _ ->
          []
      end
      |> reply(state)
  end

  def exec(_, state), do: wrong_arg_error("LRANGE") |> reply(state)
end
