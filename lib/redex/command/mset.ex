defmodule Redex.Command.MSET do
  use Redex.Command

  def exec(pairs = [_, _ | _], state = %State{quorum: quorum, db: db}) do
    if length(pairs) |> rem(2) != 0 do
      wrong_arg_error("MSET")
    else
      if readonly?(quorum) do
        {:error, "READONLY You can't write against a read only replica."}
      else
        case Mnesia.sync_transaction(fn -> mset(db, pairs) end) do
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
    Mnesia.write(:redex, {:redex, {db, key}, value, nil}, :write)
    mset(db, rest)
  end
end
