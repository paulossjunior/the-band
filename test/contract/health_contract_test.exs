defmodule TheBand.Contract.HealthContractTest do
  @moduledoc """
  Contrato da verificação de saúde — [`contracts/health.md`](../../specs/001-phoenix-foundation-governance/contracts/health.md).

  FR-001 a FR-004, SC-009.

  ## O que este arquivo protege

  A parte mais importante aqui é **negativa**: o que a resposta pública NÃO pode conter. O
  repositório é público, então a URL fica documentada publicamente. Uma resposta pública que
  detalha componentes entrega reconhecimento de infraestrutura de graça — informa se o banco
  está de pé, se a fila está de pé, e às vezes o tempo de resposta interno.

  Por isso a asserção é de igualdade estrita de chaves, e não `assert body["status"]`: um
  campo novo acrescentado por descuido faria o teste falhar, que é o comportamento desejado.
  """

  # `async: false` porque `set_mox_from_context` põe o Mox em modo global: o dublê precisa ser
  # alcançável por qualquer processo que a requisição toque, não só pelo processo do teste.
  use TheBandWeb.ConnCase, async: false

  import Mox

  alias TheBand.Telemetry.Correlation

  @operator_secret "segredo-de-operacao-para-teste-somente"

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    segredo_anterior = Application.get_env(:the_band, :operator_secret)
    checker_anterior = Application.get_env(:the_band, :health_checker)

    Application.put_env(:the_band, :operator_secret, @operator_secret)
    Application.put_env(:the_band, :health_checker, TheBand.Health.CheckerMock)

    on_exit(fn ->
      Application.put_env(:the_band, :operator_secret, segredo_anterior)
      Application.put_env(:the_band, :health_checker, checker_anterior)
    end)

    :ok
  end

  describe "GET /health — público" do
    test ~s|devolve 200 e corpo exatamente {"status":"alive"}|, %{conn: conn} do
      conn = get(conn, ~p"/health")

      assert conn.status == 200
      assert json_response(conn, 200) == %{"status" => "alive"}
    end

    test "o corpo tem EXATAMENTE uma chave, e é `status`", %{conn: conn} do
      corpo = conn |> get(~p"/health") |> json_response(200)

      assert Map.keys(corpo) == ["status"],
             "a resposta pública ganhou chaves além de `status`: #{inspect(Map.keys(corpo))}. " <>
               "SC-009 exige que ela não revele nada sobre componentes internos."
    end

    test "não revela nome nem estado de componente algum", %{conn: conn} do
      corpo = conn |> get(~p"/health") |> response(200)

      proibidos = ~w(database postgres postgrex repo oban queue background_jobs
                     ecto bandit phoenix elixir otp version host port up down
                     healthy unhealthy)

      for termo <- proibidos do
        refute String.contains?(String.downcase(corpo), termo),
               "a resposta pública contém #{inspect(termo)}, que revela infraestrutura interna"
      end
    end

    test "não exige credencial", %{conn: conn} do
      # Precisa continuar servindo como sonda de infraestrutura sem segredo configurado.
      Application.put_env(:the_band, :operator_secret, nil)

      assert conn |> get(~p"/health") |> json_response(200) == %{"status" => "alive"}
    end

    test "NÃO consulta dependência alguma", %{conn: conn} do
      # Nenhuma expectativa declarada no dublê. `verify_on_exit!` falha se ele for chamado.
      # É esta a garantia de FR-001, e ela vale para o caminho HTTP inteiro — não apenas para
      # uma função de domínio.
      assert conn |> get(~p"/health") |> json_response(200) == %{"status" => "alive"}
    end

    test "responde mesmo com todos os componentes fora", %{conn: conn} do
      # Se o público consultasse dependência, esta requisição devolveria 503. Devolve 200
      # porque não consulta — e é isso que o mantém utilizável como sonda.
      stub(TheBand.Health.CheckerMock, :database, fn -> :down end)
      stub(TheBand.Health.CheckerMock, :background_jobs, fn -> :down end)

      assert conn |> get(~p"/health") |> json_response(200) == %{"status" => "alive"}
    end

    test "devolve o cabeçalho de correlação", %{conn: conn} do
      conn = get(conn, ~p"/health")

      assert [id] = get_resp_header(conn, Correlation.header())
      assert Correlation.valid?(id)
    end
  end

  describe "GET /health/detail — restrito a operação" do
    defp todos_no_ar do
      stub(TheBand.Health.CheckerMock, :database, fn -> :up end)
      stub(TheBand.Health.CheckerMock, :background_jobs, fn -> :up end)
    end

    test "com segredo válido devolve 200 e os dois componentes", %{conn: conn} do
      todos_no_ar()

      corpo =
        conn
        |> put_req_header("authorization", "Bearer #{@operator_secret}")
        |> get(~p"/health/detail")
        |> json_response(200)

      assert corpo["status"] == "healthy"
      assert corpo["components"]["database"] == "up"
      assert corpo["components"]["background_jobs"] == "up"
    end

    test "com armazenamento fora devolve 503 identificando o componente", %{conn: conn} do
      stub(TheBand.Health.CheckerMock, :database, fn -> :down end)
      stub(TheBand.Health.CheckerMock, :background_jobs, fn -> :up end)

      corpo =
        conn
        |> put_req_header("authorization", "Bearer #{@operator_secret}")
        |> get(~p"/health/detail")
        |> json_response(503)

      assert corpo["status"] == "unhealthy"
      assert corpo["components"]["database"] == "down"
      assert corpo["components"]["background_jobs"] == "up"
    end

    test "sem cabeçalho devolve 401 e não revela componente", %{conn: conn} do
      corpo = conn |> get(~p"/health/detail") |> json_response(401)

      assert corpo == %{"error" => "unauthorized"}
    end

    test "com segredo errado devolve 401 com corpo IDÊNTICO ao caso sem cabeçalho",
         %{conn: conn} do
      sem_cabecalho = build_conn() |> get(~p"/health/detail") |> json_response(401)

      com_errado =
        conn
        |> put_req_header("authorization", "Bearer segredo-errado-mas-do-mesmo-tamanho-x")
        |> get(~p"/health/detail")
        |> json_response(401)

      assert com_errado == sem_cabecalho,
             "corpos diferentes permitem distinguir 'credencial errada' de 'ausente', " <>
               "o que informa a quem sonda"
    end

    test "com segredo NÃO configurado recusa, em vez de liberar", %{conn: conn} do
      Application.put_env(:the_band, :operator_secret, nil)

      corpo =
        conn
        |> put_req_header("authorization", "Bearer qualquer-coisa")
        |> get(~p"/health/detail")
        |> json_response(401)

      assert corpo == %{"error" => "unauthorized"}
    end

    test "não expõe credencial, host interno nem rastro de pilha", %{conn: conn} do
      todos_no_ar()

      corpo =
        conn
        |> put_req_header("authorization", "Bearer #{@operator_secret}")
        |> get(~p"/health/detail")
        |> response(200)

      refute String.contains?(corpo, @operator_secret)
      refute String.contains?(corpo, "localhost")
      refute String.contains?(corpo, "postgres")
      refute String.contains?(String.downcase(corpo), "stacktrace")
      refute String.contains?(corpo, "5432")
    end

    test "aceita apenas o esquema Bearer", %{conn: conn} do
      corpo =
        conn
        |> put_req_header("authorization", @operator_secret)
        |> get(~p"/health/detail")
        |> json_response(401)

      assert corpo == %{"error" => "unauthorized"}
    end
  end
end
