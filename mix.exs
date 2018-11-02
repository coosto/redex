defmodule Redex.MixProject do
  use Mix.Project

  def project do
    [
      app: :redex,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :mnesia],
      mod: {Redex.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ranch, "~> 1.6"},
      {:libcluster, "~> 3.0"},
      {:distillery, "~> 2.0"}
    ]
  end
end
