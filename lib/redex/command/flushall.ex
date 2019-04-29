defmodule Redex.Command.FLUSHALL do
  use Redex.Command

  def exec([], state = state(quorum: quorum)) do
    if readonly?(quorum) do
      {:error, "READONLY You can't write against a read only replica."}
    else
      {:atomic, :ok} = :mnesia.clear_table(:redex)
      :ok
    end
    |> reply(state)
  end

  def exec(_, state), do: wrong_arg_error("FLUSHALL") |> reply(state)
end
