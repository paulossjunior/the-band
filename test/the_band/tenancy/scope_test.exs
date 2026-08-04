defmodule TheBand.Tenancy.ScopeTest do
  @moduledoc """
  FR-013, FR-014, FR-016 — construção e validação do escopo de Tenant.

  ## A asserção mais importante deste arquivo

  A que verifica que ausência de escopo **levanta**, e não devolve vazio.

  É o requisito que fez Row Level Security ser descartada nesta feature: testada de ponta a
  ponta, RLS isola corretamente com o contexto definido, mas sem o contexto devolve zero linhas
  silenciosamente. Um defeito que perdesse o contexto produziria "nenhum dado encontrado" — uma
  falha que parece funcionamento normal.
  """

  use TheBand.DataCase, async: true

  import TheBand.TenancyFixtures

  alias TheBand.Tenancy
  alias TheBand.Tenancy.Scope
  alias TheBand.Tenancy.ScopeError

  describe "scope/1" do
    test "devolve escopo para Tenant existente e ativo" do
      tenant = tenant_fixture()

      assert {:ok, scope} = Tenancy.scope(tenant.id)
      assert Scope.scope?(scope)
      assert Scope.tenant_id!(scope) == tenant.id
    end

    test "rejeita Tenant desativado" do
      tenant = inactive_tenant_fixture()

      assert {:error, :tenant_inactive} = Tenancy.scope(tenant.id)
    end

    test "rejeita Tenant inexistente" do
      assert {:error, :tenant_not_found} = Tenancy.scope(Ecto.UUID.generate())
    end

    test "rejeita nil" do
      assert {:error, :tenant_not_found} = Tenancy.scope(nil)
    end

    test "rejeita valor que não é UUID" do
      for valor <- ["nao-e-uuid", "", 42, %{}, [], :atom, "1234"] do
        assert {:error, :tenant_not_found} = Tenancy.scope(valor),
               "aceitou #{inspect(valor)} como identificador de Tenant"
      end
    end

    test "NÃO cria Tenant implicitamente" do
      antes = length(Tenancy.admin_list_tenants())
      id = Ecto.UUID.generate()

      assert {:error, :tenant_not_found} = Tenancy.scope(id)

      assert length(Tenancy.admin_list_tenants()) == antes
      assert {:error, :not_found} = Tenancy.admin_fetch_tenant(id)
    end

    test "emite telemetria em cada rejeição, com o motivo" do
      # Rejeição silenciosa de escopo esconde tanto defeito de código quanto tentativa de
      # acesso indevido. Sem o evento, nada distingue "não há dados" de "acesso barrado".
      :telemetry.attach_many(
        "test-scope-rejected",
        [[:the_band, :tenancy, :scope, :rejected]],
        fn _e, _m, meta, pid -> send(pid, {:rejeitado, meta.reason}) end,
        self()
      )

      on_exit(fn -> :telemetry.detach("test-scope-rejected") end)

      inativo = inactive_tenant_fixture()

      Tenancy.scope(inativo.id)
      assert_receive {:rejeitado, :tenant_inactive}

      Tenancy.scope(Ecto.UUID.generate())
      assert_receive {:rejeitado, :tenant_not_found}
    end
  end

  describe "scope!/1" do
    test "devolve escopo para Tenant ativo" do
      tenant = tenant_fixture()

      assert %Scope{} = Tenancy.scope!(tenant.id)
    end

    test "levanta com motivo nomeado para Tenant inativo" do
      tenant = inactive_tenant_fixture()

      erro = assert_raise ScopeError, fn -> Tenancy.scope!(tenant.id) end

      assert Exception.message(erro) =~ "tenant_inactive"
    end

    test "levanta para Tenant inexistente" do
      assert_raise ScopeError, fn -> Tenancy.scope!(Ecto.UUID.generate()) end
    end
  end

  describe "scope_by_slug/1" do
    test "devolve escopo do Tenant com aquele identificador legível" do
      tenant = tenant_fixture()

      assert {:ok, scope} = Tenancy.scope_by_slug(tenant.slug)
      assert Scope.tenant_id!(scope) == tenant.id
    end

    test "rejeita identificador legível inexistente e Tenant inativo" do
      assert {:error, :tenant_not_found} = Tenancy.scope_by_slug("nao-existe-este-slug")

      inativo = inactive_tenant_fixture()
      assert {:error, :tenant_inactive} = Tenancy.scope_by_slug(inativo.slug)
    end

    test "rejeita entrada que não é string" do
      assert {:error, :tenant_not_found} = Tenancy.scope_by_slug(nil)
      assert {:error, :tenant_not_found} = Tenancy.scope_by_slug(123)
    end
  end

  describe "Scope.tenant_id!/1 — a invariante central" do
    test "LEVANTA para nil, em vez de devolver vazio" do
      erro = assert_raise ArgumentError, fn -> Scope.tenant_id!(nil) end

      assert Exception.message(erro) =~ "sem escopo de Tenant"

      assert Exception.message(erro) =~ "FR-014",
             "a mensagem precisa dizer qual requisito está em jogo, senão quem tropeça nela " <>
               "acha que faltou uma verificação de nulo"
    end

    test "LEVANTA para qualquer coisa que não seja escopo" do
      for valor <- [nil, "uuid-cru", %{tenant_id: "x"}, 42, [], :atom] do
        assert_raise ArgumentError, fn -> Scope.tenant_id!(valor) end
      end
    end

    test "escopo não é construtível fora de Tenancy" do
      # `Scope.new/1` é `@doc false` e só é chamada depois de validar. Se ela virar pública, um
      # escopo poderia apontar para Tenant inexistente ou inativo, e toda função que confia em
      # receber `Scope.t()` perderia a garantia.
      docs =
        case Code.fetch_docs(Scope) do
          {:docs_v1, _, _, _, _, _, docs} -> docs
          _ -> []
        end

      new_doc =
        Enum.find_value(docs, fn
          {{:function, :new, 1}, _, _, doc, _} -> doc
          _ -> nil
        end)

      assert new_doc == :hidden,
             "Scope.new/1 deixou de ser @doc false — construir escopo sem validação fura a " <>
               "invariante do módulo"
    end
  end
end
