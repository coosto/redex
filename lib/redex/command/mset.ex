defmodule Redex.Command.MSET do
  use Redex.Command

  def exec(pairs = [_, _ | _], state = state(quorum: quorum, db: db)) do
    if length(pairs) |> rem(2) != 0 do
      wrong_arg_error("MSET")
    else
      if Redex.readonly?(quorum) do
        {:error, "READONLY You can't write against a read only replica."}
      else
        case :mnesia.sync_transaction(fn -> mset(db, pairs) end) do
          {:atomic, :ok} -> :ok
          _ -> {:error, "ERR mset operation failed"}
        end
      end
    end
    |> reply(state)
  end

  def exec(_, state), do: wrong_arg_error("MSET") |> reply(state)

  defp mset(_db, []), do: :ok

  defp mset(db, [key, value | rest]) do
    :mnesia.write({:redex, {db, key}, value, nil})
    mset(db, rest)
  end
end
