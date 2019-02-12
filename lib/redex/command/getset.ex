defmodule Redex.Command.GETSET do
  use Redex.Command

  def exec([key, value], state = state(quorum: quorum, db: db)) do
    if Redex.readonly?(quorum) do
      {:error, "READONLY You can't write against a read only replica."}
    else
      now = System.os_time(:millisecond)

      {:atomic, result} =
        :mnesia.sync_transaction(fn ->
          result =
            case :mnesia.read(:redex, {db, key}, :write) do
              [{:redex, {^db, ^key}, value, expiry}] when expiry > now ->
                value

              _ ->
                nil
            end

          :mnesia.write({:redex, {db, key}, value, nil})
          result
        end)

      result
    end
    |> reply(state)
  end

  def exec(_, state), do: wrong_arg_error("GETSET") |> reply(state)
end
