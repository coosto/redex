defmodule Redex.MixProject do
  use Mix.Project

  def project do
    [
      app: :redex,
      version: "0.3.0",
      elixir: "~> 1.8",
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
      {:confex, "~> 3.4"},
      {:ranch, "~> 1.7"},
      {:libcluster, github: "bitwalker/libcluster"},
      {:distillery, "~> 2.0"},
      {:nimble_parsec, "~> 0.5.0"},
      {:dialyxir, "~> 1.0.0-rc.4", only: [:dev], runtime: false},
      {:stream_data, "~> 0.4.2", only: [:test]}
    ]
  end
end
