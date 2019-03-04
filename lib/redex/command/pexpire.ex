defmodule Redex.Command.PEXPIRE do
  use Redex.Command

  def exec([key, timeout], state) do
    String.to_integer(timeout)
  rescue
    ArgumentError -> reply({:error, "ERR value is not an integer or out of range"}, state)
  else
    timeout -> expire(key, timeout, state)
  end

  def exec(_, state), do: wrong_arg_error("PEXPIRE") |> reply(state)

  def expire(key, timeout, state = state(quorum: quorum, db: db)) do
    if Redex.readonly?(quorum) do
      {:error, "READONLY You can't write against a read only replica."}
    else
      now = System.os_time(:millisecond)

      {:atomic, result} =
        :mnesia.sync_transaction(fn ->
          case :mnesia.read(:redex, {db, key}, :write) do
            [{:redex, {^db, ^key}, value, expiry}] when expiry > now ->
              :mnesia.write({:redex, {db, key}, value, now + timeout})
              1

            _ ->
              0
          end
        end)

      result
    end
    |> reply(state)
  end
end
