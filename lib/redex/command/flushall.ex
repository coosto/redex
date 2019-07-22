defmodule Redex.Command.FLUSHALL do
  use Redex.Command

  def exec([], state = %State{quorum: quorum}) do
    if readonly?(quorum) do
      {:error, "READONLY You can't write against a read only replica."}
    else
      {:atomic, :ok} = Mnesia.clear_table(:redex)
      :ok
    end
    |> reply(state)
  end

  def exec(_, state), do: {:error, "ERR syntax error"} |> reply(state)
end
