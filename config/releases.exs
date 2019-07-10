import Config

config :redex,
  port: System.get_env("REDEX_PORT", "6379") |> String.to_integer(),
  quorum: System.get_env("REDEX_QUORUM", "2") |> String.to_integer()

if System.get_env("REDEX_K8S_SELECTOR") do
  config :libcluster, :topologies,
    k8s: [
      strategy: Cluster.Strategy.Kubernetes,
      config: [
        kubernetes_ip_lookup_mode: :pods,
        kubernetes_node_basename: "redex",
        kubernetes_namespace: System.get_env("REDEX_K8S_NAMESPACE"),
        kubernetes_selector: System.get_env("REDEX_K8S_SELECTOR")
      ]
    ]
else
  config :libcluster, :topologies,
    gossip: [
      strategy: Cluster.Strategy.Gossip,
      config: [
        port: 45892,
        if_addr: "0.0.0.0",
        multicast_addr: "230.1.1.251",
        multicast_ttl: 1,
        secret: System.get_env("REDEX_GOSSIP_SECRET", "REDEX")
      ]
    ]
end
