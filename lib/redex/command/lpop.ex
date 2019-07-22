defmodule Redex.Command.LPOP do
  use Redex.Command

  def exec([key], state = %State{quorum: quorum, db: db}) do
    if readonly?(quorum) do
      {:error, "READONLY You can't write against a read only replica."}
    else
      now = System.os_time(:millisecond)

      {:atomic, result} =
        Mnesia.sync_transaction(fn ->
          case Mnesia.read(:redex, {db, key}, :write) do
            [{:redex, {^db, ^key}, [value], expiry}] when expiry > now ->
              Mnesia.delete(:redex, {db, key}, :write)
              value

            [{:redex, {^db, ^key}, [value | list], expiry}] when expiry > now ->
              Mnesia.write({:redex, {db, key}, list, expiry})
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
