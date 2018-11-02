use Mix.Config

config :logger, level: :debug

config :libcluster,
  topologies: [
    k8s: [
      strategy: Redex.Cluster.Strategy.Kubernetes,
      config: [
        kubernetes_node_basename: "redex",
        kubernetes_selector: "${REDEX_SELECTOR}"
      ],
      connect: {Redex, :connect_node, []}
    ]
  ]
