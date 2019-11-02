defmodule Redex.Manager do
  use GenServer

  require Logger

  def start_link(quorum) do
    GenServer.start_link(__MODULE__, %{quorum: quorum}, name: __MODULE__)
  end

  def init(state) do
    node = node()
    :ok = :mnesia.start()
    {:ok, ^node} = :mnesia.subscribe(:system)
    :ok = :net_kernel.monitor_nodes(true)

    nodes = wait_for_nodes(state.quorum)
    Logger.info("connected nodes: #{inspect(nodes)}")

    :ok = add_nodes(nodes)

    :mnesia.create_table(:redex,
      ram_copies: [node | nodes],
      attributes: [:key, :value, :expiry]
    )
    |> case do
      {:atomic, :ok} ->
        Logger.info("redex table successfully created")
        {:ok, state}

      {:aborted, {:already_exists, :redex}} ->
        replicas = :mnesia.table_info(:redex, :where_to_write)

        if node in replicas do
          Logger.info("redex table already exists")
        else
          source = hd(replicas)
          Logger.info("copy data from #{source} ...")

          case :rpc.call(source, :mnesia, :add_table_copy, [:redex, node, :ram_copies]) do
            {:atomic, :ok} -> :ok
            {:aborted, {:already_exists, :redex, ^node}} -> :ok
          end
        end

        {:ok, state}

      {:aborted, reason} ->
        Logger.error(inspect(reason))
        :mnesia.stop()
        init(state)
    end
  end

  defp restart_nodes(nodes, state) do
    :rpc.multicall(nodes, :mnesia, :stop, [])
    :rpc.multicall(nodes -- [node()], :init, :restart, [])

    if node() in nodes do
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  defp add_nodes(nodes) do
    :global.trans(
      {:redex_add_nodes, self()},
      fn ->
        case :mnesia.change_config(:extra_db_nodes, nodes) do
          {:ok, _} ->
            :ok

          {:error, reason} ->
            Logger.error(inspect(reason))
            :mnesia.stop()
            {:error, reason}
        end
      end
    )
  end

  defp wait_for_nodes(quorum) do
    nodes = Node.list()
    current = length(nodes) + 1

    if current < quorum do
      Logger.info("waiting for quorum (#{current}/#{quorum}) ...")

      receive do
        {:nodeup, _} -> wait_for_nodes(quorum)
      end
    else
      Logger.info("quorum is satisfied (#{current}/#{quorum})")
      nodes
    end
  end

  def handle_info(
        {:mnesia_system_event, {:inconsistent_database, :running_partitioned_network, node}},
        state
      ) do
    :global.trans(
      {:redex_partition, self()},
      fn ->
        local_nodes = :mnesia.system_info(:running_db_nodes)
        remote_nodes = :rpc.call(node, :mnesia, :system_info, [:running_db_nodes])
        true = is_list(remote_nodes)
        local_readonly = length(local_nodes) < state.quorum
        remote_readonly = length(remote_nodes) < state.quorum
        parts = {local_nodes, remote_nodes}

        cond do
          node in local_nodes ->
            Logger.info("network partition is already healed")
            {:noreply, state}

          local_nodes -- remote_nodes != local_nodes ->
            Logger.warn("network partition detected: #{inspect(parts)}")
            symmetric_diff = (local_nodes -- remote_nodes) ++ (remote_nodes -- local_nodes)
            restart_nodes(symmetric_diff, state)

          local_readonly and remote_readonly ->
            Logger.info("connecting two readonly partitions: #{inspect(parts)}")
            :ok = add_nodes(remote_nodes)
            {:noreply, state}

          true ->
            Logger.info("sync readonly partition with active partition: #{inspect(parts)}")

            (length(local_nodes) > length(remote_nodes) && remote_nodes) ||
              local_nodes
              |> restart_nodes(state)
        end
      end,
      [node() | Node.list()]
    )
  end

  def handle_info({:nodeup, node}, state) do
    local_nodes = :mnesia.system_info(:running_db_nodes)
    remote_nodes = :rpc.call(node, :mnesia, :system_info, [:running_db_nodes])

    if node in :mnesia.system_info(:db_nodes) or length(local_nodes) > length(remote_nodes) do
      {:noreply, state}
    else
      case add_nodes([node]) do
        :ok -> {:noreply, state}
        _ -> {:stop, :normal, state}
      end
    end
  end

  def handle_info(event, state) do
    Logger.info("event received: #{inspect(event)}")
    {:noreply, state}
  end
end
