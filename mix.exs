defmodule Redex.MixProject do
  use Mix.Project

  def project do
    [
      app: :redex,
      version: "0.5.0",
      elixir: "~> 1.9",
      elixirc_paths: if(Mix.env() == :test, do: ["lib", "test/support"], else: ["lib"]),
      start_permanent: Mix.env() == :prod,
      cookie: "COOKIE_GOES_HERE",
      aliases: aliases(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :mnesia],
      mod: {Redex.Application, []}
    ]
  end

  defp aliases do
    [
      test: "test --no-start"
    ]
  end

  defp deps do
    [
      {:injector, "~> 0.2"},
      {:manifold, "~> 1.2"},
      {:ranch, "~> 1.7"},
      {:libcluster, "~> 3.1"},
      {:nimble_parsec, "~> 0.5.0"},
      {:singleton_supervisor, "~> 0.1"},
      {:mox, "~> 0.5", only: :test},
      {:excoveralls, "~> 0.11.1", only: :test},
      {:dialyxir, "~> 1.0.0-rc.6", only: :dev, runtime: false},
      {:stream_data, "~> 0.4", only: [:dev, :test]}
    ]
  end
end
