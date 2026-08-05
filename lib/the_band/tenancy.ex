defmodule TheBand.Tenancy do
  @moduledoc """
  API pública do isolamento por Tenant (FR-009 a FR-017).

  ## A invariante

  > Ausência de contexto de Tenant **levanta erro**. Nunca devolve conjunto vazio.

  Row Level Security do PostgreSQL foi testada e descartada nesta feature exatamente por
  falhar nisso: sem o contexto, devolve zero linhas silenciosamente. Um defeito que perdesse o
  contexto produziria "nenhum dado encontrado" em vez de falha visível. Ver ADR-0002.

  ## Como se obtém acesso a dado

      {:ok, scope} = TheBand.Tenancy.scope(tenant_id)
      TheBand.Audit.list_events(scope)

  O escopo carrega um `tenant_id` **já validado** contra existência e ativação. Toda função que
  o recebe herda essa garantia sem reverificar.

  ## Funções `admin_*`

  Prefixo deliberado. São os únicos caminhos de acesso fora de escopo, e existem porque FR-017
  exige que dado de Tenant desativado permaneça legível. O prefixo faz com que busca no código
  e revisão encontrem **todo** acesso fora de escopo numa única expressão.

  ## Tenant não é Organização

  `Tenant` é a fronteira de isolamento desta instalação. `eo.organization` é a organização do
  mundo real analisada, e chega na feature 005 com `tenant_id` própria. Um Tenant contém várias
  organizações. Ver ADR-0003.
  """

  alias TheBand.Tenancy.Commands
  alias TheBand.Tenancy.Queries
  alias TheBand.Tenancy.Scope
  alias TheBand.Tenancy.ScopeError
  alias TheBand.Tenancy.Tenant

  @type tenant_id :: Ecto.UUID.t()
  @type scope_error :: :tenant_not_found | :tenant_inactive

  @doc """
  Constrói escopo validado.

  Valida existência **e** ativação. Emite telemetria em cada rejeição, porque rejeição
  silenciosa de escopo esconde tanto defeito de código quanto tentativa de acesso indevido.

  | Entrada | Retorno |
  |---|---|
  | Tenant existente e ativo | `{:ok, scope}` |
  | Tenant existente e inativo | `{:error, :tenant_inactive}` |
  | Tenant inexistente | `{:error, :tenant_not_found}` |
  | `nil`, valor não-UUID, qualquer outra coisa | `{:error, :tenant_not_found}` |

  **Nunca cria Tenant implicitamente** (FR-016).
  """
  @spec scope(term()) :: {:ok, Scope.t()} | {:error, scope_error()}
  def scope(tenant_id) do
    case Queries.fetch(tenant_id) do
      {:ok, %Tenant{active: true, id: id}} ->
        {:ok, Scope.new(id)}

      {:ok, %Tenant{active: false, id: id}} ->
        reject(:tenant_inactive, id)

      {:error, :not_found} ->
        reject(:tenant_not_found, tenant_id)
    end
  end

  @doc """
  Igual a `scope/1`, mas levanta `TheBand.Tenancy.ScopeError`.

  Use onde a ausência de escopo é defeito de programação e não condição esperada — em
  trabalhador assíncrono, por exemplo, onde o Tenant já foi validado no enfileiramento.
  """
  @spec scope!(term()) :: Scope.t()
  def scope!(tenant_id) do
    case scope(tenant_id) do
      {:ok, scope} -> scope
      {:error, reason} -> raise ScopeError, reason: reason, tenant_id: tenant_id
    end
  end

  @doc """
  Constrói escopo a partir do identificador legível. Mesmas regras de `scope/1`.
  """
  @spec scope_by_slug(String.t()) :: {:ok, Scope.t()} | {:error, scope_error()}
  def scope_by_slug(slug) when is_binary(slug) do
    case Queries.fetch_by_slug(slug) do
      {:ok, %Tenant{active: true, id: id}} -> {:ok, Scope.new(id)}
      {:ok, %Tenant{active: false, id: id}} -> reject(:tenant_inactive, id)
      {:error, :not_found} -> reject(:tenant_not_found, slug)
    end
  end

  def scope_by_slug(_), do: reject(:tenant_not_found, nil)

  @doc """
  Registra um Tenant.

  `slug` é único na instalação, imutável, e restrito a minúsculas, dígitos e hífen com 3 a 63
  caracteres. `name` é livre, alterável e **não** exige unicidade — duas organizações homônimas
  podem contratar a plataforma (FR-011).
  """
  @spec register_tenant(map()) :: {:ok, Tenant.t()} | {:error, Ecto.Changeset.t()}
  defdelegate register_tenant(attrs), to: Commands, as: :create

  @doc """
  Renomeia o Tenant do escopo.

  Recebe `Scope.t()` porque renomear é operação escopada. Não aceita `slug`: a assinatura não o
  expõe e o changeset não o inclui (FR-010).
  """
  @spec rename_tenant(Scope.t(), String.t()) ::
          {:ok, Tenant.t()} | {:error, Ecto.Changeset.t() | :not_found}
  def rename_tenant(scope, name) when is_binary(name) do
    with {:ok, tenant} <- Queries.fetch(Scope.tenant_id!(scope)) do
      Commands.rename(tenant, name)
    end
  end

  @doc """
  Desativa o Tenant.

  Recebe `tenant_id` cru, **não** escopo: desativar por meio de um escopo válido e depois
  invalidá-lo seria contraditório. É operação administrativa.

  Preserva integralmente os dados (FR-017).
  """
  @spec deactivate_tenant(tenant_id()) :: {:ok, Tenant.t()} | {:error, term()}
  def deactivate_tenant(tenant_id), do: set_activation(tenant_id, false)

  @doc "Reativa o Tenant. Dados e histórico voltam a ser acessíveis por acesso comum."
  @spec activate_tenant(tenant_id()) :: {:ok, Tenant.t()} | {:error, term()}
  def activate_tenant(tenant_id), do: set_activation(tenant_id, true)

  @doc """
  Leitura administrativa, **fora de escopo**.

  Único caminho para Tenant desativado (FR-017). Prefixo `admin_` para que revisão e busca no
  código encontrem todo acesso fora de escopo.
  """
  @spec admin_fetch_tenant(tenant_id()) :: {:ok, Tenant.t()} | {:error, :not_found}
  defdelegate admin_fetch_tenant(tenant_id), to: Queries, as: :fetch

  @doc """
  Lista Tenants. Operação administrativa: não é escopada por natureza.

  ## Opções

    * `:active` — filtra por ativação quando `true` ou `false`
  """
  @spec admin_list_tenants(keyword()) :: [Tenant.t()]
  defdelegate admin_list_tenants(opts \\ []), to: Queries, as: :list

  defp set_activation(tenant_id, active) do
    with {:ok, tenant} <- Queries.fetch(tenant_id) do
      Commands.set_active(tenant, active)
    end
  end

  defp reject(reason, tenant_id) do
    :telemetry.execute(
      [:the_band, :tenancy, :scope, :rejected],
      %{},
      %{reason: reason, tenant_id: tenant_id}
    )

    {:error, reason}
  end
end
