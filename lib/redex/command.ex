defmodule Redex.Command do
  alias Redex.Command.{SET, DEL, INFO}

  def process(cmd, state) do
    upcase_cmd(cmd) |> exec(state)
  end

  def exec(["SELECT", db], state) do
    db = String.to_integer(db)

    if db in 0..100 do
      {:ok, %{state | db: db}}
    else
      {{:error, "ERR DB index is out of range"}, state}
    end
  rescue
    ArgumentError -> {{:error, "ERR invalid DB index"}, state}
  end

  # def exec(["SUBSCRIBE" | channels], state) do
  #   subscribe(channels)
  #   {:noreply, %{state | channels: channels}}
  # end

  def exec(["SET", key, value | args], state = %{db: db}) do
    case args |> Enum.map(&String.upcase/1) |> SET.args() do
      {:ok, args} ->
        expiry = if args["PX"], do: System.system_time(:milliseconds) + args["PX"]
        nodes = :mnesia.system_info(:running_db_nodes)

        cond do
          length(nodes) < state.quorum ->
            {{:error, "READONLY You can't write against a read only replica."}, state}

          length(nodes) == 1 ->
            :ok = :mnesia.dirty_write({:redex, {db, key}, value, expiry})
            {:ok, state}

          true ->
            {:atomic, :ok} =
              :mnesia.sync_transaction(fn ->
                :mnesia.write({:redex, {db, key}, value, expiry})
              end)

            {:ok, state}
        end

      error ->
        {error, state}
    end
  rescue
    ArgumentError -> {{:error, "ERR syntax error"}, state}
  end

  def exec(["GET", key], state = %{db: db}) do
    now = System.system_time(:milliseconds)

    case :mnesia.dirty_read(:redex, {db, key}) do
      [{:redex, {^db, ^key}, value, expiry}] when expiry > now ->
        {value, state}

      _ ->
        {nil, state}
    end
  end

  def exec(["DEL", key | rest], state = %{db: db}) do
    if Redex.readonly?(state.quorum) do
      {{:error, "READONLY You can't write against a read only replica."}, state}
    else
      {DEL.delete(db, [key | rest]), state}
    end
  end

  def exec(["TTL", key], state) do
    with {ttl, state} when ttl > 0 <- exec(["PTTL", key], state) do
      {trunc(ttl / 1000), state}
    end
  end

  def exec(["PTTL", key], state = %{db: db}) do
    now = System.system_time(:milliseconds)

    case :mnesia.dirty_read(:redex, {db, key}) do
      [{:redex, {^db, ^key}, _value, nil}] ->
        {-1, state}

      [{:redex, {^db, ^key}, _value, expiry}] when expiry > now ->
        {expiry - now, state}

      _ ->
        {-2, state}
    end
  end

  def exec(cmd, state) do
    {exec(cmd), state}
  end

  def exec(["FLUSHALL"]) do
    {:atomic, :ok} = :mnesia.clear_table(:redex)
    :ok
  end

  def exec(["PING"]), do: :pong
  def exec(["PING", message]), do: message

  def exec(["INFO"]), do: INFO.section(:all)
  def exec(["INFO", section]), do: String.downcase(section) |> INFO.section()

  # def exec(["INCR" | _]), do: 1
  # def exec(["DECR" | _]), do: 1

  def exec(["QUIT" | _]) do
    send(self(), :close)
    :ok
  end

  def exec([cmd | _]) do
    if cmd in ["FLUSHALL", "DEL", "SET", "GET", "PING", "TTL", "PTTL"],
      do: {:error, "ERR wrong number of arguments for '#{cmd}' command"},
      else: {:error, "ERR unknown command '#{cmd}'"}
  end

  def exec(_cmd), do: {:error, "ERR invalid command"}

  # defp subscribe(channels, count \\ 1)
  # defp subscribe([], _count), do: :ok

  # defp subscribe([ch | channels], count) do
  #   send(self(), {:push, ["subscribe", ch, count]})
  #   subscribe(channels, count + 1)
  # end

  defp upcase_cmd([cmd | args]) when is_binary(cmd),
    do: [String.upcase(cmd) | args]

  defp upcase_cmd(cmd), do: cmd
end
