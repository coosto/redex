defmodule Redex.MixProject do
  use Mix.Project

  def project do
    [
      app: :redex,
      version: "0.4.0",
      elixir: "~> 1.9",
      elixirc_paths: if(Mix.env() == :test, do: ["lib", "test/mock"], else: ["lib"]),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :mnesia],
      mod: {Redex.Application, []}
    ]
  end

  defp deps do
    [
      {:ranch, "~> 1.7"},
      {:libcluster, "~> 3.1"},
      {:nimble_parsec, "~> 0.5.0"},
      {:dialyxir, "~> 1.0.0-rc.6", only: [:dev], runtime: false},
      {:stream_data, "~> 0.4", only: [:test]}
    ]
  end
end
