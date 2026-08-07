defmodule TheBandWeb.OperationalEventsLiveTest do
  @moduledoc """
  Feature 040, T009 a T013 — a tela.

  Testa o que a pessoa vê, não a implementação: que a contagem acompanha o filtro, que os dois
  estados vazios são distintos, e que nenhum evento de outro Tenant aparece.
  """

  use TheBandWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import TheBand.TenancyFixtures

  alias TheBand.Audit

  defp evento(escopo, tipo, correlacao \\ nil) do
    correlacao = correlacao || "corr-#{System.unique_integer([:positive])}"

    {:ok, e} =
      Audit.record_event(escopo, %{type: tipo, correlation_id: correlacao, metadata: %{}})

    e
  end

  # NÃO chamar este auxiliar de `url/1`: `ConnCase` importa `Phoenix.VerifiedRoutes`, que exporta
  # `url/1` como macro, e dentro de `live/2` a expansão escolhia a dela — produzindo
  # "expected compile-time ~p path string, got: tenant.slug". O slug só existe em execução.
  defp caminho_da_tela(slug, query \\ "periodo=tudo") do
    Phoenix.VerifiedRoutes.unverified_path(
      TheBandWeb.Endpoint,
      TheBandWeb.Router,
      "/dev/eventos/#{slug}?#{query}"
    )
  end

  describe "FR-005 — a tela lista os eventos" do
    test "mostra os eventos do Tenant", %{conn: conn} do
      {tenant, escopo} = scoped_tenant_fixture()
      e = evento(escopo, "tenant.health_check")

      {:ok, view, html} = live(conn, caminho_da_tela(tenant.slug))

      assert html =~ "Eventos operacionais"
      assert has_element?(view, "#evento-#{e.id}")
      assert render(view) =~ "tenant.health_check"
    end

    test "mostra o slug do Tenant", %{conn: conn} do
      {tenant, _} = scoped_tenant_fixture()
      {:ok, _view, html} = live(conn, caminho_da_tela(tenant.slug))
      assert html =~ tenant.slug
    end
  end

  describe "FR-011 — a limitação de acesso está na própria tela" do
    test "avisa que é tela de desenvolvimento sem controle de acesso", %{conn: conn} do
      {tenant, _} = scoped_tenant_fixture()
      {:ok, _view, html} = live(conn, caminho_da_tela(tenant.slug))

      assert html =~ "sem controle de acesso"
      assert html =~ "não tem autenticação"
    end
  end

  describe "FR-006 e SC-002 — a contagem acompanha o filtro" do
    test "sem filtro, a contagem é o total", %{conn: conn} do
      {tenant, escopo} = scoped_tenant_fixture()
      for _ <- 1..4, do: evento(escopo, "alfa")

      {:ok, view, _html} = live(conn, caminho_da_tela(tenant.slug))
      assert render(view) =~ "4"
      assert element(view, "#contagem") |> render() =~ "4"
    end

    test "com filtro de tipo, a contagem é a do filtro — não o total", %{conn: conn} do
      {tenant, escopo} = scoped_tenant_fixture()
      for _ <- 1..5, do: evento(escopo, "alfa")
      for _ <- 1..2, do: evento(escopo, "beta")

      {:ok, view, _} = live(conn, caminho_da_tela(tenant.slug))

      view
      |> form("#filtros", %{"tipo" => "beta", "periodo" => "tudo"})
      |> render_change()

      contagem = element(view, "#contagem") |> render()

      # O defeito que este teste impede: a tela exibir 7 mostrando 2.
      assert contagem =~ "2"

      # O total vem dentro de um <span>, então a frase não é contígua no HTML. Verificar por
      # substring exigiria conhecer a marcação; verificar os dois números separadamente é o que
      # importa: a tela distingue o filtrado do total.
      assert contagem =~ "com este filtro"
      assert contagem =~ "7", "a tela deve dizer o total do Tenant, sem confundi-lo com o filtro"
      assert contagem =~ "no Tenant"

      # E a lista tem de ter exatamente 2 linhas.
      assert view |> render() |> linhas_de_evento() == 2
    end

    test "o filtro de tipo oferece só os tipos que existem", %{conn: conn} do
      {tenant, escopo} = scoped_tenant_fixture()
      evento(escopo, "so.este.tipo")

      {:ok, view, _} = live(conn, caminho_da_tela(tenant.slug))
      opcoes = element(view, "#filtro-tipo") |> render()

      assert opcoes =~ "so.este.tipo"
    end
  end

  describe "FR-008 — os dois estados vazios são distintos" do
    test "Tenant sem evento algum", %{conn: conn} do
      {tenant, _} = scoped_tenant_fixture()

      {:ok, view, _} = live(conn, caminho_da_tela(tenant.slug))
      assert element(view, "#vazio") |> render() =~ "ainda não tem evento algum"
    end

    test "Tenant com eventos, mas nenhum no filtro", %{conn: conn} do
      {tenant, escopo} = scoped_tenant_fixture()
      for _ <- 1..3, do: evento(escopo, "alfa")

      {:ok, view, _} = live(conn, caminho_da_tela(tenant.slug, "tipo=inexistente&periodo=tudo"))

      vazio = element(view, "#vazio") |> render()
      assert vazio =~ "Nenhum evento com este filtro"
      assert vazio =~ "3 no total"

      refute vazio =~ "ainda não tem evento algum",
             "as duas frases são respostas diferentes; confundi-las faz procurar no lugar errado"
    end
  end

  describe "FR-007 — navegação por correlação" do
    test "o identificador de correlação é um link", %{conn: conn} do
      {tenant, escopo} = scoped_tenant_fixture()
      evento(escopo, "alfa", "corr-visivel")

      {:ok, view, _} = live(conn, caminho_da_tela(tenant.slug))
      assert has_element?(view, "a", "corr-visivel")
    end

    test "seguir a correlação mostra só os eventos dela", %{conn: conn} do
      {tenant, escopo} = scoped_tenant_fixture()
      evento(escopo, "alfa", "corr-alvo")
      evento(escopo, "beta", "corr-alvo")
      de_fora = evento(escopo, "gama", "outra-corr")

      {:ok, view, _} =
        live(conn, caminho_da_tela(tenant.slug, "correlacao=corr-alvo&periodo=tudo"))

      assert view |> render() |> linhas_de_evento() == 2
      assert element(view, "#filtro-correlacao") |> render() =~ "corr-alvo"

      # Asserção pelo identificador da linha, não pela palavra na página. "gama" aparece
      # legitimamente no menu de tipos — o filtro oferece todos os tipos do Tenant — e uma asserção
      # sobre a página inteira reprovaria comportamento correto.
      refute has_element?(view, "#evento-#{de_fora.id}")
    end
  end

  describe "SC-001 — isolamento entre Tenants na tela" do
    test "a tela de um Tenant não mostra evento do outro", %{conn: conn} do
      {tenant_a, escopo_a} = scoped_tenant_fixture()
      {_tenant_b, escopo_b} = scoped_tenant_fixture()

      evento(escopo_a, "evento.de.a")
      do_b = evento(escopo_b, "evento.de.b")

      {:ok, view, html} = live(conn, caminho_da_tela(tenant_a.slug))

      assert html =~ "evento.de.a"
      refute html =~ "evento.de.b"
      refute has_element?(view, "#evento-#{do_b.id}")
    end

    test "a contagem também não soma o do outro", %{conn: conn} do
      {tenant_a, escopo_a} = scoped_tenant_fixture()
      {_tenant_b, escopo_b} = scoped_tenant_fixture()

      for _ <- 1..2, do: evento(escopo_a, "alfa")
      for _ <- 1..9, do: evento(escopo_b, "alfa")

      {:ok, view, _} = live(conn, caminho_da_tela(tenant_a.slug))
      contagem = element(view, "#contagem") |> render()

      assert contagem =~ "2"
      refute contagem =~ "11", "volume do outro Tenant já é informação sobre ele"
    end

    test "o filtro de tipo não oferece tipo do outro Tenant", %{conn: conn} do
      {tenant_a, escopo_a} = scoped_tenant_fixture()
      {_tenant_b, escopo_b} = scoped_tenant_fixture()

      evento(escopo_a, "tipo.de.a")
      evento(escopo_b, "tipo.de.b")

      {:ok, view, _} = live(conn, caminho_da_tela(tenant_a.slug))
      refute element(view, "#filtro-tipo") |> render() =~ "tipo.de.b"
    end
  end

  describe "FR-009 — Tenant inexistente" do
    test "recusa sem revelar se o identificador existe em outro lugar", %{conn: conn} do
      {:ok, view, _} = live(conn, caminho_da_tela("nao-existe-em-lugar-algum"))

      erro = element(view, "#erro") |> render()
      assert erro =~ "Nenhum Tenant ativo"
      refute has_element?(view, "#eventos")
    end

    test "Tenant inativo produz a MESMA mensagem que inexistente", %{conn: conn} do
      inativo = inactive_tenant_fixture()

      {:ok, view_inativo, _} = live(conn, caminho_da_tela(inativo.slug))
      {:ok, view_ausente, _} = live(conn, caminho_da_tela("nao-existe"))

      assert element(view_inativo, "#erro") |> render() ==
               element(view_ausente, "#erro") |> render(),
             "mensagens diferentes revelariam que o slug existe, só está inativo"
    end
  end

  # Conta as linhas de evento pelo identificador que a tela põe em cada uma. A primeira versão usava
  # `LazyHTML.filter/2` com `Enum.count/1`, e devolvia SEMPRE zero — `LazyHTML` não é enumerável
  # dessa forma. Isso fez dois testes reprovarem por motivo diferente do que pareciam.
  defp linhas_de_evento(html) do
    Regex.scan(~r/id="evento-/, html) |> length()
  end
end
