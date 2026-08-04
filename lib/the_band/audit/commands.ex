defmodule TheBand.Audit.Commands do
  @moduledoc """
  Escritas de evento operacional. Módulo interno — use `TheBand.Audit`.

  O `tenant_id` vem **sempre** do escopo, nunca dos atributos. Aceitar dos atributos permitiria
  gravar evento num Tenant diferente do escopo ativo, que é o vazamento que FR-019 impede.
  """

  import Ecto.Query

  alias TheBand.Audit.OperationalEvent
  alias TheBand.Repo
  alias TheBand.Telemetry.Correlation
  alias TheBand.Tenancy.Scope

  @doc """
  Grava evento operacional no Tenant do escopo.

  Preenche `occurred_at` e `correlation_id` quando ausentes: um evento sem tempo ou sem
  correlação é registro que não serve para reconstituir cadeia, e exigir que cada chamador os
  informe garantiria que alguém esqueceria.
  """
  @spec record(Scope.t(), map()) :: {:ok, OperationalEvent.t()} | {:error, Ecto.Changeset.t()}
  def record(scope, attrs) do
    tenant_id = Scope.tenant_id!(scope)

    attrs
    |> normalize()
    |> OperationalEvent.create_changeset(tenant_id)
    |> Repo.insert()
  end

  @doc """
  Remove eventos do Tenant do escopo mais antigos que `before`.

  Existe para que o expurgo também seja escopado. Um expurgo global apagaria histórico de outro
  contratante — dano pior que vazamento de leitura, porque é irreversível.
  """
  @spec purge_before(Scope.t(), DateTime.t()) :: {non_neg_integer(), nil}
  def purge_before(scope, %DateTime{} = before) do
    tenant_id = Scope.tenant_id!(scope)

    from(e in OperationalEvent,
      where: e.tenant_id == ^tenant_id and e.occurred_at < ^before
    )
    |> Repo.delete_all()
  end

  defp normalize(attrs) do
    attrs
    |> Map.new(fn {k, v} -> {to_string(k), v} end)
    |> Map.put_new_lazy("occurred_at", &DateTime.utc_now/0)
    |> Map.put_new_lazy("correlation_id", &Correlation.ensure/0)
  end
end
