import Config

config :redex,
  port: System.get_env("REDEX_PORT", "6379") |> String.to_integer(),
  quorum: System.get_env("REDEX_QUORUM", "1") |> String.to_integer()

config :libcluster, :topologies,
  gossip: [
    strategy: Cluster.Strategy.Gossip,
    config: [
      port: 45892,
      if_addr: "0.0.0.0",
      multicast_addr: "230.1.1.251",
      multicast_ttl: 1,
      secret: "REDEX"
    ]
  ]

if Mix.env() == :test, do: import_config("test.exs")
