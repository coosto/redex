defmodule Redex.Command.FLUSHALL do
  use Redex.Command

  def exec([]) do
    {:atomic, :ok} = :mnesia.clear_table(:redex)
    :ok
  end

  def exec(_), do: wrong_arg_error("FLUSHALL")
end
