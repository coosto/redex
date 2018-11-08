use Mix.Config

config :libcluster,
  topologies: [
    k8s: [
      strategy: Redex.Cluster.Strategy.Kubernetes,
      config: [
        kubernetes_node_basename: "redex",
        kubernetes_selector: "${REDEX_SELECTOR}"
      ]
    ]
  ]
