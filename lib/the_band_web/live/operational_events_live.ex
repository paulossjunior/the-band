defmodule TheBandWeb.OperationalEventsLive do
  @moduledoc """
  Feature 040 — primeira fatia vertical. Tela e backend na mesma entrega.

  Atravessa todas as camadas com dado que já existe: banco → escopo de Tenant → consulta → LiveView
  → tela. Nenhuma ontologia, nenhum YAML, nenhum conector.

  ## Sem controle de acesso, e isso é declarado

  Não existe autenticação nesta plataforma. Esta tela recebe o slug do Tenant na URL, e **qualquer
  pessoa que a alcance lê qualquer Tenant**. Por isso ela vive sob rota somente de desenvolvimento,
  como o LiveDashboard do Phoenix, e o aviso aparece na própria tela — FR-010 e FR-011.

  A alternativa seria segurança de fachada: exigir um segredo que o navegador não tem como enviar,
  ou fingir que o slug na URL é autorização.

  ## Por que a tela não mostra o nome do Tenant

  `TheBand.Tenancy.Scope` carrega **apenas** `tenant_id`, por desenho. Obter o nome exigiria
  `admin_fetch_tenant/1`, que é o caminho **administrativo** — existe para Tenant desativado e opera
  fora de escopo. Chamá-lo de uma tela seria desvio semântico para um dado cosmético.

  O slug identifica o Tenant e é o que a URL já carrega. Se o nome vier a ser necessário, ele entra
  por consulta escopada própria, não por atalho pelo caminho administrativo.

  ## A contagem acompanha o filtro

  FR-002. `Audit.count_events/2` recebe **os mesmos** filtros de `Audit.list_events/2`. Enquanto a
  contagem não aceitava filtro, esta tela exibiria "142 eventos" mostrando 3 — um número que
  contradiz o que está nela.
  """

  use TheBandWeb, :live_view

  alias TheBand.Audit
  alias TheBand.Tenancy

  @limite 200

  @periodos [
    {"Últimas 24 horas", "24h"},
    {"Últimos 7 dias", "7d"},
    {"Últimos 30 dias", "30d"},
    {"Todo o período", "tudo"}
  ]

  @impl true
  def mount(%{"tenant_slug" => slug} = params, _session, socket) do
    case Tenancy.scope_by_slug(slug) do
      {:ok, scope} ->
        {:ok,
         socket
         |> assign(
           scope: scope,
           slug: slug,
           periodos: @periodos,
           tipos: Audit.list_event_types(scope),
           filtro_tipo: Map.get(params, "tipo", ""),
           filtro_periodo: Map.get(params, "periodo", "24h"),
           filtro_correlacao: Map.get(params, "correlacao", ""),
           erro: nil
         )
         |> carregar()}

      {:error, _} ->
        # FR-009: recusa sem revelar se o slug existe em outro lugar. A mensagem é a mesma para slug
        # inexistente e para Tenant inativo, de propósito.
        {:ok,
         assign(socket,
           scope: nil,
           slug: slug,
           erro: "Nenhum Tenant ativo com este identificador.",
           eventos: [],
           total: 0,
           tipos: [],
           periodos: @periodos,
           filtro_tipo: "",
           filtro_periodo: "24h",
           filtro_correlacao: ""
         )}
    end
  end

  @impl true
  def handle_params(params, _uri, %{assigns: %{scope: scope}} = socket) when not is_nil(scope) do
    {:noreply,
     socket
     |> assign(
       filtro_tipo: Map.get(params, "tipo", ""),
       filtro_periodo: Map.get(params, "periodo", "24h"),
       filtro_correlacao: Map.get(params, "correlacao", "")
     )
     |> carregar()}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("filtrar", %{"tipo" => tipo, "periodo" => periodo}, socket) do
    {:noreply, push_patch(socket, to: caminho(socket.assigns.slug, tipo, periodo, ""))}
  end

  def handle_event("limpar", _params, socket) do
    {:noreply, push_patch(socket, to: caminho(socket.assigns.slug, "", "tudo", ""))}
  end

  # ── carregamento ────────────────────────────────────────────────────────────────────────────

  defp carregar(%{assigns: assigns} = socket) do
    filtros = filtros_de(assigns)

    eventos = Audit.list_events(assigns.scope, Keyword.put(filtros, :limit, @limite))

    assign(socket,
      eventos: eventos,
      # A MESMA lista de filtros vai para a contagem. É o requisito FR-002, e é o que impede a tela
      # de exibir um número que contradiz suas próprias linhas.
      total: Audit.count_events(assigns.scope, filtros),
      total_sem_filtro: Audit.count_events(assigns.scope)
    )
  end

  defp filtros_de(assigns) do
    []
    |> then(fn f ->
      if assigns.filtro_tipo == "", do: f, else: [{:type, assigns.filtro_tipo} | f]
    end)
    |> then(fn f ->
      if assigns.filtro_correlacao == "",
        do: f,
        else: [{:correlation_id, assigns.filtro_correlacao} | f]
    end)
    |> then(fn f ->
      case instante_inicial(assigns.filtro_periodo) do
        nil -> f
        since -> [{:since, since} | f]
      end
    end)
  end

  defp instante_inicial("24h"), do: DateTime.add(DateTime.utc_now(), -24, :hour)
  defp instante_inicial("7d"), do: DateTime.add(DateTime.utc_now(), -7, :day)
  defp instante_inicial("30d"), do: DateTime.add(DateTime.utc_now(), -30, :day)
  defp instante_inicial(_), do: nil

  defp caminho(slug, tipo, periodo, correlacao) do
    query =
      %{"tipo" => tipo, "periodo" => periodo, "correlacao" => correlacao}
      |> Enum.reject(fn {_k, v} -> v == "" end)
      |> URI.encode_query()

    "/dev/eventos/#{slug}?#{query}"
  end

  defp filtrando?(assigns) do
    assigns.filtro_tipo != "" or assigns.filtro_correlacao != "" or
      assigns.filtro_periodo != "tudo"
  end

  # ── tela ────────────────────────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-5xl px-4 py-8">
        <div class="mb-6 rounded-lg border border-amber-400/60 bg-amber-50 px-4 py-3 text-sm text-amber-900">
          <strong>Tela de desenvolvimento, sem controle de acesso.</strong>
          Esta plataforma ainda não tem autenticação: quem alcança esta URL lê qualquer Tenant. Por
          isso a rota não existe fora de desenvolvimento.
        </div>

        <h1 class="text-2xl font-semibold tracking-tight">Eventos operacionais</h1>

        <%= if @erro do %>
          <div
            id="erro"
            class="mt-6 rounded-lg border border-red-300 bg-red-50 px-4 py-3 text-red-900"
          >
            {@erro}
          </div>
        <% else %>
          <p class="mt-1 text-sm text-zinc-500">
            Tenant <span class="font-mono">{@slug}</span>
          </p>

          <.form
            for={%{}}
            id="filtros"
            phx-change="filtrar"
            phx-submit="filtrar"
            class="mt-6 flex flex-wrap items-end gap-3"
          >
            <label class="flex flex-col gap-1 text-sm">
              <span class="text-zinc-600">Tipo</span>
              <select id="filtro-tipo" name="tipo" class="rounded-md border-zinc-300 text-sm">
                <option value="" selected={@filtro_tipo == ""}>Todos os tipos</option>
                <option :for={t <- @tipos} value={t} selected={@filtro_tipo == t}>{t}</option>
              </select>
            </label>

            <label class="flex flex-col gap-1 text-sm">
              <span class="text-zinc-600">Período</span>
              <select id="filtro-periodo" name="periodo" class="rounded-md border-zinc-300 text-sm">
                <option
                  :for={{rotulo, valor} <- @periodos}
                  value={valor}
                  selected={@filtro_periodo == valor}
                >
                  {rotulo}
                </option>
              </select>
            </label>

            <%= if @filtro_correlacao != "" do %>
              <div class="flex flex-col gap-1 text-sm">
                <span class="text-zinc-600">Correlação</span>
                <span
                  id="filtro-correlacao"
                  class="rounded-md bg-zinc-100 px-2 py-1 font-mono text-xs"
                >
                  {@filtro_correlacao}
                </span>
              </div>
            <% end %>

            <button
              :if={filtrando?(assigns)}
              type="button"
              id="limpar"
              phx-click="limpar"
              class="rounded-md border border-zinc-300 px-3 py-1.5 text-sm hover:bg-zinc-50"
            >
              Limpar filtros
            </button>
          </.form>

          <p id="contagem" class="mt-4 text-sm text-zinc-600">
            <span class="font-semibold text-zinc-900">{@total}</span>
            {if @total == 1, do: "evento", else: "eventos"}
            <%= if filtrando?(assigns) do %>
              com este filtro, de <span class="font-semibold">{@total_sem_filtro}</span> no Tenant
            <% end %>
            <%= if @total > length(@eventos) do %>
              — exibindo os {length(@eventos)} mais recentes
            <% end %>
          </p>

          <%= if @eventos == [] do %>
            <div
              id="vazio"
              class="mt-6 rounded-lg border border-zinc-200 px-4 py-8 text-center text-zinc-500"
            >
              <%= if @total_sem_filtro == 0 do %>
                Este Tenant ainda não tem evento algum.
              <% else %>
                Nenhum evento com este filtro. O Tenant tem {@total_sem_filtro} no total.
              <% end %>
            </div>
          <% else %>
            <table id="eventos" class="mt-4 w-full border-collapse text-sm">
              <thead>
                <tr class="border-b border-zinc-200 text-left text-xs uppercase tracking-wide text-zinc-500">
                  <th class="py-2 pr-4 font-medium">Quando</th>
                  <th class="py-2 pr-4 font-medium">Tipo</th>
                  <th class="py-2 font-medium">Correlação</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={e <- @eventos} id={"evento-#{e.id}"} class="border-b border-zinc-100">
                  <td class="py-2 pr-4 font-mono text-xs text-zinc-600">
                    {Calendar.strftime(e.occurred_at, "%d/%m %H:%M:%S")}
                  </td>
                  <td class="py-2 pr-4">{e.type}</td>
                  <td class="py-2">
                    <%= if e.correlation_id do %>
                      <.link
                        patch={caminho(@slug, "", "tudo", e.correlation_id)}
                        class="font-mono text-xs text-blue-700 hover:underline"
                      >
                        {e.correlation_id}
                      </.link>
                    <% else %>
                      <span class="text-zinc-400">—</span>
                    <% end %>
                  </td>
                </tr>
              </tbody>
            </table>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
