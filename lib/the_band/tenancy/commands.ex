defmodule TheBand.Tenancy.Commands do
  @moduledoc """
  Escritas de Tenant. Módulo interno — use `TheBand.Tenancy`.

  Autorizado a chamar `TheBand.Repo` diretamente, declarado na checagem
  `TheBand.Credo.Check.NoDirectRepoAccess`.
  """

  alias TheBand.Repo
  alias TheBand.Tenancy.Tenant

  @doc """
  Cria Tenant.

  Sempre nasce ativo: `create_changeset/1` não aceita `active`. Criar um Tenant já desativado
  não tem caso de uso e permitiria estado que ninguém pediu.
  """
  @spec create(map()) :: {:ok, Tenant.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    attrs
    |> Tenant.create_changeset()
    |> Repo.insert()
  end

  @doc """
  Renomeia. `slug` não é aceito — imutável (FR-010).
  """
  @spec rename(Tenant.t(), String.t()) :: {:ok, Tenant.t()} | {:error, Ecto.Changeset.t()}
  def rename(%Tenant{} = tenant, name) do
    tenant
    |> Tenant.rename_changeset(%{name: name})
    |> Repo.update()
  end

  @doc """
  Define ativação.

  Desativar **preserva integralmente** os dados: altera apenas `active` (FR-017). Não há
  remoção nem anonimização, e as chaves estrangeiras usam `RESTRICT` para impedir remoção por
  acidente.
  """
  @spec set_active(Tenant.t(), boolean()) :: {:ok, Tenant.t()} | {:error, Ecto.Changeset.t()}
  def set_active(%Tenant{} = tenant, active) when is_boolean(active) do
    tenant
    |> Tenant.activation_changeset(active)
    |> Repo.update()
  end
end
