defmodule TheBand.Integration.TenantIsolationTest do
  @moduledoc """
  SC-002, SC-003, SC-004, FR-015, FR-020 — isolamento entre Tenants.

  ## O que este arquivo protege

  Vazamento entre contratantes. É o pior defeito possível nesta plataforma: um Tenant vendo
  dado de outro não é bug de funcionalidade, é quebra de confiança que não se desfaz.

  ## Por que dois Tenants com contagens diferentes

  Três eventos em um, cinco no outro. Com a mesma contagem, um defeito que trocasse os escopos
  passaria despercebido — os números baterіam.

  ## Por que cobre contagem, e não só listagem

  Uma contagem que ignorasse o escopo vazaria **volume** do outro contratante mesmo sem vazar
  conteúdo. Volume já é informação: quantos repositórios, quantas equipes, qual o tamanho da
  operação.
  """

  use TheBand.DataCase, async: false

  import TheBand.TenancyFixtures

  alias TheBand.Audit
  alias TheBand.Tenancy

  @moduletag :integration

  setup do
    {:ok, two_tenants_fixture(3, 5)}
  end

  describe "leitura" do
    test "listar no escopo de A não devolve evento de B", %{
      scope_a: scope_a,
      scope_b: scope_b,
      events_b: events_b
    } do
      ids_a = scope_a |> Audit.list_events() |> Enum.map(& &1.id) |> MapSet.new()
      ids_b = events_b |> Enum.map(& &1.id) |> MapSet.new()

      assert MapSet.size(ids_a) == 3
      assert MapSet.disjoint?(ids_a, ids_b), "evento de B apareceu na listagem de A"

      # E o inverso, porque isolamento assimétrico é isolamento quebrado.
      ids_b_lidos = scope_b |> Audit.list_events() |> Enum.map(& &1.id) |> MapSet.new()
      assert MapSet.size(ids_b_lidos) == 5
      assert MapSet.disjoint?(ids_b_lidos, ids_a)
    end

    test "contar no escopo de A desconsidera B integralmente", %{
      scope_a: scope_a,
      scope_b: scope_b
    } do
      assert Audit.count_events(scope_a) == 3
      assert Audit.count_events(scope_b) == 5

      # A soma prova que nenhuma contagem viu o total. Se uma delas vazasse, daria 8.
      assert Audit.count_events(scope_a) + Audit.count_events(scope_b) == 8
    end

    test "buscar evento de B pelo escopo de A devolve not_found, indistinguível de inexistente",
         %{scope_a: scope_a, events_b: events_b} do
      evento_b = hd(events_b)
      inexistente = Ecto.UUID.generate()

      assert Audit.fetch_event(scope_a, evento_b.id) == {:error, :not_found}
      assert Audit.fetch_event(scope_a, inexistente) == {:error, :not_found}

      # Respostas idênticas de propósito: distinguir revelaria que o identificador existe em
      # outro contratante, o que já é vazamento.
    end

    test "filtrar por tipo não escapa do escopo", %{scope_a: scope_a, scope_b: scope_b} do
      # Tipo que existe APENAS em B.
      #
      # A primeira versão deste teste usava o tipo de um evento de B vindo da fixture, mas a
      # fixture gera os mesmos tipos para os dois Tenants. O filtro devolvia o evento de A com
      # aquele tipo — comportamento correto, teste errado. Corrigido para criar um tipo
      # exclusivo, senão o teste não prova nada sobre escopo.
      tipo_exclusivo = "somente.em.b.#{System.unique_integer([:positive])}"
      event_fixture(scope_b, %{type: tipo_exclusivo})

      assert Audit.list_events(scope_a, type: tipo_exclusivo) == []
      assert [_] = Audit.list_events(scope_b, type: tipo_exclusivo)
    end

    test "limite alto não alcança o outro Tenant", %{scope_a: scope_a} do
      assert length(Audit.list_events(scope_a, limit: 10_000)) == 3
    end
  end

  describe "escrita" do
    test "gravar com escopo de A ignora tenant_id de B passado nos atributos", %{
      scope_a: scope_a,
      tenant_a: tenant_a,
      tenant_b: tenant_b,
      scope_b: scope_b
    } do
      {:ok, evento} =
        Audit.record_event(scope_a, %{
          type: "tentativa.de.injecao",
          tenant_id: tenant_b.id
        })

      assert evento.tenant_id == tenant_a.id,
             "tenant_id dos atributos prevaleceu sobre o do escopo — FR-019 violado"

      assert Audit.count_events(scope_b) == 5, "o evento foi para o Tenant errado"
      assert Audit.count_events(scope_a) == 4
    end

    test "expurgo no escopo de A não remove evento de B", %{
      scope_a: scope_a,
      scope_b: scope_b
    } do
      futuro = DateTime.add(DateTime.utc_now(), 3600, :second)

      {removidos, _} = Audit.purge_events_before(scope_a, futuro)

      assert removidos == 3
      assert Audit.count_events(scope_a) == 0

      assert Audit.count_events(scope_b) == 5,
             "expurgo escopado apagou histórico de outro contratante — dano irreversível"
    end
  end

  describe "ausência de escopo" do
    test "toda função escopada LEVANTA sem escopo, em vez de devolver vazio", %{
      events_a: _
    } do
      for {nome, fun} <- [
            {"list_events", fn -> Audit.list_events(nil) end},
            {"count_events", fn -> Audit.count_events(nil) end},
            {"fetch_event", fn -> Audit.fetch_event(nil, Ecto.UUID.generate()) end},
            {"record_event", fn -> Audit.record_event(nil, %{type: "x"}) end},
            {"purge_events_before", fn -> Audit.purge_events_before(nil, DateTime.utc_now()) end}
          ] do
        assert_raise ArgumentError, fn -> fun.() end

        # A distinção entre levantar e devolver vazio é o requisito FR-014, não estilo.
        # Devolver `[]` ou `0` aqui transformaria perda de contexto em "nenhum dado encontrado".
        _ = nome
      end
    end

    test "identificador cru não serve como escopo", %{tenant_a: tenant_a} do
      assert_raise ArgumentError, fn -> Audit.list_events(tenant_a.id) end
      assert_raise ArgumentError, fn -> Audit.count_events(tenant_a.id) end
    end

    test "estrutura parecida com escopo não serve", %{tenant_a: tenant_a} do
      falso = %{tenant_id: tenant_a.id}

      assert_raise ArgumentError, fn -> Audit.list_events(falso) end
    end
  end

  describe "Tenant desativado" do
    test "acesso comum é rejeitado e os dados permanecem", %{
      tenant_a: tenant_a,
      scope_a: scope_a
    } do
      assert Audit.count_events(scope_a) == 3

      {:ok, _} = Tenancy.deactivate_tenant(tenant_a.id)

      assert {:error, :tenant_inactive} = Tenancy.scope(tenant_a.id)

      # FR-017 — desativar preserva. Nada é removido nem anonimizado.
      assert {:ok, tenant} = Tenancy.admin_fetch_tenant(tenant_a.id)
      assert tenant.slug == tenant_a.slug
      assert tenant.name == tenant_a.name
      assert length(Audit.admin_list_events(tenant_a.id)) == 3
    end

    test "reativar devolve o acesso comum, com os dados intactos", %{tenant_a: tenant_a} do
      {:ok, _} = Tenancy.deactivate_tenant(tenant_a.id)
      {:ok, _} = Tenancy.activate_tenant(tenant_a.id)

      assert {:ok, scope} = Tenancy.scope(tenant_a.id)
      assert Audit.count_events(scope) == 3
    end

    test "leitura administrativa de A não devolve evento de B", %{
      tenant_a: tenant_a,
      events_b: events_b
    } do
      # O caminho administrativo é fora de escopo, mas não é fora de Tenant: exige
      # `tenant_id` explícito e não existe variante que leia todos de uma vez.
      ids_admin = tenant_a.id |> Audit.admin_list_events() |> Enum.map(& &1.id) |> MapSet.new()
      ids_b = events_b |> Enum.map(& &1.id) |> MapSet.new()

      assert MapSet.size(ids_admin) == 3
      assert MapSet.disjoint?(ids_admin, ids_b)
    end
  end

  describe "integridade no banco" do
    test "remover Tenant com evento é impedido pela chave estrangeira", %{tenant_a: tenant_a} do
      # ON DELETE RESTRICT, não CASCADE. Remover um Tenant não pode apagar seu histórico em
      # cascata: histórico que desaparece é o fim da auditoria.
      assert_raise Ecto.ConstraintError, fn ->
        TheBand.Repo.delete!(%TheBand.Tenancy.Tenant{id: tenant_a.id})
      end

      assert {:ok, _} = Tenancy.admin_fetch_tenant(tenant_a.id)
    end
  end
end
