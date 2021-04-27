import Config

config :redex,
  port: System.get_env("REDEX_PORT", "6379") |> String.to_integer(),
  quorum: System.get_env("REDEX_QUORUM", "1") |> String.to_integer()

web_hosts = ~w(
  redex@web-beta-us-central1-a-001
  redex@web-beta-us-central1-a-002
  redex@web-beta-us-central1-a-003
  redex@web-beta-us-central1-a-004
  redex@web-beta-us-central1-a-005
  redex@web-beta-us-central1-a-006
  redex@web-beta-us-central1-a-007
  redex@web-beta-us-central1-a-008
  redex@web-beta-us-central1-a-009
  redex@web-beta-us-central1-a-010
  redex@web-beta-us-central1-a-011
)a

auth_payments_hosts = ~w(
  redex@blitz-auth-001
  redex@blitz-auth-002
  redex@blitz-payments-001
)a

config :libcluster, :topologies,
  epmd: [
   strategy: Cluster.Strategy.Epmd,
   config: [hosts: "HOSTS@GO_HERE"]
  ]

if Mix.env() == :test, do: import_config("test.exs")
