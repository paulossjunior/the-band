defmodule TheBand.Health.SystemChecker do
  @moduledoc """
  Verificação real dos componentes.

  ## Sobre o acesso ao armazenamento

  Este módulo consulta o armazenamento diretamente, e é uma exceção deliberada à regra de que
  apenas `TheBand.Tenancy` e `TheBand.Audit` o fazem. A regra existe para impedir acesso a
  **dado de Tenant** sem escopo. Aqui não há dado: `SELECT 1` prova conectividade e não lê
  linha alguma.

  A exceção está declarada na lista de módulos autorizados da checagem
  `TheBand.Credo.Check.NoDirectRepoAccess` (issue #4), em vez de depender de um ponto cego
  da checagem. Intenção explícita é revisável; contorno acidental não é.

  ## Sobre o tempo limite

  Cada verificação tem tempo limite próprio e curto. Sem isso, uma dependência lenta faria a
  verificação de saúde pendurar em vez de reportar problema — e uma sonda de infraestrutura
  que pendura é pior que uma que responde "fora", porque não dispara nada.
  """

  @behaviour TheBand.Health.Checker

  alias Ecto.Adapters.SQL

  @timeout_ms 2_000

  @impl TheBand.Health.Checker
  def database do
    case SQL.query(TheBand.Repo, "SELECT 1", [], timeout: @timeout_ms) do
      {:ok, %{rows: [[1]]}} -> :up
      _ -> :down
    end
  rescue
    # DBConnection levanta em conexão recusada, e o motivo pode conter host e credencial.
    # Descartado de propósito: FR-004 proíbe expor detalhe de configuração na resposta.
    _ -> :down
  catch
    :exit, _ -> :down
  end

  @impl TheBand.Health.Checker
  def background_jobs do
    # `Oban.check_queue/2` exige uma fila configurada; consultar o processo registrado prova
    # que a supervisão está de pé sem depender do nome de uma fila específica, que muda
    # quando os conectores chegarem.
    case Oban.Registry.whereis(Oban) do
      pid when is_pid(pid) -> if Process.alive?(pid), do: :up, else: :down
      _ -> :down
    end
  rescue
    _ -> :down
  catch
    :exit, _ -> :down
  end
end
