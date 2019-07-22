defmodule Redex.Command.SELECT do
  use Redex.Command

  def exec([db], state) do
    String.to_integer(db)
  rescue
    ArgumentError -> reply({:error, "ERR invalid DB index"}, state)
  else
    db when db in 0..100 ->
      reply(:ok, %{state | db: db})

    _ ->
      reply({:error, "ERR DB index is out of range"}, state)
  end

  def exec(_, state), do: wrong_arg_error("SELECT") |> reply(state)
end
