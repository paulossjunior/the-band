defmodule TheBand.TenancyFixtures do
  @moduledoc """
  Auxiliares de teste para Tenant e evento operacional (T022).

  Estava planejada para a issue #2, e foi movida para cá porque referencia schemas que só
  existem nesta issue. Defeito de ordenação identificado durante a implementação e corrigido na
  lista de tarefas em vez de contornado.

  Identificadores legíveis são gerados com sufixo único porque `slug` é único na instalação:
  fixtures com valor fixo colidiriam entre testes e a falha apareceria como violação de
  restrição, não como o problema real.
  """

  alias TheBand.Audit
  alias TheBand.Tenancy

  @doc """
  Cria Tenant ativo.
  """
  def tenant_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        slug: unique_slug(),
        name: "Tenant de Teste"
      })

    {:ok, tenant} = Tenancy.register_tenant(attrs)
    tenant
  end

  @doc """
  Cria Tenant desativado.

  Cria ativo e desativa em seguida, de propósito: é o único caminho existente, porque
  `create_changeset/1` não aceita `active`. A fixture não deve abrir um caminho que a API
  pública não oferece — senão testaria um estado que a aplicação não sabe produzir.
  """
  def inactive_tenant_fixture(attrs \\ %{}) do
    tenant = tenant_fixture(attrs)
    {:ok, inactive} = Tenancy.deactivate_tenant(tenant.id)
    inactive
  end

  @doc """
  Devolve `{tenant, scope}` de um Tenant ativo.
  """
  def scoped_tenant_fixture(attrs \\ %{}) do
    tenant = tenant_fixture(attrs)
    {:ok, scope} = Tenancy.scope(tenant.id)
    {tenant, scope}
  end

  @doc """
  Grava evento operacional no escopo.
  """
  def event_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        type: "test.event",
        correlation_id: "corr-#{System.unique_integer([:positive])}",
        occurred_at: DateTime.utc_now()
      })

    {:ok, event} = Audit.record_event(scope, attrs)
    event
  end

  @doc """
  Grava `n` eventos no escopo.
  """
  def events_fixture(scope, n) when is_integer(n) and n > 0 do
    Enum.map(1..n, fn i -> event_fixture(scope, %{type: "test.event.#{i}"}) end)
  end

  @doc """
  Monta dois Tenants com escopos e eventos, para teste de isolamento.

  Contagens diferentes de propósito: com a mesma contagem, um defeito que trocasse os escopos
  passaria despercebido.
  """
  def two_tenants_fixture(n_a \\ 3, n_b \\ 5) do
    {tenant_a, scope_a} = scoped_tenant_fixture(%{name: "Alpha"})
    {tenant_b, scope_b} = scoped_tenant_fixture(%{name: "Beta"})

    events_a = events_fixture(scope_a, n_a)
    events_b = events_fixture(scope_b, n_b)

    %{
      tenant_a: tenant_a,
      tenant_b: tenant_b,
      scope_a: scope_a,
      scope_b: scope_b,
      events_a: events_a,
      events_b: events_b
    }
  end

  @doc "Identificador legível válido e único."
  def unique_slug, do: "t-#{System.unique_integer([:positive])}"
end
