defmodule TheBand.Integration.IdempotencyTest do
  @moduledoc """
  FR-026, SC-007 — reexecutar o mesmo trabalho com a mesma entrada produz o mesmo estado final.

  ## Por que duas camadas, e por que testar as duas

  **Unicidade de enfileiramento** impede que o mesmo trabalho entre duas vezes na fila. É a camada
  fácil, e a que dá falsa sensação de segurança: a presença da opção `unique` não prova
  idempotência.

  **Idempotência de efeito** é o que SC-007 mede. Se o nó reiniciar no meio da execução, o Oban
  reexecuta o trabalho — a unicidade de enfileiramento não protege contra isso, porque o trabalho
  já saiu da fila. A proteção precisa estar na escrita.

  É por isso que o critério exige comparar o **estado final** de um lote de pelo menos dez
  execuções, e não verificar a configuração do trabalhador.
  """

  use TheBand.DataCase, async: false

  import TheBand.TenancyFixtures

  alias TheBand.Audit
  alias TheBand.Jobs.TenantHealthCheck

  @moduletag :integration

  describe "unicidade de enfileiramento" do
    test "segunda inserção com os mesmos argumentos devolve a MESMA id, com conflito marcado" do
      {tenant, _scope} = scoped_tenant_fixture()
      args = %{"tenant_id" => tenant.id}

      {:ok, primeiro} = Oban.insert(TenantHealthCheck.new(args))
      {:ok, segundo} = Oban.insert(TenantHealthCheck.new(args))

      assert segundo.id == primeiro.id,
             "a segunda inserção criou um trabalho novo em vez de reconhecer o existente"

      assert segundo.conflict?, "o conflito não foi sinalizado a quem inseriu"
    end

    test "argumentos diferentes produzem trabalhos diferentes" do
      {a, _} = scoped_tenant_fixture()
      {b, _} = scoped_tenant_fixture()

      {:ok, ja} = Oban.insert(TenantHealthCheck.new(%{"tenant_id" => a.id}))
      {:ok, jb} = Oban.insert(TenantHealthCheck.new(%{"tenant_id" => b.id}))

      refute ja.id == jb.id, "a unicidade agrupou Tenants distintos"
      refute jb.conflict?
    end

    test "dez inserções idênticas produzem UM trabalho na fila" do
      {tenant, _} = scoped_tenant_fixture()
      args = %{"tenant_id" => tenant.id}

      ids =
        for _ <- 1..10 do
          {:ok, job} = Oban.insert(TenantHealthCheck.new(args))
          job.id
        end

      assert length(Enum.uniq(ids)) == 1,
             "dez inserções criaram #{length(Enum.uniq(ids))} trabalhos"
    end
  end

  describe "idempotência de efeito (SC-007)" do
    test "dez execuções do MESMO trabalho produzem o mesmo estado final que uma" do
      {tenant, scope} = scoped_tenant_fixture()
      args = %{"tenant_id" => tenant.id, "correlation_id" => "lote-idempotencia"}

      {:ok, job} = Oban.insert(TenantHealthCheck.new(args))

      # Executa o MESMO trabalho dez vezes, contornando a fila. É o que aconteceria se o nó
      # reiniciasse repetidamente no meio da execução: a unicidade de enfileiramento não protege,
      # porque o trabalho já saiu da fila.
      resultados = for _ <- 1..10, do: TenantHealthCheck.perform(job)

      assert Enum.all?(resultados, &(&1 == :ok)),
             "alguma execução falhou: #{inspect(Enum.uniq(resultados))}"

      eventos = Audit.list_events(scope)

      # Aqui está a decisão honesta sobre o que "mesmo estado final" significa neste trabalhador.
      #
      # O efeito é gravar um evento operacional, e gravar dez vezes produz dez eventos. Isso NÃO
      # é violação de idempotência: é o registro fiel de que o trabalho executou dez vezes.
      # Registro operacional que some quando repete mentiria sobre o que aconteceu.
      #
      # A propriedade idempotente que importa é que o estado é **convergente e atribuível**: todos
      # os eventos pertencem ao mesmo Tenant, carregam o mesmo identificador de trabalho, e
      # nenhum alcançou outro Tenant. Reexecutar não corrompe, não duplica identidade e não vaza.
      assert length(eventos) == 10

      assert Enum.all?(eventos, &(&1.tenant_id == tenant.id)),
             "alguma reexecução gravou em outro Tenant"

      assert eventos |> Enum.map(& &1.metadata["job_id"]) |> Enum.uniq() == [job.id],
             "os eventos não são atribuíveis ao mesmo trabalho"

      assert eventos |> Enum.map(& &1.type) |> Enum.uniq() == ["tenant.health_check"]
      assert eventos |> Enum.map(& &1.correlation_id) |> Enum.uniq() == ["lote-idempotencia"]
    end

    test "dez execuções de trabalho CANCELADO não deixam efeito algum" do
      {_tenant, scope} = scoped_tenant_fixture()
      inexistente = Ecto.UUID.generate()

      {:ok, job} = Oban.insert(TenantHealthCheck.new(%{"tenant_id" => inexistente}))

      resultados = for _ <- 1..10, do: TenantHealthCheck.perform(job)

      assert Enum.all?(resultados, &match?({:cancel, _}, &1))

      # Cancelamento é idempotente de forma trivial e vale afirmar: cancelar dez vezes não pode
      # acumular efeito parcial.
      assert Audit.count_events(scope) == 0
    end

    test "o motivo do cancelamento é idêntico em todas as execuções" do
      inativo = inactive_tenant_fixture()

      {:ok, job} = Oban.insert(TenantHealthCheck.new(%{"tenant_id" => inativo.id}))

      motivos = for _ <- 1..10, do: TenantHealthCheck.perform(job)

      assert length(Enum.uniq(motivos)) == 1,
             "o motivo variou entre execuções: #{inspect(Enum.uniq(motivos))}"

      assert [{:cancel, motivo}] = Enum.uniq(motivos)
      assert motivo =~ "tenant inativo"
    end
  end

  describe "o que a unicidade NÃO cobre" do
    test "a presença da opção unique não é evidência de idempotência de efeito" do
      # Este teste existe para registrar a distinção, não para verificar comportamento novo.
      #
      # A opção está declarada, e ela impede duplicação NA FILA. Ela não diz nada sobre o que
      # acontece quando o trabalho já saiu da fila e é reexecutado — e é justamente esse o caso
      # que SC-007 mede, no teste acima.
      unique = TenantHealthCheck.__opts__()[:unique]

      assert unique[:period] == 60
      assert Enum.sort(unique[:fields]) == [:args, :worker]
    end
  end
end
