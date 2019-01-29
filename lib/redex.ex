defmodule Redex do
  use GenServer

  require Logger

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(state) do
    :mnesia.subscribe(:system)
    nodes = wait_for_nodes(state.quorum)
    Logger.info("connected nodes: #{inspect(nodes)}")

    :ok = update_db_nodes(nodes)
    node = node()

    created =
      :mnesia.create_table(:redex,
        ram_copies: [node | nodes],
        attributes: [:key, :value, :expiry]
      )

    case created do
      {:atomic, :ok} ->
        Logger.info("redex table successfully created")
        start_server(state)

      {:aborted, {:already_exists, :redex}} ->
        replicas = :mnesia.table_info(:redex, :where_to_write)

        if node in replicas do
          Logger.info("redex table already exists")
        else
          source = hd(replicas)
          Logger.info("copy data from #{source} ...")

          copy = :rpc.call(source, :mnesia, :add_table_copy, [:redex, node, :ram_copies])

          case copy do
            {:atomic, :ok} -> :ok
            {:aborted, {:already_exists, :redex, ^node}} -> :ok
          end
        end

        start_server(state)

      {:aborted, reason} ->
        Logger.error(inspect(reason))
        :init.restart()
    end

    {:ok, state}
  end

  def start_server(%{port: port, quorum: quorum}) do
    opts = %{socket_opts: [port: port], num_acceptors: 20, max_connections: 10_000}

    Logger.info("[tcp] starting redex server on port #{port}")

    :ranch.start_listener(
      :redex,
      :ranch_tcp,
      opts,
      Redex.Protocol,
      quorum: quorum
    )
  end

  defp update_db_nodes(nodes) do
    case :mnesia.change_config(:extra_db_nodes, nodes) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.error(inspect(reason))
        :init.restart()
        :error
    end
  end

  defp wait_for_nodes(quorum) do
    nodes = Node.list(:connected)

    if length(nodes) + 1 < quorum do
      Logger.info("waiting for other nodes to be connected ...")
      Process.sleep(1000)
      wait_for_nodes(quorum)
    else
      nodes
    end
  end

  defp restart_nodes(nodes) do
    for node <- nodes -- [node()] do
      Logger.info("restarting #{node} ...")
      :rpc.call(node, :init, :restart, [])
    end

    if node() in nodes do
      :init.restart()
    end

    :ok
  end

  def readonly?(quorum) do
    nodes = :mnesia.system_info(:running_db_nodes)
    length(nodes) < quorum
  end

  def handle_info(
        {:mnesia_system_event, {:inconsistent_database, :running_partitioned_network, node}},
        state
      ) do
    :global.set_lock({:partition, self()})
    nodes = :mnesia.system_info(:running_db_nodes)
    remote_nodes = :rpc.call(node, :mnesia, :system_info, [:running_db_nodes])
    true = is_list(remote_nodes)
    readonly = length(nodes) < state.quorum
    remote_readonly = length(remote_nodes) < state.quorum
    Logger.warn("network partition detected: #{inspect(nodes)} #{inspect(remote_nodes)}")

    cond do
      node in nodes or nodes == [] or remote_nodes == [] ->
        Logger.info("partition is already recovered")

      nodes -- remote_nodes != nodes ->
        unhealthy_nodes = (nodes -- remote_nodes) ++ (remote_nodes -- nodes)
        Logger.info("restarting nodes not present in all partitions ...")
        restart_nodes(unhealthy_nodes)

      readonly and remote_readonly ->
        Logger.info("connecting two readonly partitions ...")
        :ok = update_db_nodes(remote_nodes)

      readonly ->
        Logger.info("restarting this readonly partition to copy data from active partition ...")
        restart_nodes(nodes)

      remote_readonly ->
        Logger.info("we are in active partition, no need to restart.")

      true ->
        Logger.warn("two partitions are active. data might be inconsistent.")
        :ok = update_db_nodes([node])
    end

    :global.del_lock({:partition, self()})
    {:noreply, state}
  end

  def handle_info(event, state) do
    Logger.info("event received: #{inspect(event)}")
    {:noreply, state}
  end
end
