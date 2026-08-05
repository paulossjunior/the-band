defmodule TheBand.Audit do
  @moduledoc """
  API pública de eventos operacionais (FR-018 a FR-020).

  ## Por que esta entidade existe

  Não é decoração. `tenants` não pertence a si mesma, então sem uma entidade que **pertença** a
  um Tenant o requisito de que todo dado tenha dono não tem sujeito, e o critério de ausência de
  vazamento não tem objeto de teste. Este é o primeiro dado escopado da plataforma, e o que
  torna o isolamento verificável.

  ## Toda função escopada recebe `Scope.t()` como primeiro argumento

      {:ok, scope} = TheBand.Tenancy.scope(tenant_id)
      TheBand.Audit.record_event(scope, %{type: "sync.started"})
      TheBand.Audit.count_events(scope)

  Passar qualquer outra coisa **levanta**, incluindo `nil`. Nunca devolve lista vazia nem zero:
  é a diferença entre falha visível e "nenhum dado encontrado", e é o requisito FR-014.

  ## Não é `spo.performed_activity`

  Registro de operação **desta plataforma**, não atividade de processo de software de projeto
  observado. Quando a ontologia SPO chegar (feature 006), os dois conceitos coexistem sem se
  confundir. Ver ADR-0003.
  """

  alias TheBand.Audit.Commands
  alias TheBand.Audit.OperationalEvent
  alias TheBand.Audit.Queries
  alias TheBand.Tenancy.Scope

  @doc """
  Grava evento operacional no Tenant do escopo.

  `occurred_at` e `correlation_id` são preenchidos quando ausentes. `tenant_id` passado nos
  atributos é **ignorado**: o do escopo prevalece (FR-019).

  `metadata` com chave de nome sensível é **rejeitado**, não mascarado (FR-030): mascarar
  pressupõe que o valor já foi persistido, e num banco isso alcança backup e réplica.
  """
  @spec record_event(Scope.t(), map()) ::
          {:ok, OperationalEvent.t()} | {:error, Ecto.Changeset.t()}
  defdelegate record_event(scope, attrs), to: Commands, as: :record

  @doc """
  Lista eventos do Tenant do escopo, mais recentes primeiro.

  ## Opções

    * `:limit` — padrão 100
    * `:type` — filtra por tipo
  """
  @spec list_events(Scope.t(), keyword()) :: [OperationalEvent.t()]
  defdelegate list_events(scope, opts \\ []), to: Queries, as: :list

  @doc """
  Conta eventos do Tenant do escopo.

  Separada de `list_events/2` porque a contagem também precisa ser escopada: uma contagem que
  ignorasse o escopo vazaria **volume** de outro contratante, e volume já é informação.
  """
  @spec count_events(Scope.t()) :: non_neg_integer()
  defdelegate count_events(scope), to: Queries, as: :count

  @doc """
  Busca evento por identificador, dentro do escopo.

  Evento de outro Tenant devolve `{:error, :not_found}` — indistinguível de inexistente, de
  propósito: distinguir revelaria que o identificador existe em outro contratante.
  """
  @spec fetch_event(Scope.t(), Ecto.UUID.t()) ::
          {:ok, OperationalEvent.t()} | {:error, :not_found}
  defdelegate fetch_event(scope, event_id), to: Queries, as: :fetch

  @doc """
  Remove eventos do Tenant do escopo anteriores a `before`.
  """
  @spec purge_events_before(Scope.t(), DateTime.t()) :: {non_neg_integer(), nil}
  defdelegate purge_events_before(scope, before), to: Commands, as: :purge_before

  @doc """
  Leitura administrativa, **fora de escopo** — único caminho para Tenant desativado (FR-017).

  Prefixo `admin_` para que revisão e busca no código encontrem todo acesso fora de escopo numa
  única expressão.
  """
  @spec admin_list_events(Ecto.UUID.t(), keyword()) :: [OperationalEvent.t()]
  defdelegate admin_list_events(tenant_id, opts \\ []), to: Queries, as: :admin_list
end
