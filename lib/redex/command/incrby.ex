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
            [{:redex, {^db, ^key}, value, expiry}] when expiry > now ->
              try do
                {String.to_integer(value) + inc, expiry}
              rescue
                ArgumentError -> {:error, "ERR value is not an integer or out of range"}
              end

            _ ->
              {inc, nil}
          end
          |> case do
            error = {:error, _} ->
              error

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
