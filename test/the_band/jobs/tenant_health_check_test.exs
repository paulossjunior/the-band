defmodule TheBand.Jobs.TenantHealthCheckTest do
  @moduledoc """
  FR-022 a FR-024, FR-027, FR-028, SC-005, SC-006, SC-016.

  ## A asserção que mais importa

  `attempt == 1` nos casos cancelados.

  Ela prova que **não houve nova tentativa**. Se o trabalhador devolvesse `{:error, motivo}` em
  vez de `{:cancel, motivo}`, o Oban reprocessaria até o limite, e `attempt` chegaria a 3 — para
  um Tenant que não vai passar a existir nem voltar a estar ativo pela repetição.

  Verificar apenas a situação final não pegaria isso: um trabalho descartado após três tentativas
  também termina fora de `completed`.
  """

  use TheBand.DataCase, async: false

  import TheBand.TenancyFixtures

  alias TheBand.Jobs.TenantHealthCheck
  alias TheBand.Repo

  # Executa o trabalho como o Oban executaria — inserido, drenado, e o registro lido de volta do
  # banco. Chamar `perform/1` direto testaria a função e não o comportamento do trabalho.
  # Primeiro motivo registrado em `errors`, sem o rastro de pilha.
  defp motivo(%Oban.Job{errors: [%{"error" => erro} | _]}), do: erro
  defp motivo(%Oban.Job{errors: []}), do: nil

  defp executar(args) do
    {:ok, job} = Oban.insert(TenantHealthCheck.new(args))

    Oban.drain_queue(queue: :default)

    Repo.reload!(job)
  end

  describe "os quatro casos de FR-023 e FR-024" do
    test "Tenant ativo conclui" do
      {tenant, _scope} = scoped_tenant_fixture()

      job = executar(%{"tenant_id" => tenant.id})

      assert job.state == "completed"
      assert job.attempt == 1
      assert job.errors == []
    end

    test "sem tenant_id é CANCELADO sem nova tentativa" do
      job = executar(%{})

      assert job.state == "cancelled"

      assert job.attempt == 1,
             "attempt=#{job.attempt} indica retentativa. Trabalho sem Tenant não deve ser " <>
               "reprocessado: repetir não vai fazer o tenant_id aparecer."

      assert motivo(job) =~ "tenant_id ausente"
    end

    test "Tenant inexistente é CANCELADO sem nova tentativa" do
      id = Ecto.UUID.generate()

      job = executar(%{"tenant_id" => id})

      assert job.state == "cancelled"
      assert job.attempt == 1
      assert motivo(job) =~ "tenant inexistente"
      assert motivo(job) =~ id
    end

    test "Tenant inativo é CANCELADO sem nova tentativa" do
      tenant = inactive_tenant_fixture()

      job = executar(%{"tenant_id" => tenant.id})

      assert job.state == "cancelled"

      assert job.attempt == 1,
             "retentar não vai fazer o Tenant voltar a estar ativo — FR-024"

      assert motivo(job) =~ "tenant inativo"
    end

    test "tenant_id que não é texto é CANCELADO" do
      for valor <- [123, %{}, [], nil] do
        job = executar(%{"tenant_id" => valor})

        assert job.state == "cancelled", "aceitou tenant_id #{inspect(valor)}"
        assert job.attempt == 1
      end
    end
  end

  describe "o motivo fica persistido e consultável (FR-027)" do
    test "errors carrega o motivo do cancelamento" do
      job = executar(%{"tenant_id" => Ecto.UUID.generate()})

      assert [%{"error" => erro} | _] = job.errors
      assert erro =~ "tenant inexistente"

      # Persistido no banco, não apenas em log: quem diagnostica consulta a fila, não o terminal.
      recarregado = Repo.reload!(job)
      assert recarregado.errors == job.errors
    end

    test "trabalho concluído não deixa erro" do
      {tenant, _} = scoped_tenant_fixture()

      job = executar(%{"tenant_id" => tenant.id})

      assert job.errors == []
      assert job.completed_at
    end
  end

  describe "o trabalho registra evento operacional no escopo (FR-018, FR-021)" do
    test "grava evento no Tenant do trabalho, e em nenhum outro" do
      {tenant_a, scope_a} = scoped_tenant_fixture()
      {_tenant_b, scope_b} = scoped_tenant_fixture()

      job = executar(%{"tenant_id" => tenant_a.id})

      assert job.state == "completed"
      assert TheBand.Audit.count_events(scope_a) == 1
      assert TheBand.Audit.count_events(scope_b) == 0, "o evento vazou para outro Tenant"

      [evento] = TheBand.Audit.list_events(scope_a)
      assert evento.type == "tenant.health_check"
      assert evento.metadata["job_id"] == job.id
    end

    test "trabalho cancelado NÃO grava evento" do
      {_tenant, scope} = scoped_tenant_fixture()

      executar(%{"tenant_id" => Ecto.UUID.generate()})

      assert TheBand.Audit.count_events(scope) == 0
    end
  end

  describe "telemetria carrega os campos de FR-028 (SC-016)" do
    setup do
      eventos = [
        [:the_band, :job, :start],
        [:the_band, :job, :stop],
        [:the_band, :job, :exception]
      ]

      :telemetry.attach_many(
        "test-job-telemetry",
        eventos,
        fn nome, medidas, meta, pid -> send(pid, {:telemetria, nome, medidas, meta}) end,
        self()
      )

      on_exit(fn -> :telemetry.detach("test-job-telemetry") end)
      :ok
    end

    test "início e fim carregam Tenant, correlação, trabalho e tentativa" do
      {tenant, _} = scoped_tenant_fixture()

      job = executar(%{"tenant_id" => tenant.id})

      assert_received {:telemetria, [:the_band, :job, :start], _, meta_inicio}
      assert meta_inicio.tenant_id == tenant.id
      assert meta_inicio.job_id == job.id
      assert meta_inicio.attempt == 1
      assert is_binary(meta_inicio.correlation_id)

      assert_received {:telemetria, [:the_band, :job, :stop], medidas, meta_fim}
      assert meta_fim.status == :completed
      assert is_integer(medidas.duration)
    end

    test "cancelamento carrega situação e código de erro" do
      executar(%{"tenant_id" => Ecto.UUID.generate()})

      assert_received {:telemetria, [:the_band, :job, :stop], medidas, meta}
      assert meta.status == :cancelled
      assert meta.error_code == :cancelled
      assert is_integer(medidas.duration)
    end

    test "a correlação fornecida nos argumentos é propagada" do
      {tenant, _} = scoped_tenant_fixture()
      correlacao = "correlacao-de-quem-enfileirou"

      executar(%{"tenant_id" => tenant.id, "correlation_id" => correlacao})

      assert_received {:telemetria, [:the_band, :job, :start], _, meta}

      assert meta.correlation_id == correlacao,
             "sem isto, o trabalho não pode ser ligado à requisição que o originou"
    end
  end

  describe "política de novas tentativas (FR-025)" do
    test "o trabalhador declara limite máximo de tentativas" do
      assert TenantHealthCheck.__opts__()[:max_attempts] == 3
    end

    test "o trabalhador declara unicidade de enfileiramento" do
      unique = TenantHealthCheck.__opts__()[:unique]

      assert unique[:period] == 60
      assert :worker in unique[:fields]
      assert :args in unique[:fields]
    end
  end
end
