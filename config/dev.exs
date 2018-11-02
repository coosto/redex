use Mix.Config

port =
  case node() do
    :"node1@127.0.0.1" -> 63791
    :"node2@127.0.0.1" -> 63792
    :"node3@127.0.0.1" -> 63793
    _ -> 6379
  end

config :redex, port: port

config :libcluster,
  topologies: [
    epmd: [
      strategy: Elixir.Cluster.Strategy.Epmd,
      config: [
        hosts: [:"node1@127.0.0.1", :"node2@127.0.0.1", :"node3@127.0.0.1"]
      ],
      connect: {Redex, :connect_node, []}
    ]
  ]
