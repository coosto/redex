defmodule Redex.Cleaner do
  use GenServer

  require Logger

  @clean_interval 60_000
  @name __MODULE__

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  def init([]) do
    {:ok, nil, {:continue, :init}}
  end

  def handle_continue(:init, state) do
    :mnesia.wait_for_tables([:redex], :infinity)
    :timer.send_interval(@clean_interval, :clean)
    {:noreply, state}
  end

  def handle_info(:clean, state) do
    :global.register_name(@name, self())

    if :global.whereis_name(@name) == self() do
      Logger.info("cleaning expired cache entries")
      now = System.os_time(:millisecond)

      deleted =
        :mnesia.dirty_select(:redex, [
          {{:redex, :"$1", :"$2", :"$3"}, [{:<, :"$3", now}], [:"$_"]}
        ])
        |> Enum.reduce(0, fn object, deleted ->
          :mnesia.dirty_delete_object(object)
          deleted + 1
        end)

      Logger.info("#{deleted} expired entries cleaned")
    end

    {:noreply, state}
  end
end
