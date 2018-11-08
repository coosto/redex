defmodule Redex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies)
    quorum = Confex.fetch_env!(:redex, :quorum)
    port = Confex.fetch_env!(:redex, :port)
    redex_opts = %{port: port, quorum: quorum}

    children = [
      {Cluster.Supervisor, [topologies, [name: Redex.ClusterSupervisor]]},
      {Redex, redex_opts},
      Redex.Cleaner
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Redex.Supervisor)
  end
end
