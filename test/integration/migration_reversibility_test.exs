defmodule TheBand.Integration.MigrationReversibilityTest do
  @moduledoc """
  FR-008, SC-015 — migrações aplicam e revertem sem erro, em base vazia e em base já
  inicializada.

  ## Por que isto é teste, e não apenas um comando no roteiro de validação

  Migração que não reverte é armadilha de implantação: descobre-se no momento em que se precisa
  voltar, que é o pior momento possível. Um comando no roteiro só protege quem lembra de
  rodá-lo; um teste protege todo mundo.

  ## Por que fora da execução padrão

  Marcado `:integration` porque derruba e recria o esquema do banco de teste. Rodar isso a cada
  `mix test` seria lento e conflitaria com os outros testes. O fluxo de verificação automática
  o executa como passo próprio (FR-034).

  Também `async: false`: o teste manipula o esquema inteiro, então nada mais pode estar usando
  o banco ao mesmo tempo.
  """

  use ExUnit.Case, async: false

  @moduletag :integration

  alias Ecto.Adapters.SQL
  alias Ecto.Adapters.SQL.Sandbox
  alias Ecto.Migrator

  @repo TheBand.Repo

  setup do
    # Sandbox desligado para o repositório durante estes testes.
    #
    # `Sandbox.checkout(repo, sandbox: false)` não basta: `Ecto.Migrator.run/4` executa numa
    # Task própria, que precisa da sua própria conexão, e no modo `:manual` o sandbox recusa
    # entregá-la — o erro observado foi
    # `could not checkout the connection owned by #PID<...>`.
    #
    # Também não serve rodar migração dentro de transação de sandbox: DDL seria descartado no
    # fim do teste, e o teste passaria sem provar nada.
    Sandbox.mode(@repo, :auto)

    on_exit(fn ->
      # Deixa a base migrada, senão os testes seguintes encontrariam esquema ausente.
      Migrator.run(@repo, migrations_path(), :up, all: true, log: false)
      Sandbox.mode(@repo, :manual)
    end)

    :ok
  end

  defp migrations_path, do: Application.app_dir(:the_band, "priv/repo/migrations")

  defp aplicadas do
    @repo
    |> Migrator.migrations(migrations_path())
    |> Enum.filter(fn {status, _version, _name} -> status == :up end)
    |> Enum.map(fn {_status, version, _name} -> version end)
  end

  test "reverte tudo e reaplica sem erro" do
    assert aplicadas() != [], "a base de teste deveria começar migrada"

    Migrator.run(@repo, migrations_path(), :down, all: true, log: false)
    assert aplicadas() == [], "sobrou migração aplicada depois de reverter tudo"

    Migrator.run(@repo, migrations_path(), :up, all: true, log: false)
    assert aplicadas() != [], "reaplicar não trouxe as migrações de volta"
  end

  test "aplicar em base já migrada não tem efeito e não falha" do
    antes = aplicadas()

    # Segunda aplicação precisa ser inofensiva: o processo de inicialização do roteiro de
    # validação roda `mix ecto.migrate` sem saber se a base já está migrada.
    assert [] == Migrator.run(@repo, migrations_path(), :up, all: true, log: false)
    assert aplicadas() == antes
  end

  test "reverter em base vazia não falha" do
    Migrator.run(@repo, migrations_path(), :down, all: true, log: false)

    assert [] == Migrator.run(@repo, migrations_path(), :down, all: true, log: false)
    assert aplicadas() == []
  end

  test "as tabelas do Oban desaparecem ao reverter e voltam ao reaplicar" do
    # A reversão da migração do Oban vai até a versão 1 justamente para não deixar tabela de
    # pé. Sem esta asserção, uma reversão parcial passaria como sucesso.
    assert oban_jobs_existe?()

    Migrator.run(@repo, migrations_path(), :down, all: true, log: false)
    refute oban_jobs_existe?(), "oban_jobs sobreviveu à reversão"

    Migrator.run(@repo, migrations_path(), :up, all: true, log: false)
    assert oban_jobs_existe?()
  end

  defp oban_jobs_existe? do
    %{rows: [[existe]]} =
      SQL.query!(
        @repo,
        "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'oban_jobs')",
        []
      )

    existe
  end
end
