defmodule Redex do
  use Task, restart: :transient

  require Logger

  def start_link([]) do
    Task.start_link(__MODULE__, :init, [])
  end

  def init do
    Logger.info("waiting for other nodes to be connected ...")
    nodes = wait_for_nodes()
    Logger.info("connected nodes: #{inspect(nodes)}")

    :ok = update_db_nodes(nodes)

    created =
      :mnesia.create_table(:redex,
        ram_copies: [node() | nodes],
        attributes: [:key, :value, :expiry]
      )

    case created do
      {:atomic, :ok} ->
        Logger.info("redex table successfully created")
        start_server()

      {:aborted, {:already_exists, :redex}} ->
        replicas = :mnesia.table_info(:redex, :where_to_write)

        if node() in replicas do
          Logger.info("redex table already exists")
        else
          source = hd(replicas)
          Logger.info("copy data from #{source} ...")

          {:atomic, :ok} =
            :rpc.call(source, :mnesia, :add_table_copy, [:redex, node(), :ram_copies])
        end

        start_server()

      {:aborted, reason} ->
        Logger.error(inspect(reason))
        :init.restart()
    end
  end

  def start_server do
    port = Application.get_env(:redex, :port)
    opts = %{socket_opts: [port: port], num_acceptors: 20, max_connections: 10000}

    Logger.info("[tcp] starting redex server on port #{port}")

    :ranch.start_listener(
      :redex,
      :ranch_tcp,
      opts,
      Redex.Protocol,
      []
    )
  end

  def connect_node(node) do
    connected = Node.connect(node)
    :ok = update_db_nodes(Node.list(:connected))
    connected
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

  defp wait_for_nodes(timeout \\ 30)
  defp wait_for_nodes(0), do: Node.list(:connected)

  defp wait_for_nodes(timeout) do
    case Node.list(:connected) do
      [] ->
        Process.sleep(1000)
        wait_for_nodes(timeout - 1)

      nodes ->
        nodes
    end
  end
end
