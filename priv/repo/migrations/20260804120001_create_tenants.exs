defmodule TheBand.Repo.Migrations.CreateTenants do
  @moduledoc """
  Tabela de Tenants — a fronteira de isolamento da instalação (FR-009, FR-010, FR-011).

  **Tenant não é `eo.organization`.** Um Tenant é quem contrata e opera esta instalação; a
  organização de domínio, analisada, chega na feature 005 e terá `tenant_id` própria. Um
  Tenant contém várias organizações. Ver ADR-0003.

  Chave primária e timestamps herdam os padrões declarados em `config/config.exs`:
  `binary_id` e `utc_datetime_usec`.
  """

  use Ecto.Migration

  def change do
    create table(:tenants) do
      # Identificador legível. Aparece em endereço, registro operacional e diagnóstico.
      #
      # 63 caracteres não é arbitrário: é o limite de um rótulo de DNS, o que mantém a opção
      # de usar o identificador como subdomínio sem migração de dados depois.
      add :slug, :string, size: 63, null: false

      # Rótulo humano. Livre e alterável, sem exigência de unicidade: duas organizações
      # homônimas podem contratar a plataforma legitimamente (FR-011).
      add :name, :text, null: false

      # Desativar preserva os dados (FR-017). Não há coluna de remoção: remoção de Tenant não
      # é operação prevista, e as chaves estrangeiras usam RESTRICT justamente para impedi-la
      # por acidente.
      add :active, :boolean, null: false, default: true

      timestamps()
    end

    create unique_index(:tenants, [:slug])

    # A restrição vive no banco, não só na aplicação. Assim vale também para escrita feita por
    # migração, semeadura ou tarefa administrativa — caminhos que não passam pelo changeset.
    create constraint(:tenants, :slug_format,
             check: "slug ~ '^[a-z0-9-]{3,63}$'",
             comment: "Identificador legível: minúsculas, dígitos e hífen, 3 a 63 caracteres."
           )
  end
end
