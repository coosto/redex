defmodule Redex.Command.GETSET do
  use Redex.Command

  def exec([key, value], state = state(quorum: quorum, db: db)) do
    if readonly?(quorum) do
      {:error, "READONLY You can't write against a read only replica."}
    else
      now = System.os_time(:millisecond)

      {:atomic, result} =
        :mnesia.sync_transaction(fn ->
          case :mnesia.read(:redex, {db, key}, :write) do
            [{:redex, {^db, ^key}, value, expiry}] when expiry > now and is_binary(value) ->
              value

            [{:redex, {^db, ^key}, _value, expiry}] when expiry > now ->
              {:error, "WRONGTYPE Operation against a key holding the wrong kind of value"}

            _ ->
              nil
          end
          |> case do
            {:error, error} ->
              {:error, error}

            old_value ->
              :mnesia.write({:redex, {db, key}, value, nil})
              old_value
          end
        end)

      result
    end
    |> reply(state)
  end

  def exec(_, state), do: wrong_arg_error("GETSET") |> reply(state)
end
