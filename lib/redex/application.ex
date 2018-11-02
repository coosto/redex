defmodule Redex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies)

    children = [
      {Cluster.Supervisor, [topologies, [name: Redex.ClusterSupervisor]]},
      Redex,
      Redex.Cleaner
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Redex.Supervisor)
  end
end
