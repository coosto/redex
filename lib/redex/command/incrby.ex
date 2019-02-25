defmodule Redex.Command.INCRBY do
  use Redex.Command

  def exec([key, inc], state) do
    String.to_integer(inc)
  rescue
    ArgumentError -> reply({:error, "ERR value is not an integer or out of range"}, state)
  else
    inc -> inc(key, inc, state)
  end

  def exec(_, state), do: wrong_arg_error("INCRBY") |> reply(state)

  def inc(key, inc, state = state(quorum: quorum, db: db)) do
    if Redex.readonly?(quorum) do
      {:error, "READONLY You can't write against a read only replica."}
    else
      now = System.os_time(:millisecond)

      {:atomic, result} =
        :mnesia.sync_transaction(fn ->
          case :mnesia.read(:redex, {db, key}, :write) do
            [{:redex, {^db, ^key}, value, expiry}] when expiry > now and is_binary(value) ->
              try do
                {String.to_integer(value) + inc, expiry}
              rescue
                ArgumentError -> {:error, "ERR value is not an integer or out of range"}
              end

            [{:redex, {^db, ^key}, _value, expiry}] when expiry > now ->
              {:error, "WRONGTYPE Operation against a key holding the wrong kind of value"}

            _ ->
              {inc, nil}
          end
          |> case do
            {:error, error} ->
              {:error, error}

            {value, expiry} ->
              :mnesia.write({:redex, {db, key}, Integer.to_string(value), expiry})
              value
          end
        end)

      result
    end
    |> reply(state)
  end
end
