import Config

config :redex,
  port: System.get_env("REDEX_PORT", "6379") |> String.to_integer(),
  quorum: System.get_env("REDEX_QUORUM", "1") |> String.to_integer()

config :libcluster, :topologies,
  k8s: [
    strategy: Cluster.Strategy.Kubernetes,
    config: [
      kubernetes_ip_lookup_mode: :pods,
      kubernetes_node_basename: "redex"
    ]
  ],
  gossip: [
    strategy: Cluster.Strategy.Gossip,
    config: [
      port: 45892,
      if_addr: "0.0.0.0",
      multicast_addr: "230.1.1.251",
      multicast_ttl: 1
    ]
  ]

if Mix.env() == :test, do: import_config("test.exs")
