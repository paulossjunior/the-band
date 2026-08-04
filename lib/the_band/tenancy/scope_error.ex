defmodule TheBand.Tenancy.ScopeError do
  @moduledoc """
  Levantada por `TheBand.Tenancy.scope!/1` quando o escopo não pode ser construído.

  Em arquivo próprio, e não aninhada em `TheBand.Tenancy`: aninhada, ela era referenciada antes
  do ponto de definição, e `--warnings-as-errors` reprovou a compilação — corretamente.
  """

  defexception [:reason, :tenant_id]

  @impl true
  def message(%{reason: reason, tenant_id: tenant_id}) do
    "não foi possível construir escopo de Tenant: #{reason} (tenant_id: #{inspect(tenant_id)})"
  end
end
