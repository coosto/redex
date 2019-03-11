use Mix.Config

config :redex,
  port: {:system, :integer, "REDEX_PORT", 6379},
  quorum: {:system, :integer, "REDEX_QUORUM", if(Mix.env() == :prod, do: 2, else: 1)},
  cluster: {:system, :atom, "REDEX_CLUSTER", if(Mix.env() == :prod, do: :k8s, else: :gossip)}

config :libcluster, :topologies,
  k8s: [
    strategy: Cluster.Strategy.Kubernetes,
    config: [
      kubernetes_ip_lookup_mode: :pods,
      kubernetes_node_basename: "redex",
      kubernetes_namespace: {:system, "REDEX_K8S_NAMESPACE", nil},
      kubernetes_selector: {:system, "REDEX_K8S_SELECTOR", "app=redex"}
    ]
  ],
  gossip: [
    strategy: Cluster.Strategy.Gossip,
    config: [
      port: 45892,
      if_addr: "0.0.0.0",
      multicast_addr: "230.1.1.251",
      multicast_ttl: 1,
      secret: {:system, "REDEX_GOSSIP_SECRET", "REDEX"}
    ]
  ]
