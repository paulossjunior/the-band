defmodule TheBand.Jobs.TenantHealthCheck do
  @moduledoc """
  Trabalhador de referência (FR-021 a FR-027).

  Verifica que a plataforma consegue executar trabalho em segundo plano no escopo de um Tenant, e
  serve de modelo para **todo** trabalhador futuro — os conectores da feature 025 em diante.

  ## Por que `{:cancel, motivo}` e nunca `{:error, motivo}`

  Verificado por execução na pesquisa da Fase 0. `{:cancel, motivo}` produz situação `cancelled`,
  `attempt = 1`, motivo persistido em `errors`, e **nenhuma nova tentativa**.

  `{:error, motivo}` faria o Oban reprocessar até `max_attempts`. Para Tenant ausente,
  inexistente ou inativo isso violaria FR-024 diretamente: retentar não vai fazer o Tenant
  passar a existir nem voltar a estar ativo, e a fila acumularia trabalho condenado.

  A distinção é entre falha **transitória** — conexão caiu, limite de taxa atingido, que merece
  nova tentativa — e falha **definitiva**, que não muda com o tempo.

  ## Como a falha transitória chega aqui

  **Por exceção levantada, não por tupla de erro.** Este trabalhador não tem caminho que devolva
  `{:error, motivo}`: todos os seus modos de falha conhecidos são definitivos. Uma versão anterior
  tinha uma cláusula para `{:error, _}` e o compilador a apontou como inalcançável —
  corretamente, porque `--warnings-as-errors` está ativo.

  Falha de infraestrutura — conexão com o armazenamento recusada, tempo esgotado — **levanta**.
  O Oban trata exceção levantada como falha retentável e aplica `max_attempts` com espera
  crescente, que é onde a política de FR-025 age. A exceção é capturada aqui apenas para emitir
  telemetria com o código de erro, e **relançada** para que o Oban faça seu trabalho.

  ## Ordem de validação obrigatória

      1. `tenant_id` presente nos argumentos?      não → {:cancel, "tenant_id ausente"}
      2. TheBand.Tenancy.scope/1                   {:error, :tenant_not_found} → {:cancel, …}
                                                   {:error, :tenant_inactive}  → {:cancel, …}
      3. trabalho de fato, com o escopo validado

  O passo 2 usa `TheBand.Tenancy.scope/1`, a mesma função de todo acesso a dados. Este módulo
  **não** consulta a tabela de Tenants por conta própria: isso duplicaria a regra de validação em
  dois lugares, e a cópia que ficasse desatualizada seria descoberta por um vazamento.

  ## Idempotência

  Duas camadas, ambas necessárias.

  Unicidade de enfileiramento vem de `unique:` na definição do trabalho: inserir os mesmos
  argumentos dentro da janela devolve o **mesmo** registro com `conflict?: true`, em vez de criar
  um segundo trabalho.

  Idempotência de **efeito** não vem de graça. Se o nó reiniciar no meio da execução, o trabalho
  roda de novo, e a proteção precisa estar na escrita. Aqui o efeito é gravar um evento
  operacional, e o evento carrega o identificador do trabalho em `metadata`, o que permite
  reconhecer a reexecução no histórico em vez de fingir que ela não aconteceu.
  """

  use Oban.Worker,
    queue: :default,
    # Três tentativas: suficiente para falha transitória de rede, curto o bastante para não
    # esconder falha real atrás de repetição.
    max_attempts: 3,
    unique: [period: 60, fields: [:worker, :args]]

  alias TheBand.Audit
  alias TheBand.Telemetry.Correlation
  alias TheBand.Tenancy

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: args, id: job_id, attempt: attempt}) do
    # A correlação vem dos argumentos quando quem enfileirou a forneceu, o que liga o trabalho à
    # requisição que o originou. O dicionário do processo não é herdado, então precisa ser
    # definido aqui explicitamente.
    correlation = args["correlation_id"] || Correlation.generate()
    Correlation.put(correlation)
    Logger.metadata(correlation_id: correlation, tenant_id: args["tenant_id"])

    metadata = %{
      tenant_id: args["tenant_id"],
      correlation_id: correlation,
      job_id: job_id,
      attempt: attempt
    }

    :telemetry.execute([:the_band, :job, :start], %{}, metadata)

    inicio = System.monotonic_time()

    try do
      resultado = run(args, job_id, correlation)

      emit_stop(resultado, System.monotonic_time() - inicio, metadata)

      resultado
    rescue
      erro ->
        # Emite telemetria com o código de erro e RELANÇA: o Oban precisa ver a exceção para
        # aplicar nova tentativa com espera crescente. Engolir aqui transformaria falha
        # transitória em trabalho silenciosamente perdido.
        :telemetry.execute(
          [:the_band, :job, :exception],
          %{duration: System.monotonic_time() - inicio},
          metadata
          |> Map.put(:status, :exception)
          |> Map.put(:error_code, erro.__struct__)
        )

        reraise erro, __STACKTRACE__
    end
  end

  # Passo 1 — `tenant_id` presente?
  defp run(%{"tenant_id" => tenant_id}, job_id, correlation) when is_binary(tenant_id) do
    # Passo 2 — escopo validado. Existência E ativação, pela mesma função de todo acesso.
    case Tenancy.scope(tenant_id) do
      {:ok, scope} ->
        do_check(scope, job_id, correlation)

      {:error, :tenant_not_found} ->
        {:cancel, "tenant inexistente: #{tenant_id}"}

      {:error, :tenant_inactive} ->
        {:cancel, "tenant inativo: #{tenant_id}"}
    end
  end

  defp run(_args, _job_id, _correlation) do
    {:cancel, "tenant_id ausente"}
  end

  # Passo 3 — o trabalho de fato.
  defp do_check(scope, job_id, correlation) do
    case Audit.record_event(scope, %{
           type: "tenant.health_check",
           correlation_id: correlation,
           # O identificador do trabalho no evento é o que permite reconhecer reexecução: se o nó
           # reiniciar, o trabalho roda de novo e o histórico mostra dois eventos com o mesmo
           # `job_id`, em vez de esconder que aconteceu.
           metadata: %{"job_id" => job_id}
         }) do
      {:ok, _event} ->
        :ok

      {:error, changeset} ->
        # Falha de validação não é transitória: repetir com a mesma entrada dá o mesmo erro.
        {:cancel, "evento operacional rejeitado: #{inspect(changeset.errors)}"}
    end
  end

  defp emit_stop(:ok, duracao, metadata) do
    :telemetry.execute(
      [:the_band, :job, :stop],
      %{duration: duracao},
      Map.put(metadata, :status, :completed)
    )
  end

  defp emit_stop({:cancel, motivo}, duracao, metadata) do
    :telemetry.execute(
      [:the_band, :job, :stop],
      %{duration: duracao},
      metadata |> Map.put(:status, :cancelled) |> Map.put(:error_code, :cancelled)
    )

    Logger.warning("trabalho cancelado: #{motivo}")
  end
end
