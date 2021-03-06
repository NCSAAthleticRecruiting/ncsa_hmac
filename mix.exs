defmodule NcsaHmac.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ncsa_hmac,
      version: release_version(),
      elixir: "~> 1.0",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :ecto, :timex, :json, :plug, :httpoison]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:ecto, ">= 1.1.0"},
      {:timex, "~> 3.0"},
      {:json, "~> 0.3.0"},
      {:plug, "~> 1.0"},
      {:httpoison, "~> 1.0"},
      {:bypass, "~> 1.0", only: :test},
      {:ex_doc, "~> 0.19", only: :dev},
      {:credo, "~> 0.4", only: :dev}
    ]
  end

  defp release_version do
    {:ok, version} = File.read('RELEASE_VERSION')
    String.trim(version)
  end
end
