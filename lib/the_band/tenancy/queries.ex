defmodule TheBand.Tenancy.Queries do
  @moduledoc """
  Consultas de Tenant. Módulo interno — use `TheBand.Tenancy`.

  Autorizado a chamar `TheBand.Repo` diretamente, e essa autorização é declarada na checagem
  `TheBand.Credo.Check.NoDirectRepoAccess`.
  """

  import Ecto.Query

  alias TheBand.Repo
  alias TheBand.Tenancy.Tenant

  @doc """
  Busca Tenant por identificador, **sem** filtrar por ativação.

  A tabela de Tenants é a única sem `tenant_id`: ela é a fronteira, não algo dentro dela. Por
  isso não recebe escopo — quem valida o escopo é `TheBand.Tenancy.scope/1`, e é ela que
  chama isto.
  """
  @spec fetch(term()) :: {:ok, Tenant.t()} | {:error, :not_found}
  def fetch(tenant_id) when is_binary(tenant_id) do
    case Ecto.UUID.cast(tenant_id) do
      {:ok, uuid} -> from_id(uuid)
      :error -> {:error, :not_found}
    end
  end

  def fetch(_), do: {:error, :not_found}

  @doc """
  Busca Tenant por identificador legível.
  """
  @spec fetch_by_slug(String.t()) :: {:ok, Tenant.t()} | {:error, :not_found}
  def fetch_by_slug(slug) when is_binary(slug) do
    case Repo.get_by(Tenant, slug: slug) do
      nil -> {:error, :not_found}
      tenant -> {:ok, tenant}
    end
  end

  @doc """
  Lista Tenants. Operação administrativa: não é escopada, por natureza.
  """
  @spec list(keyword()) :: [Tenant.t()]
  def list(opts \\ []) do
    query = from(t in Tenant, order_by: [asc: t.slug])

    query =
      case Keyword.get(opts, :active) do
        nil -> query
        active when is_boolean(active) -> where(query, [t], t.active == ^active)
      end

    Repo.all(query)
  end

  defp from_id(uuid) do
    case Repo.get(Tenant, uuid) do
      nil -> {:error, :not_found}
      tenant -> {:ok, tenant}
    end
  end
end
