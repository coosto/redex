use Mix.Config

config :libcluster,
  topologies: [
    epmd: [
      strategy: Elixir.Cluster.Strategy.Epmd,
      config: [
        hosts: [node()]
      ]
    ]
  ]
