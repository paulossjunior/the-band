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
    |> aplicar_filtros(opts)
    |> order_by([e], desc: e.occurred_at)
    |> limit(^Keyword.get(opts, :limit, 100))
    |> Repo.all()
  end

  @doc """
  Conta eventos do Tenant do escopo.

  Existe separada de `list/2` porque SC-003 exige que a **contagem** também não alcance outro
  Tenant. Uma contagem que ignorasse o escopo vazaria volume mesmo sem vazar conteúdo — e
  volume já é informação sobre o outro contratante.

  ## Aceita os MESMOS filtros de `list/2`, e isso é requisito

  Feature 040, FR-002. Enquanto esta função não aceitava filtro, uma tela que filtrasse a lista e
  usasse a contagem exibiria "142 eventos" mostrando 3 — um número que contradiz o que está na tela.

  As duas funções compartilham `aplicar_filtros/2` de propósito: se os filtros divergirem, a
  contagem e a lista passam a discordar, e a tela mente. Há teste de que os dois concordam.

  ## Opções

    * `:type` — filtra por tipo
    * `:since` — apenas eventos a partir deste instante, inclusive
    * `:correlation_id` — apenas eventos desta correlação
  """
  @spec count(Scope.t(), keyword()) :: non_neg_integer()
  def count(scope, opts \\ []) do
    scope
    |> scoped()
    |> aplicar_filtros(opts)
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
  def admin_list(tenant_id, opts \\ []) do
    # Valida antes de consultar. Sem isto, identificador inválido chega ao Ecto e produz
    # `Ecto.Query.CastError` — erro técnico que não diz o que quem opera fez de errado.
    # Apontado em revisão independente.
    #
    # Levanta em vez de devolver lista vazia: este é caminho administrativo, e devolver vazio
    # para identificador inválido faria erro de digitação parecer "este Tenant não tem eventos".
    tenant_id =
      case tenant_id do
        id when is_binary(id) ->
          case Ecto.UUID.cast(id) do
            {:ok, uuid} ->
              uuid

            :error ->
              raise ArgumentError,
                    "admin_list/2 recebeu identificador de Tenant inválido: #{inspect(id)}"
          end

        outro ->
          raise ArgumentError,
                "admin_list/2 exige identificador de Tenant como texto, e recebeu #{inspect(outro)}"
      end

    from(e in OperationalEvent,
      where: e.tenant_id == ^tenant_id,
      order_by: [desc: e.occurred_at],
      limit: ^Keyword.get(opts, :limit, 100)
    )
    |> Repo.all()
  end

  @doc """
  Tipos distintos de evento presentes no Tenant do escopo, ordenados.

  Existe para alimentar o filtro da tela. Uma lista de tipos fixa no código mentiria assim que um
  tipo novo aparecesse — e os tipos vêm de trabalhadores e conectores que ainda não existem.

  Também é consulta escopada: o vocabulário de tipos de um contratante já é informação sobre ele.
  """
  @spec list_types(Scope.t()) :: [String.t()]
  def list_types(scope) do
    scope
    |> scoped()
    |> distinct(true)
    |> select([e], e.type)
    |> order_by([e], asc: e.type)
    |> Repo.all()
  end

  # Um único lugar aplica filtros, e `list/2` e `count/2` o compartilham. Se cada uma tivesse a sua
  # cópia, elas divergiriam com a primeira opção nova, e a contagem passaria a contradizer a lista.
  defp aplicar_filtros(query, opts) do
    query
    |> maybe_filter_type(Keyword.get(opts, :type))
    |> maybe_filter_since(Keyword.get(opts, :since))
    |> maybe_filter_correlation(Keyword.get(opts, :correlation_id))
  end

  defp maybe_filter_type(query, nil), do: query
  defp maybe_filter_type(query, ""), do: query
  defp maybe_filter_type(query, type), do: where(query, [e], e.type == ^type)

  defp maybe_filter_since(query, nil), do: query

  defp maybe_filter_since(query, %DateTime{} = since),
    do: where(query, [e], e.occurred_at >= ^since)

  defp maybe_filter_correlation(query, nil), do: query
  defp maybe_filter_correlation(query, ""), do: query

  defp maybe_filter_correlation(query, correlation_id),
    do: where(query, [e], e.correlation_id == ^correlation_id)
end
