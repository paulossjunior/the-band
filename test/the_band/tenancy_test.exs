defmodule TheBand.TenancyTest do
  @moduledoc """
  FR-009 a FR-012, FR-016, FR-017, SC-008 — identidade e ciclo de vida do Tenant.
  """

  use TheBand.DataCase, async: true

  import TheBand.TenancyFixtures

  alias TheBand.Tenancy
  alias TheBand.Tenancy.Tenant

  describe "register_tenant/1 — identidade" do
    test "cria Tenant ativo com identificador legível e nome" do
      slug = unique_slug()

      assert {:ok, %Tenant{} = tenant} =
               Tenancy.register_tenant(%{slug: slug, name: "Consultoria Alpha"})

      assert tenant.slug == slug
      assert tenant.name == "Consultoria Alpha"
      assert tenant.active == true, "Tenant deve nascer ativo"
      assert tenant.id
    end

    test "rejeita identificador legível duplicado" do
      existente = tenant_fixture()

      assert {:error, changeset} =
               Tenancy.register_tenant(%{slug: existente.slug, name: "Outro"})

      assert "has already been taken" in errors_on(changeset).slug
    end

    test "rejeita identificador legível fora do formato" do
      invalidos = [
        {"AB", "curto e com maiúscula"},
        {"ab", "curto"},
        {"TENANT", "maiúsculas"},
        {"tenant_com_underscore", "underscore"},
        {"tenant com espaço", "espaço"},
        {"tenant.com.ponto", "ponto"},
        {"tenant@arroba", "caractere especial"},
        {"acentuação", "acento"},
        {String.duplicate("a", 64), "longo demais"}
      ]

      for {slug, motivo} <- invalidos do
        assert {:error, changeset} = Tenancy.register_tenant(%{slug: slug, name: "X"}),
               "aceitou identificador inválido (#{motivo}): #{inspect(slug)}"

        assert changeset.errors[:slug], "erro não foi atribuído ao campo slug"
      end
    end

    test "aceita os limites do formato" do
      for slug <- ["abc", String.duplicate("a", 63), "a-b-c", "t3n4nt-1"] do
        assert {:ok, _} = Tenancy.register_tenant(%{slug: slug, name: "X"}),
               "rejeitou identificador válido: #{inspect(slug)}"
      end
    end

    test "nome duplicado é ACEITO — unicidade não é exigida" do
      # Duas organizações homônimas podem contratar a plataforma legitimamente (FR-011).
      tenant_fixture(%{name: "Prefeitura de Vitória"})

      assert {:ok, _} =
               Tenancy.register_tenant(%{slug: unique_slug(), name: "Prefeitura de Vitória"})
    end

    test "exige identificador legível e nome" do
      assert {:error, cs} = Tenancy.register_tenant(%{})
      assert cs.errors[:slug]
      assert cs.errors[:name]

      assert {:error, cs} = Tenancy.register_tenant(%{slug: unique_slug()})
      assert cs.errors[:name]
    end

    test "NÃO aceita active nos atributos — nasce sempre ativo" do
      assert {:ok, tenant} =
               Tenancy.register_tenant(%{slug: unique_slug(), name: "X", active: false})

      assert tenant.active == true,
             "aceitar `active` na criação permitiria estado que ninguém pediu"
    end
  end

  describe "imutabilidade do identificador legível (FR-010, SC-008)" do
    test "rename_tenant/2 não altera o identificador legível" do
      {tenant, scope} = scoped_tenant_fixture()
      slug_original = tenant.slug

      assert {:ok, renomeado} = Tenancy.rename_tenant(scope, "Nome Novo")

      assert renomeado.name == "Nome Novo"
      assert renomeado.slug == slug_original
    end

    test "nenhum changeset público aceita slug em alteração" do
      tenant = tenant_fixture()

      # `rename_changeset/2` é o único caminho de alteração exposto. Se `slug` entrar na lista
      # de campos permitidos, este teste falha — que é o ponto.
      cs = Tenant.rename_changeset(tenant, %{name: "Novo", slug: "slug-injetado"})

      refute Map.has_key?(cs.changes, :slug),
             "o changeset de renomeação aceitou slug — imutabilidade de FR-010 furada"
    end

    test "activation_changeset/2 altera apenas active" do
      tenant = tenant_fixture()

      cs = Tenant.activation_changeset(tenant, false)

      assert Map.keys(cs.changes) == [:active]
    end
  end

  describe "desativação e reativação (FR-017)" do
    test "desativar preserva todos os campos e não remove nada" do
      tenant = tenant_fixture(%{name: "Preservar"})

      assert {:ok, inativo} = Tenancy.deactivate_tenant(tenant.id)

      assert inativo.active == false
      assert inativo.slug == tenant.slug
      assert inativo.name == tenant.name
      assert inativo.inserted_at == tenant.inserted_at
    end

    test "reativar restaura o acesso comum" do
      tenant = inactive_tenant_fixture()

      assert {:error, :tenant_inactive} = Tenancy.scope(tenant.id)
      assert {:ok, _} = Tenancy.activate_tenant(tenant.id)
      assert {:ok, _scope} = Tenancy.scope(tenant.id)
    end

    test "desativar Tenant inexistente devolve not_found, sem criar" do
      assert {:error, :not_found} = Tenancy.deactivate_tenant(Ecto.UUID.generate())
    end

    test "desativar duas vezes é inofensivo" do
      tenant = tenant_fixture()

      assert {:ok, _} = Tenancy.deactivate_tenant(tenant.id)
      assert {:ok, ainda_inativo} = Tenancy.deactivate_tenant(tenant.id)
      assert ainda_inativo.active == false
    end
  end

  describe "leitura administrativa (FR-017)" do
    test "admin_fetch_tenant/1 alcança Tenant desativado" do
      tenant = inactive_tenant_fixture()

      assert {:ok, encontrado} = Tenancy.admin_fetch_tenant(tenant.id)
      assert encontrado.id == tenant.id
      assert encontrado.active == false
    end

    test "admin_list_tenants/1 filtra por ativação" do
      ativo = tenant_fixture()
      inativo = inactive_tenant_fixture()

      ids_ativos = Tenancy.admin_list_tenants(active: true) |> Enum.map(& &1.id)
      ids_inativos = Tenancy.admin_list_tenants(active: false) |> Enum.map(& &1.id)

      assert ativo.id in ids_ativos
      refute inativo.id in ids_ativos
      assert inativo.id in ids_inativos
    end

    test "admin_fetch_tenant/1 devolve not_found para identificador inválido" do
      assert {:error, :not_found} = Tenancy.admin_fetch_tenant("nao-e-uuid")
      assert {:error, :not_found} = Tenancy.admin_fetch_tenant(nil)
    end
  end
end
