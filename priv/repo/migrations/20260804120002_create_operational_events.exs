defmodule TheBand.Repo.Migrations.CreateOperationalEvents do
  @moduledoc """
  Eventos operacionais — a primeira entidade que **pertence** a um Tenant (FR-012, FR-018).

  Existe por uma razão estrutural, não decorativa: a tabela de Tenants não pertence a si
  mesma, então sem uma segunda entidade o requisito de que todo dado pertença a um Tenant não
  tem sujeito, e o critério de ausência de vazamento não tem objeto de teste.

  **Não é `spo.performed_activity`.** É registro de operação desta plataforma, não atividade
  de processo de software de nenhum projeto observado.
  """

  use Ecto.Migration

  def change do
    create table(:operational_events) do
      # ON DELETE RESTRICT é deliberado, e o oposto de CASCADE.
      #
      # Remover um Tenant não pode apagar seu histórico em cascata. Combinado com FR-017, que
      # manda a desativação preservar os dados, isto garante que histórico operacional não
      # desapareça por acidente — e histórico que desaparece é o fim da auditoria.
      add :tenant_id, references(:tenants, on_delete: :restrict), null: false

      add :type, :string, size: 100, null: false
      add :correlation_id, :string, size: 64, null: false
      add :occurred_at, :utc_datetime_usec, null: false

      # Dados complementares. A validação contra chave sensível fica no changeset: rejeitar na
      # escrita é mais forte que mascarar na leitura (FR-030).
      add :metadata, :map, null: false, default: %{}
    end

    # Toda consulta é escopada por Tenant e ordenada por tempo. O índice começa por `tenant_id`
    # porque é o filtro que sempre existe — padrão que vale para toda tabela tenant-scoped
    # futura, inclusive as ontológicas.
    create index(:operational_events, [:tenant_id, :occurred_at])
  end
end
