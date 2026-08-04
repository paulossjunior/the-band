defmodule TheBandWeb.Plugs.OperatorSecretTest do
  @moduledoc """
  FR-003, SC-009 — a verificação de saúde detalhada exige segredo de operação.

  ## O que este arquivo protege

  Três recusas indistinguíveis: sem cabeçalho, com segredo errado, e com segredo ausente da
  configuração do servidor. Distinguir a terceira informaria a quem sonda que a instalação
  está com configuração faltando — exatamente o momento em que ela é mais frágil.

  E que segredo ausente **recusa**, nunca libera. Um plug que libera quando não há segredo
  configurado transforma erro de implantação em porta aberta.
  """

  use TheBandWeb.ConnCase, async: false

  alias TheBandWeb.Plugs.OperatorSecret

  @secret "segredo-de-operacao-com-tamanho-razoavel-para-teste"

  defp com_segredo(valor) do
    anterior = Application.get_env(:the_band, :operator_secret)
    Application.put_env(:the_band, :operator_secret, valor)
    on_exit(fn -> Application.put_env(:the_band, :operator_secret, anterior) end)
  end

  describe "com segredo configurado" do
    setup do
      com_segredo(@secret)
      :ok
    end

    test "deixa passar com o segredo correto", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{@secret}")
        |> OperatorSecret.call([])

      refute conn.halted
      assert conn.status == nil
    end

    test "recusa sem cabeçalho", %{conn: conn} do
      conn = OperatorSecret.call(conn, [])

      assert conn.halted
      assert conn.status == 401
      assert Jason.decode!(conn.resp_body) == %{"error" => "unauthorized"}
    end

    test "recusa com segredo errado", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer errado-mas-com-o-mesmo-tamanho-do-certo-x")
        |> OperatorSecret.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "recusa segredo correto com esquema errado" do
      for cabecalho <- [@secret, "Basic #{@secret}", "bearer#{@secret}", "Token #{@secret}"] do
        conn =
          build_conn()
          |> put_req_header("authorization", cabecalho)
          |> OperatorSecret.call([])

        assert conn.halted, "aceitou o cabeçalho #{inspect(cabecalho)}"
        assert conn.status == 401
      end
    end

    test "recusa prefixo do segredo correto", %{conn: conn} do
      prefixo = String.slice(@secret, 0, 10)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{prefixo}")
        |> OperatorSecret.call([])

      assert conn.halted
    end

    test "as três recusas têm corpo e situação idênticos" do
      sem = build_conn() |> OperatorSecret.call([])

      errado =
        build_conn()
        |> put_req_header("authorization", "Bearer valor-errado-qualquer-para-comparar")
        |> OperatorSecret.call([])

      com_segredo(nil)

      ausente =
        build_conn()
        |> put_req_header("authorization", "Bearer #{@secret}")
        |> OperatorSecret.call([])

      assert sem.status == errado.status
      assert errado.status == ausente.status

      assert sem.resp_body == errado.resp_body
      assert errado.resp_body == ausente.resp_body
    end
  end

  describe "sem segredo configurado" do
    setup do
      com_segredo(nil)
      :ok
    end

    test "recusa qualquer acesso, em vez de liberar", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer qualquer-coisa")
        |> OperatorSecret.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "recusa também quando o segredo configurado é string vazia", %{conn: conn} do
      com_segredo("")

      conn =
        conn
        |> put_req_header("authorization", "Bearer ")
        |> OperatorSecret.call([])

      assert conn.halted,
             "segredo vazio casaria com cabeçalho vazio e abriria o caminho detalhado"
    end
  end
end
