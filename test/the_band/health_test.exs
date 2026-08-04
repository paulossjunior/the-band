defmodule TheBand.HealthTest do
  @moduledoc """
  FR-001, FR-002 — verificação de saúde em dois níveis.

  ## Por que a verificação de componentes fica atrás de um comportamento

  `TheBand.Health` consulta os componentes através de `TheBand.Health.Checker`, resolvido em
  configuração. Sem essa fronteira, testar "armazenamento indisponível" exigiria derrubar o
  processo do repositório no meio da suíte — lento, propenso a vazar estado entre testes, e
  incapaz de simular resposta lenta ou erro específico.

  Foi um ponto marcado como subespecificado na análise de artefatos, e resolvido aqui.
  """

  use ExUnit.Case, async: true

  import Mox

  alias TheBand.Health

  setup :verify_on_exit!

  setup do
    anterior = Application.get_env(:the_band, :health_checker)
    Application.put_env(:the_band, :health_checker, TheBand.Health.CheckerMock)
    on_exit(fn -> Application.put_env(:the_band, :health_checker, anterior) end)
    :ok
  end

  describe "detailed/0" do
    test "reporta saudável quando todos os componentes respondem" do
      expect(TheBand.Health.CheckerMock, :database, fn -> :up end)
      expect(TheBand.Health.CheckerMock, :background_jobs, fn -> :up end)

      assert Health.detailed() == %{
               status: :healthy,
               components: %{database: :up, background_jobs: :up}
             }
    end

    test "reporta não saudável e identifica o componente com falha" do
      expect(TheBand.Health.CheckerMock, :database, fn -> :down end)
      expect(TheBand.Health.CheckerMock, :background_jobs, fn -> :up end)

      assert Health.detailed() == %{
               status: :unhealthy,
               components: %{database: :down, background_jobs: :up}
             }
    end

    test "reporta não saudável quando o trabalho assíncrono está fora" do
      expect(TheBand.Health.CheckerMock, :database, fn -> :up end)
      expect(TheBand.Health.CheckerMock, :background_jobs, fn -> :down end)

      assert Health.detailed().status == :unhealthy
    end

    test "consulta todos os componentes mesmo quando o primeiro já falhou" do
      # Parar no primeiro erro esconderia falhas simultâneas e obrigaria a corrigir e
      # reconsultar para descobrir a segunda.
      expect(TheBand.Health.CheckerMock, :database, fn -> :down end)
      expect(TheBand.Health.CheckerMock, :background_jobs, fn -> :down end)

      assert Health.detailed() == %{
               status: :unhealthy,
               components: %{database: :down, background_jobs: :down}
             }
    end

    test "trata exceção do verificador como componente fora, sem propagar" do
      # A verificação de saúde não pode falhar por causa da coisa que ela está verificando:
      # uma exceção propagada devolveria erro 500 em vez de 503 com diagnóstico.
      expect(TheBand.Health.CheckerMock, :database, fn -> raise "conexão recusada" end)
      expect(TheBand.Health.CheckerMock, :background_jobs, fn -> :up end)

      assert Health.detailed() == %{
               status: :unhealthy,
               components: %{database: :down, background_jobs: :up}
             }
    end
  end
end
