defmodule TheBandWeb.Plugs.CorrelationIdTest do
  @moduledoc """
  FR-029 — identificador de correlação propagado em toda requisição.

  ## Por que estes testes existem

  A primeira versão desta entrega criou o plug e **não o ligou a nada**. Nenhum teste
  falhou, porque não havia teste: o módulo compilava, a análise de tipos passava, e o
  requisito ficava insatisfeito em silêncio. O defeito foi encontrado na revisão do diff,
  não pelos portões.

  Daí o último teste deste arquivo, que verifica que o plug está de fato no endpoint. Um
  plug correto que ninguém invoca é código morto que parece requisito atendido.
  """

  use TheBandWeb.ConnCase, async: true

  alias TheBand.Telemetry.Correlation
  alias TheBandWeb.Plugs.CorrelationId

  setup do
    on_exit(fn -> Correlation.clear() end)
    :ok
  end

  describe "call/2" do
    test "gera correlação quando o cabeçalho está ausente", %{conn: conn} do
      conn = CorrelationId.call(conn, [])

      [id] = Plug.Conn.get_resp_header(conn, Correlation.header())

      assert Correlation.valid?(id)
      assert conn.assigns.correlation_id == id
      assert Correlation.get() == id
    end

    test "reaproveita a correlação recebida quando é válida", %{conn: conn} do
      recebido = "correlacao-externa-valida-123"

      conn =
        conn
        |> Plug.Conn.put_req_header(Correlation.header(), recebido)
        |> CorrelationId.call([])

      assert Plug.Conn.get_resp_header(conn, Correlation.header()) == [recebido]
      assert conn.assigns.correlation_id == recebido

      # Reaproveitar é o que permite a cadeia atravessar a fronteira entre serviços.
      assert Correlation.get() == recebido
    end

    test "descarta correlação recebida inválida e gera uma nova", %{conn: conn} do
      # Um valor externo termina em registro operacional. Aceitá-lo sem validar permitiria
      # injetar quebra de linha e forjar entradas de log.
      for invalido <- [
            "curto",
            "com espaço no meio",
            "quebra\nde\nlinha",
            String.duplicate("x", 200)
          ] do
        conn =
          conn
          |> Plug.Conn.put_req_header(Correlation.header(), invalido)
          |> CorrelationId.call([])

        [id] = Plug.Conn.get_resp_header(conn, Correlation.header())

        refute id == invalido, "aceitou correlação inválida: #{inspect(invalido)}"
        assert Correlation.valid?(id)
      end
    end

    test "coloca a correlação nos metadados do Logger", %{conn: conn} do
      conn = CorrelationId.call(conn, [])

      assert Keyword.get(Logger.metadata(), :correlation_id) == conn.assigns.correlation_id
    end
  end

  describe "integração com o endpoint" do
    test "toda requisição devolve o cabeçalho de correlação", %{conn: conn} do
      # Passa pelo endpoint completo, não pelo plug isolado. É este teste que pega o plug
      # implementado e não ligado.
      conn = get(conn, ~p"/")

      assert [id] = Plug.Conn.get_resp_header(conn, Correlation.header())
      assert Correlation.valid?(id)
    end

    test "resposta a rota inexistente também carrega correlação", %{conn: conn} do
      # O plug fica no endpoint justamente para cobrir o que o roteador não resolve. Falha em
      # rota desconhecida é onde o diagnóstico mais precisa de correlação — e é onde um plug
      # declarado num pipeline do roteador não chegaria.
      conn = get(conn, "/rota-que-nao-existe")

      assert conn.status == 404

      assert [id] = Plug.Conn.get_resp_header(conn, Correlation.header())
      assert Correlation.valid?(id)
    end

    test "o plug está declarado no endpoint" do
      # Guarda explícita contra o defeito original: plug correto, testado em isolamento, e
      # nunca invocado. Se alguém remover a declaração, este teste falha.
      fonte = File.read!("lib/the_band_web/endpoint.ex")

      assert fonte =~ "plug TheBandWeb.Plugs.CorrelationId",
             "o plug de correlação não está declarado no endpoint, então FR-029 não vale " <>
               "para requisição alguma"
    end
  end
end
