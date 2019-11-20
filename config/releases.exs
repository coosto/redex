import Config

config :redex,
  port: System.get_env("REDEX_PORT", "6379") |> String.to_integer(),
  quorum: System.get_env("REDEX_QUORUM", "1") |> String.to_integer()

config :libcluster, :topologies,
  k8s: [
    config: [
      kubernetes_namespace: System.get_env("REDEX_K8S_NAMESPACE"),
      kubernetes_selector: System.get_env("REDEX_K8S_SELECTOR")
    ]
  ],
  gossip: [
    config: [
      secret: System.get_env("REDEX_GOSSIP_SECRET")
    ]
  ]
