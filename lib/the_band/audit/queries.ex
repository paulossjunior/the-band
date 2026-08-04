defmodule TheBand.Audit.Queries do
  @moduledoc """
  Consultas de evento operacional. Módulo interno — use `TheBand.Audit`.

  ## O ponto único onde o filtro por Tenant é aplicado

  Toda consulta parte de `scoped/1`, que exige `Scope.t()`. Não existe consulta aqui que
  construa a partir do schema sem passar por ela — e essa é a garantia de FR-019 e FR-020.

  `Scope.tenant_id!/1` **levanta** para qualquer coisa que não seja escopo, incluindo `nil`.
  É esse comportamento que cumpre FR-014, e é o que Row Level Security não faria: ela devolveria
  conjunto vazio, transformando perda de contexto em "nenhum dado encontrado".
  """

  import Ecto.Query

  alias TheBand.Audit.OperationalEvent
  alias TheBand.Repo
  alias TheBand.Tenancy.Scope

  @doc """
  Consulta base, já filtrada pelo Tenant do escopo.

  Levanta se não receber `Scope.t()`.
  """
  @spec scoped(Scope.t()) :: Ecto.Query.t()
  def scoped(scope) do
    tenant_id = Scope.tenant_id!(scope)

    from(e in OperationalEvent, where: e.tenant_id == ^tenant_id)
  end

  @doc """
  Lista eventos do Tenant do escopo, mais recentes primeiro.

  ## Opções

    * `:limit` — máximo de registros, padrão 100
    * `:type` — filtra por tipo
  """
  @spec list(Scope.t(), keyword()) :: [OperationalEvent.t()]
  def list(scope, opts \\ []) do
    scope
    |> scoped()
    |> maybe_filter_type(Keyword.get(opts, :type))
    |> order_by([e], desc: e.occurred_at)
    |> limit(^Keyword.get(opts, :limit, 100))
    |> Repo.all()
  end

  @doc """
  Conta eventos do Tenant do escopo.

  Existe separada de `list/2` porque SC-003 exige que a **contagem** também não alcance outro
  Tenant. Uma contagem que ignorasse o escopo vazaria volume mesmo sem vazar conteúdo — e
  volume já é informação sobre o outro contratante.
  """
  @spec count(Scope.t()) :: non_neg_integer()
  def count(scope) do
    scope
    |> scoped()
    |> select([e], count(e.id))
    |> Repo.one()
  end

  @doc """
  Busca um evento por identificador, **dentro** do escopo.

  Devolve `{:error, :not_found}` para evento de outro Tenant — indistinguível de inexistente,
  de propósito: distinguir revelaria que o identificador existe em outro contratante.
  """
  @spec fetch(Scope.t(), Ecto.UUID.t()) :: {:ok, OperationalEvent.t()} | {:error, :not_found}
  def fetch(scope, event_id) do
    case Ecto.UUID.cast(event_id) do
      {:ok, uuid} ->
        scope
        |> scoped()
        |> where([e], e.id == ^uuid)
        |> Repo.one()
        |> case do
          nil -> {:error, :not_found}
          event -> {:ok, event}
        end

      :error ->
        {:error, :not_found}
    end
  end

  @doc """
  Leitura administrativa, **fora de escopo** — para Tenant desativado (FR-017).

  Exige `tenant_id` explícito: não existe caminho aqui que leia todos os Tenants de uma vez.
  """
  @spec admin_list(Ecto.UUID.t(), keyword()) :: [OperationalEvent.t()]
  def admin_list(tenant_id, opts \\ []) when is_binary(tenant_id) do
    from(e in OperationalEvent,
      where: e.tenant_id == ^tenant_id,
      order_by: [desc: e.occurred_at],
      limit: ^Keyword.get(opts, :limit, 100)
    )
    |> Repo.all()
  end

  defp maybe_filter_type(query, nil), do: query
  defp maybe_filter_type(query, type), do: where(query, [e], e.type == ^type)
end
