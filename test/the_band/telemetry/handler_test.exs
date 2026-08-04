defmodule TheBand.Telemetry.HandlerTest do
  @moduledoc """
  FR-030 — nenhuma credencial, token ou payload sensível completo em registro operacional.

  O que estes testes protegem: que um segredo não entre em registro permanente. O
  repositório e a infraestrutura são públicos; um valor registrado por engano não é um
  achado a corrigir depois, é um incidente.
  """

  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias TheBand.Telemetry.Handler

  describe "sensitive?/1" do
    test "reconhece os fragmentos declarados, em átomo e em string" do
      for fragment <- Handler.sensitive_fragments() do
        assert Handler.sensitive?(fragment), "fragmento #{fragment} deveria ser sensível"

        assert Handler.sensitive?(String.to_atom(fragment)),
               "fragmento #{fragment} como átomo deveria ser sensível"
      end
    end

    test "reconhece por substring e ignorando caixa" do
      assert Handler.sensitive?("GITHUB_TOKEN")
      assert Handler.sensitive?(:refresh_token)
      assert Handler.sensitive?("X-Api-Key")
      assert Handler.sensitive?("userPassword")
      assert Handler.sensitive?(:client_secret)
    end

    test "não marca chave comum como sensível" do
      for key <- [:tenant_id, :correlation_id, :job_id, :attempt, :duration, :status, :type] do
        refute Handler.sensitive?(key), "#{key} é exigida por FR-028 e não pode ser redigida"
      end
    end
  end

  describe "redact/1" do
    test "redige valor sob chave sensível e preserva os demais" do
      assert Handler.redact(%{user: "ana", api_token: "abc123"}) ==
               %{user: "ana", api_token: "[REDACTED]"}
    end

    test "redige em profundidade, dentro de mapas aninhados" do
      entrada = %{args: %{"password" => "x", "id" => 1}}

      assert Handler.redact(entrada) == %{args: %{"password" => "[REDACTED]", "id" => 1}}
    end

    test "redige dentro de listas" do
      entrada = %{items: [%{secret: "a"}, %{name: "b"}]}

      assert Handler.redact(entrada) == %{items: [%{secret: "[REDACTED]"}, %{name: "b"}]}
    end

    test "redige a chave sensível por inteiro quando o valor é mapa" do
      # Preservar a estrutura interna vazaria os nomes dos campos, que já são informação
      # sobre o que a credencial contém.
      assert Handler.redact(%{credentials: %{"user" => "ana", "pass" => "x"}}) ==
               %{credentials: "[REDACTED]"}
    end

    test "preserva os campos exigidos por FR-028" do
      entrada = %{
        tenant_id: "t-1",
        correlation_id: "c-1",
        job_id: 42,
        attempt: 1,
        duration: 1234,
        status: :ok,
        error_code: nil
      }

      assert Handler.redact(entrada) == entrada
    end

    test "não altera valores que não são mapa nem lista" do
      assert Handler.redact("texto") == "texto"
      assert Handler.redact(42) == 42
      assert Handler.redact(nil) == nil
    end

    test "não tenta percorrer struct" do
      # Percorrer struct converteria para mapa e perderia o tipo. `DateTime` aparece em
      # metadados de evento e precisa sobreviver intacto.
      agora = ~U[2026-08-04 12:00:00.000000Z]

      assert Handler.redact(%{occurred_at: agora}) == %{occurred_at: agora}
    end
  end

  describe "handle_event/4" do
    setup do
      Handler.attach()

      # `config/test.exs` define o nível do Logger em `:warning` para manter a saída dos
      # testes limpa. Os eventos de FR-028 são registrados em `:info`, então precisam do
      # nível baixado aqui — e restaurado depois, senão os demais testes ficariam ruidosos.
      nivel_anterior = Logger.level()
      Logger.configure(level: :info)
      on_exit(fn -> Logger.configure(level: nivel_anterior) end)

      :ok
    end

    test "registra os campos de FR-028 e redige o que é sensível" do
      log =
        capture_log(fn ->
          :telemetry.execute(
            [:the_band, :job, :stop],
            %{duration: 1234},
            %{
              tenant_id: "t-1",
              correlation_id: "c-1",
              job_id: 7,
              attempt: 1,
              status: :completed,
              args: %{"api_token" => "nunca-deveria-aparecer"}
            }
          )
        end)

      assert log =~ "tenant_id="
      assert log =~ "correlation_id="
      assert log =~ "job_id=7"
      assert log =~ "attempt=1"
      assert log =~ "duration=1234"
      assert log =~ "status=:completed"
      assert log =~ "[REDACTED]"

      refute log =~ "nunca-deveria-aparecer",
             "o valor sensível vazou para o registro operacional"
    end

    test "registra exceção de trabalho em nível de erro" do
      log =
        capture_log(fn ->
          :telemetry.execute(
            [:the_band, :job, :exception],
            %{duration: 5},
            %{tenant_id: "t-1", job_id: 9, attempt: 3, error_code: :timeout}
          )
        end)

      assert log =~ "[error]"
      assert log =~ "error_code=:timeout"
    end

    test "registra rejeição de escopo em nível de aviso" do
      log =
        capture_log(fn ->
          :telemetry.execute(
            [:the_band, :tenancy, :scope, :rejected],
            %{},
            %{reason: :tenant_inactive}
          )
        end)

      assert log =~ "[warning]"
      assert log =~ "reason=:tenant_inactive"
    end

    test "attach/0 é idempotente e não duplica o registro" do
      Handler.attach()
      Handler.attach()

      log =
        capture_log(fn ->
          :telemetry.execute([:the_band, :health, :check], %{}, %{component: :database})
        end)

      ocorrencias = log |> String.split("component=:database") |> length() |> Kernel.-(1)

      assert ocorrencias == 1, "o evento foi registrado #{ocorrencias} vezes, esperado 1"
    end
  end
end
