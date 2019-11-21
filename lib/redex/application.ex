defmodule Redex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    topologies =
      Application.fetch_env!(:libcluster, :topologies)
      |> Enum.filter(fn
        {:k8s, config} -> config[:config][:kubernetes_selector]
        {:gossip, config} -> config[:config][:secret]
      end)

    quorum = Application.fetch_env!(:redex, :quorum)
    port = Application.fetch_env!(:redex, :port)

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
      {SingletonSupervisor, strategy: :one_for_one, children: [Redex.Cleaner]}
    ]

    Supervisor.start_link(children, strategy: :rest_for_one, name: Redex.Supervisor)
  end
end
