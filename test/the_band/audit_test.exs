defmodule TheBand.AuditTest do
  @moduledoc """
  FR-014, FR-018 a FR-020, FR-030 — eventos operacionais.
  """

  use TheBand.DataCase, async: true

  import TheBand.TenancyFixtures

  alias TheBand.Audit
  alias TheBand.Telemetry.Correlation
  alias TheBand.Tenancy.Scope

  setup do
    {_tenant, scope} = scoped_tenant_fixture()
    {:ok, scope: scope}
  end

  describe "record_event/2" do
    test "grava com o tenant_id do escopo", %{scope: scope} do
      assert {:ok, evento} = Audit.record_event(scope, %{type: "sync.started"})

      assert evento.type == "sync.started"
      assert evento.tenant_id == Scope.tenant_id!(scope)
    end

    test "preenche occurred_at quando ausente", %{scope: scope} do
      antes = DateTime.utc_now()
      {:ok, evento} = Audit.record_event(scope, %{type: "x"})

      assert DateTime.compare(evento.occurred_at, antes) in [:gt, :eq]
    end

    test "preenche correlation_id quando ausente", %{scope: scope} do
      # Evento sem correlação é registro que não serve para reconstituir cadeia. Exigir que
      # cada chamador informe garantiria que alguém esqueceria.
      Correlation.clear()

      {:ok, evento} = Audit.record_event(scope, %{type: "x"})

      assert Correlation.valid?(evento.correlation_id)
    end

    test "reaproveita a correlação do processo quando existe", %{scope: scope} do
      id = Correlation.put("correlacao-do-processo-atual")

      {:ok, evento} = Audit.record_event(scope, %{type: "x"})

      assert evento.correlation_id == id
    end

    test "aceita chaves como átomo ou string", %{scope: scope} do
      assert {:ok, a} = Audit.record_event(scope, %{type: "atomo"})
      assert {:ok, b} = Audit.record_event(scope, %{"type" => "string"})

      assert a.type == "atomo"
      assert b.type == "string"
    end

    test "exige tipo", %{scope: scope} do
      assert {:error, cs} = Audit.record_event(scope, %{})
      assert cs.errors[:type]
    end

    test "rejeita tipo longo demais", %{scope: scope} do
      assert {:error, cs} = Audit.record_event(scope, %{type: String.duplicate("a", 101)})
      assert cs.errors[:type]
    end
  end

  describe "metadata sensível é REJEITADA, não mascarada (FR-030)" do
    test "rejeita chave de nome sensível", %{scope: scope} do
      sensiveis = [
        "api_token",
        "password",
        :secret,
        "GITHUB_TOKEN",
        "client_secret",
        "authorization",
        :private_key
      ]

      for chave <- sensiveis do
        assert {:error, cs} =
                 Audit.record_event(scope, %{
                   type: "x",
                   metadata: %{chave => "valor-que-nao-deve-entrar"}
                 }),
               "aceitou chave sensível: #{inspect(chave)}"

        assert cs.errors[:metadata]
      end
    end

    test "rejeitar na escrita, e não mascarar na leitura, é deliberado", %{scope: scope} do
      # Mascarar depois pressupõe que o valor já foi persistido — e num banco isso alcança
      # backup, réplica e log de replicação. Rejeitar impede a entrada.
      {:error, _} = Audit.record_event(scope, %{type: "x", metadata: %{"token" => "abc"}})

      assert Audit.count_events(scope) == 0, "o evento foi gravado apesar do erro"
    end

    test "aceita metadata sem chave sensível", %{scope: scope} do
      assert {:ok, evento} =
               Audit.record_event(scope, %{
                 type: "x",
                 metadata: %{"repository" => "the-band", "count" => 42}
               })

      assert evento.metadata == %{"repository" => "the-band", "count" => 42}
    end

    test "rejeita metadata que não é mapa", %{scope: scope} do
      assert {:error, cs} = Audit.record_event(scope, %{type: "x", metadata: "texto"})
      assert cs.errors[:metadata]
    end
  end

  describe "list_events/2 e count_events/1" do
    test "lista mais recentes primeiro", %{scope: scope} do
      base = DateTime.utc_now()

      for i <- 1..3 do
        event_fixture(scope, %{
          type: "e#{i}",
          occurred_at: DateTime.add(base, i, :second)
        })
      end

      tipos = scope |> Audit.list_events() |> Enum.map(& &1.type)

      assert tipos == ["e3", "e2", "e1"]
    end

    test "respeita o limite", %{scope: scope} do
      events_fixture(scope, 5)

      assert length(Audit.list_events(scope, limit: 2)) == 2
    end

    test "limite padrão é 100", %{scope: scope} do
      events_fixture(scope, 3)

      assert length(Audit.list_events(scope)) == 3
    end

    test "conta zero quando não há evento", %{scope: scope} do
      assert Audit.count_events(scope) == 0
    end
  end

  describe "fetch_event/2" do
    test "encontra evento do próprio escopo", %{scope: scope} do
      evento = event_fixture(scope)

      assert {:ok, encontrado} = Audit.fetch_event(scope, evento.id)
      assert encontrado.id == evento.id
    end

    test "devolve not_found para identificador inexistente ou inválido", %{scope: scope} do
      assert {:error, :not_found} = Audit.fetch_event(scope, Ecto.UUID.generate())
      assert {:error, :not_found} = Audit.fetch_event(scope, "nao-e-uuid")
    end
  end

  describe "ausência de escopo LEVANTA (FR-014)" do
    test "nenhuma função escopada devolve vazio sem escopo" do
      for fun <- [
            fn -> Audit.list_events(nil) end,
            fn -> Audit.count_events(nil) end,
            fn -> Audit.record_event(nil, %{type: "x"}) end,
            fn -> Audit.fetch_event(nil, Ecto.UUID.generate()) end
          ] do
        assert_raise ArgumentError, fun
      end
    end
  end
end
