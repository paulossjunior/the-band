defmodule TheBand.AuditFiltersTest do
  @moduledoc """
  Feature 040, T005 e T006 — filtros de consulta, e a concordância entre contagem e listagem.

  ## O defeito que estes testes impedem

  Antes desta feature, `count_events/1` **não aceitava filtro** enquanto `list_events/2` aceitava
  tipo. Uma tela que filtrasse a lista e usasse a contagem exibiria "142 eventos" mostrando 3 — um
  número que contradiz as próprias linhas dela.

  O teste que importa não verifica a implementação: verifica que os dois **concordam**. Se alguém
  acrescentar um filtro a `list/2` e esquecer `count/2`, este teste reprova.
  """

  use TheBand.DataCase, async: true

  import TheBand.TenancyFixtures

  alias TheBand.Audit

  setup do
    {tenant_a, escopo_a} = scoped_tenant_fixture()
    {tenant_b, escopo_b} = scoped_tenant_fixture()
    {:ok, tenant_a: tenant_a, escopo_a: escopo_a, tenant_b: tenant_b, escopo_b: escopo_b}
  end

  # `correlation_id` é obrigatório no schema — a plataforma não registra evento sem correlação, para
  # que todo fato seja atribuível a uma operação. Quando o teste não se interessa pela correlação,
  # gera uma única.
  defp evento(escopo, tipo, correlacao \\ nil) do
    correlacao = correlacao || "corr-#{System.unique_integer([:positive])}"

    {:ok, e} =
      Audit.record_event(escopo, %{type: tipo, correlation_id: correlacao, metadata: %{}})

    e
  end

  describe "FR-002 e SC-002 — contagem e listagem concordam" do
    test "sem filtro", %{escopo_a: escopo} do
      for _ <- 1..7, do: evento(escopo, "alfa")

      assert Audit.count_events(escopo) == length(Audit.list_events(escopo))
    end

    test "com filtro de tipo", %{escopo_a: escopo} do
      for _ <- 1..5, do: evento(escopo, "alfa")
      for _ <- 1..3, do: evento(escopo, "beta")

      filtro = [type: "beta"]

      assert Audit.count_events(escopo, filtro) == 3
      assert Audit.count_events(escopo, filtro) == length(Audit.list_events(escopo, filtro))

      refute Audit.count_events(escopo, filtro) == Audit.count_events(escopo),
             "a contagem filtrada não pode ser igual à total quando o filtro exclui algo — " <>
               "se for, o filtro está sendo ignorado"
    end

    test "com filtro de correlação", %{escopo_a: escopo} do
      evento(escopo, "alfa", "corr-1")
      evento(escopo, "beta", "corr-1")
      evento(escopo, "alfa", "corr-2")

      filtro = [correlation_id: "corr-1"]

      assert Audit.count_events(escopo, filtro) == 2
      assert length(Audit.list_events(escopo, filtro)) == 2
    end

    test "com filtro de instante inicial", %{escopo_a: escopo} do
      for _ <- 1..4, do: evento(escopo, "alfa")

      futuro = DateTime.add(DateTime.utc_now(), 1, :hour)
      passado = DateTime.add(DateTime.utc_now(), -1, :hour)

      assert Audit.count_events(escopo, since: futuro) == 0
      assert Audit.list_events(escopo, since: futuro) == []

      assert Audit.count_events(escopo, since: passado) == 4
    end

    test "com filtros combinados", %{escopo_a: escopo} do
      evento(escopo, "alfa", "corr-1")
      evento(escopo, "beta", "corr-1")
      evento(escopo, "alfa", "corr-2")

      filtro = [type: "alfa", correlation_id: "corr-1"]

      assert Audit.count_events(escopo, filtro) == 1
      assert length(Audit.list_events(escopo, filtro)) == 1
    end

    test "filtro vazio é tratado como ausência de filtro", %{escopo_a: escopo} do
      for _ <- 1..3, do: evento(escopo, "alfa")

      # A tela envia string vazia quando quem opera escolhe "todos". Tratar `""` como um tipo
      # chamado "" devolveria zero, e a tela mostraria "0 eventos" tendo 3.
      assert Audit.count_events(escopo, type: "") == 3
      assert length(Audit.list_events(escopo, type: "")) == 3
    end
  end

  describe "FR-004 e SC-001 — nenhum filtro alcança outro Tenant" do
    test "listagem filtrada não vê evento do outro", %{escopo_a: a, escopo_b: b} do
      evento(a, "compartilhado")
      evento(b, "compartilhado")

      assert length(Audit.list_events(a, type: "compartilhado")) == 1
      assert length(Audit.list_events(b, type: "compartilhado")) == 1
    end

    test "contagem filtrada não soma o do outro", %{escopo_a: a, escopo_b: b} do
      for _ <- 1..3, do: evento(a, "compartilhado")
      for _ <- 1..5, do: evento(b, "compartilhado")

      assert Audit.count_events(a, type: "compartilhado") == 3
      assert Audit.count_events(b, type: "compartilhado") == 5
    end

    test "correlação idêntica em dois Tenants não vaza", %{escopo_a: a, escopo_b: b} do
      evento(a, "alfa", "mesma-correlacao")
      evento(b, "alfa", "mesma-correlacao")

      assert length(Audit.list_events(a, correlation_id: "mesma-correlacao")) == 1
      assert Audit.count_events(a, correlation_id: "mesma-correlacao") == 1
    end

    test "lista de tipos não revela o vocabulário do outro", %{escopo_a: a, escopo_b: b} do
      evento(a, "tipo.de.a")
      evento(b, "tipo.de.b")

      assert Audit.list_event_types(a) == ["tipo.de.a"]
      assert Audit.list_event_types(b) == ["tipo.de.b"]

      refute "tipo.de.b" in Audit.list_event_types(a),
             "o vocabulário de tipos de um contratante já é informação sobre ele"
    end
  end

  describe "FR-003 — lista de tipos" do
    test "devolve os tipos distintos, ordenados", %{escopo_a: escopo} do
      evento(escopo, "zeta")
      evento(escopo, "alfa")
      evento(escopo, "alfa")
      evento(escopo, "meio")

      assert Audit.list_event_types(escopo) == ["alfa", "meio", "zeta"]
    end

    test "devolve lista vazia quando não há evento", %{escopo_a: escopo} do
      assert Audit.list_event_types(escopo) == []
    end
  end

  describe "FR-014 da feature 001 — as funções novas levantam sem escopo" do
    test "count_events com filtro levanta sem escopo" do
      assert_raise ArgumentError, ~r/sem escopo de Tenant/, fn ->
        Audit.count_events(nil, type: "alfa")
      end
    end

    test "list_event_types levanta sem escopo" do
      assert_raise ArgumentError, ~r/sem escopo de Tenant/, fn ->
        Audit.list_event_types(nil)
      end
    end

    test "list_events com filtro levanta sem escopo" do
      assert_raise ArgumentError, ~r/sem escopo de Tenant/, fn ->
        Audit.list_events(nil, type: "alfa")
      end
    end
  end
end
