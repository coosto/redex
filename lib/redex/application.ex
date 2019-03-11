defmodule Redex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    topologies = Confex.fetch_env!(:libcluster, :topologies)
    topologies = Keyword.take(topologies, [Confex.fetch_env!(:redex, :cluster)])
    quorum = Confex.fetch_env!(:redex, :quorum)
    port = Confex.fetch_env!(:redex, :port)

    server_opts = %{
      socket_opts: [port: port],
      num_acceptors: 20,
      max_connections: 10_000,
      quorum: quorum
    }

    children = [
      {Cluster.Supervisor, [topologies, [name: Redex.ClusterSupervisor]]},
      {Redex.Manager, quorum},
      {Redex.Server, server_opts},
      Redex.Cleaner
    ]

    Supervisor.start_link(children, strategy: :rest_for_one, name: Redex.Supervisor)
  end
end
