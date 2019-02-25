defmodule Redex.Command.LPOP do
  use Redex.Command

  def exec([key], state = state(quorum: quorum, db: db)) do
    if Redex.readonly?(quorum) do
      {:error, "READONLY You can't write against a read only replica."}
    else
      now = System.os_time(:millisecond)

      {:atomic, result} =
        :mnesia.sync_transaction(fn ->
          case :mnesia.read(:redex, {db, key}, :write) do
            [{:redex, {^db, ^key}, [value], expiry}] when expiry > now ->
              :mnesia.delete({:redex, {db, key}})
              value

            [{:redex, {^db, ^key}, [value | list], expiry}] when expiry > now ->
              :mnesia.write({:redex, {db, key}, list, expiry})
              value

            [{:redex, {^db, ^key}, _value, expiry}] when expiry > now ->
              {:error, "WRONGTYPE Operation against a key holding the wrong kind of value"}

            _ ->
              nil
          end
        end)

      result
    end
    |> reply(state)
  end

  def exec(_, state), do: wrong_arg_error("LPOP") |> reply(state)
end
