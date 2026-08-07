defmodule TheBand.MixProject do
  use Mix.Project

  def project do
    [
      app: :the_band,
      version: "0.1.0",
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore.exs",
        plt_add_apps: [:mix, :ex_unit],
        # O ambiente entra no nome do arquivo de propósito. Com um nome fixo, `mix dialyzer`
        # em `:dev` e em `:test` sobrescrevem o mesmo PLT — verificado: o arquivo passou de
        # 5.664.703 para 5.535.132 bytes ao alternar — e cada troca de ambiente força uma
        # reconstrução completa de ~1m23s. Isso consumiria o orçamento de 10 minutos de
        # SC-012 e tornaria o cache do fluxo de verificação inútil.
        plt_file: {:no_warn, "priv/plts/dialyzer-#{Mix.env()}.plt"}
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {TheBand.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # `gates` PRECISA estar aqui. O alias termina em `test`, e `mix test` se recusa a rodar fora do
  # ambiente `:test`. Sem esta entrada, `mix gates` executa quatro dos cinco portões, morre no quinto
  # com `** (Mix) "mix test" is running in the "dev" environment` e sai com código 1 — enquanto
  # `CLAUDE.md` e `README.md` o documentam como o comando que roda os cinco. Verificado: issue #29.
  #
  # Consequência aceita: `mix gates` passa a usar `priv/plts/dialyzer-test.plt` em vez do de `dev`,
  # porque o nome do PLT inclui o ambiente de propósito (ver a configuração de `dialyzer` acima). A
  # primeira execução após esta mudança reconstrói aquele PLT.
  def cli do
    [
      preferred_envs: [gates: :test, precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  #
  # `credo_checks/` is deliberately absent here. Project-specific Credo checks are loaded by
  # Credo itself via the `requires:` option in `.credo.exs`, which reads the source directly.
  # Adding the directory to `elixirc_paths` as well makes the module be both compiled and
  # required, producing `warning: redefining module` on every run. Verified — see
  # specs/001-phoenix-foundation-governance/research.md R5.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.8.9"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.14"},
      # Pinned to the 0.22 line on purpose: the latest published version is 1.0.0-rc.1, a
      # pre-release we must not adopt in the foundation. See research.md R1.
      {:postgrex, "~> 0.22"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.2.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.5", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:daisyui,
       github: "saadeghi/daisyui",
       tag: "v5.5.20",
       sparse: "packages/bundle",
       app: false,
       compile: false,
       depth: 1},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      # Pinned to the 1.4 line: the latest published version is 1.5.0-alpha.2 (research.md R1).
      {:jason, "~> 1.4"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},

      # Background work: queues, retries, scheduling. Constitution-mandated stack.
      {:oban, "~> 2.23"},

      # HTTP client for the connectors that arrive in feature 025. No connector here yet.
      {:req, "~> 0.7"},

      # Quality gates
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mox, "~> 1.2", only: :test},

      # Base de conhecimento declarativa (feature 002). Escolhida POR MEDIÇÃO, não por
      # conveniência — ver docs/adr/0005-biblioteca-yaml-e-portao-de-tokens.md e
      # specs/002-knowledge-base-infrastructure/research.md, R1 a R11.
      #
      # Ela já estava aqui como dependência transitiva `only: [:dev, :test]` do `mix_audit`, com um
      # aviso dizendo que aquela presença NÃO era a escolha. A escolha foi feita depois, medindo:
      # `fast_yaml` foi descartada por não compilar sem `libyaml` do sistema, e `yamerl` puro por
      # lançar em vez de devolver erro e por entregar charlists.
      #
      # Duas regras de uso, cada uma com medição por trás:
      #
      #   1. SEMPRE `read_all_from_string/2`. NUNCA `read_from_string/2`, que devolve apenas o
      #      último documento de um arquivo com vários, descartando os anteriores em silêncio, e
      #      devolve `%{}` para arquivo vazio — indistinguível de mapeamento vazio legítimo (R8);
      #   2. SEMPRE atravessar `TheBand.Knowledge.TokenGate` antes. Um arquivo de 814 bytes de
      #      apelidos aninhados NÃO TERMINA em 15 segundos e mata o processo, e nenhuma biblioteca
      #      de YAML oferece limite de nós (R6).
      {:yaml_elixir, "~> 2.12"},

      # FR-033 exige reprovar dependência com vulnerabilidade conhecida. `mix hex.audit`, que
      # é embutido, só detecta pacote aposentado — não avisos de segurança. `mix_audit` compara
      # `mix.lock` com a base de avisos do ecossistema Elixir.
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind the_band", "esbuild the_band"],
      "assets.deploy": [
        "tailwind the_band --minify",
        "esbuild the_band --minify",
        "phx.digest"
      ],
      # The five quality gates, in the order the constitution requires.
      #
      # The order is not cosmetic: `mix credo` does NOT compile the project first, so the
      # project-specific checks under `credo_checks/` are only loaded if `compile` already
      # ran. Without compiling first, Credo prints "Ignoring an undefined check" and exits 0
      # — a silent no-op that would leave SC-002 unverified. See research.md R5.
      gates: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo --strict",
        "dialyzer",
        "test",
        # A partir da feature 002. A constituição lista as três verificações de conhecimento entre os
        # portões obrigatórios; `knowledge.validate` é a primeira a existir. `knowledge.graph` e
        # `knowledge.test` entram nas issues #24 e #26.
        #
        # Depois de `test` de propósito: ela lê o disco e não depende de compilação de teste, mas
        # falhar aqui deve significar "a base está quebrada", não "os testes não rodaram".
        "knowledge.validate"
      ],
      precommit: ["deps.unlock --unused", "format", "gates"]
    ]
  end
end
