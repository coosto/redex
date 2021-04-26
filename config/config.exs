import Config

config :redex,
  port: System.get_env("REDEX_PORT", "6379") |> String.to_integer(),
  quorum: System.get_env("REDEX_QUORUM", "1") |> String.to_integer()

web_hosts = ~w(
  blitz_web@web-beta-us-central1-a-001
  blitz_web@web-beta-us-central1-a-002
  blitz_web@web-beta-us-central1-a-003
  blitz_web@web-beta-us-central1-a-004
  blitz_web@web-beta-us-central1-a-005
  blitz_web@web-beta-us-central1-a-006
  blitz_web@web-beta-us-central1-a-007
  blitz_web@web-beta-us-central1-a-008
  blitz_web@web-beta-us-central1-a-009
  blitz_web@web-beta-us-central1-a-010
  blitz_web@web-beta-us-central1-a-011
)a

auth_payments_hosts = ~w(
  blitz_auth@blitz-auth-001
  blitz_auth@blitz-auth-002
  blitz_payments@blitz-payments-001
)a

config :libcluster, :topologies,
  epmd: [
   strategy: Cluster.Strategy.Epmd,
   config: [hosts: "HOSTS@GO_HERE"]
  ]

if Mix.env() == :test, do: import_config("test.exs")
