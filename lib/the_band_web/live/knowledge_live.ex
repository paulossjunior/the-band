defmodule TheBandWeb.KnowledgeLive do
  @moduledoc """
  A base de conhecimento na tela — leva 2 do roadmap.

  ## Por que esta tela existe

  A feature 002 entregava maquinaria de validação **sem nada que se possa olhar**. Sob o modelo de
  vertical slice, ela passa a entrar junto com o consumidor que a torna verificável por quem opera, e
  não só por teste.

  O que se vê: o que o manifesto declara, quais arquivos a base contém, e **o que a validação
  recusou — com arquivo, linha e coluna**.

  ## A tela diz o que a verificação NÃO cobre

  Integridade de documento e manifesto são verificados; validação de campo por esquema, vocabulários
  fechados e reciprocidade **não** são — issue #22. O aviso fica na tela, não só na especificação.

  Uma tela que mostrasse "base válida" sem essa ressalva afirmaria mais do que a verificação
  garante, e é exatamente a mentira que esta feature existe para evitar.

  ## Sem controle de acesso

  Mesma razão da tela de eventos operacionais: não existe autenticação nesta plataforma. Rota somente
  de desenvolvimento, e o aviso aparece na própria tela.
  """

  use TheBandWeb, :live_view

  alias TheBand.Knowledge

  @impl true
  def mount(_params, _session, socket) do
    {:ok, carregar(socket)}
  end

  @impl true
  def handle_event("revalidar", _params, socket) do
    # A base é lida do disco a cada revalidação, de propósito: em desenvolvimento quem escreve YAML
    # precisa ver o efeito sem reiniciar. Isto NÃO é o caminho de runtime — aquele carrega uma vez na
    # inicialização, para `:persistent_term` (ADR-0006), e chega na issue #25.
    {:noreply, socket |> carregar() |> put_flash(:info, "Base revalidada.")}
  end

  defp carregar(socket) do
    {estado, r} = Knowledge.inspect_base()

    assign(socket,
      estado: estado,
      relatorio: r,
      ausentes: Knowledge.esquemas_ausentes(),
      exigidos: Knowledge.tipos_exigidos()
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-5xl px-4 py-8">
        <div class="mb-6 rounded-lg border border-amber-400/60 bg-amber-50 px-4 py-3 text-sm text-amber-900">
          <strong>Tela de desenvolvimento, sem controle de acesso.</strong>
          Esta plataforma ainda não tem autenticação. Por isso a rota não existe fora de desenvolvimento.
        </div>

        <div class="flex items-start justify-between gap-4">
          <div>
            <h1 class="text-2xl font-semibold tracking-tight">Base de conhecimento</h1>
            <p class="mt-1 font-mono text-xs text-zinc-500">{@relatorio.base}</p>
          </div>
          <button
            id="revalidar"
            phx-click="revalidar"
            class="rounded-md border border-zinc-300 px-3 py-1.5 text-sm hover:bg-zinc-50"
          >
            Revalidar
          </button>
        </div>

        <div
          id="estado"
          class={[
            "mt-6 rounded-lg border px-4 py-3 text-sm",
            @estado == :ok && "border-emerald-300 bg-emerald-50 text-emerald-900",
            @estado == :error && "border-red-300 bg-red-50 text-red-900"
          ]}
        >
          <%= if @estado == :ok do %>
            <strong>Base íntegra.</strong>
            {@relatorio.arquivos_inspecionados} arquivos inspecionados, nenhuma violação.
          <% else %>
            <strong>{length(@relatorio.violacoes)} violação(ões).</strong>
            {@relatorio.arquivos_inspecionados} arquivos inspecionados.
          <% end %>
        </div>

        <%= if @relatorio.manifest do %>
          <h2 class="mt-8 text-sm font-semibold uppercase tracking-wide text-zinc-500">Manifesto</h2>
          <dl id="manifesto" class="mt-2 grid grid-cols-1 gap-x-8 gap-y-2 sm:grid-cols-2">
            <div class="flex justify-between border-b border-zinc-100 py-1 text-sm">
              <dt class="text-zinc-600">Nome</dt>
              <dd class="font-mono">{@relatorio.manifest.name}</dd>
            </div>
            <div class="flex justify-between border-b border-zinc-100 py-1 text-sm">
              <dt class="text-zinc-600">Versão</dt>
              <dd class="font-mono">{@relatorio.manifest.version}</dd>
            </div>
            <div class="flex justify-between border-b border-zinc-100 py-1 text-sm">
              <dt class="text-zinc-600">Idiomas exigidos</dt>
              <dd class="font-mono">{Enum.join(@relatorio.manifest.required_languages, " · ")}</dd>
            </div>
            <div class="flex justify-between border-b border-zinc-100 py-1 text-sm">
              <dt class="text-zinc-600">Versão de esquema</dt>
              <dd class="font-mono">{@relatorio.manifest.default_schema_version}</dd>
            </div>
            <div class="flex justify-between border-b border-zinc-100 py-1 text-sm sm:col-span-2">
              <dt class="text-zinc-600">Ontologias declaradas</dt>
              <dd class="font-mono">
                <%= if @relatorio.manifest.ontologies == [] do %>
                  <span class="text-zinc-400">nenhuma — as doze chegam da feature 003 em diante</span>
                <% else %>
                  {Enum.join(@relatorio.manifest.ontologies, " · ")}
                <% end %>
              </dd>
            </div>
          </dl>
        <% else %>
          <div
            id="sem-manifesto"
            class="mt-8 rounded-lg border border-red-300 bg-red-50 px-4 py-3 text-sm text-red-900"
          >
            <strong>Manifesto ilegível.</strong>
            Ele é o ponto de entrada da base: sem ele não se sabe quais idiomas são exigidos, qual
            versão de esquema vale, nem quais ontologias a base contém.
          </div>
        <% end %>

        <h2 class="mt-8 text-sm font-semibold uppercase tracking-wide text-zinc-500">
          Esquemas de validação
          <span id="contagem-esquemas" class="ml-1 font-normal normal-case text-zinc-400">
            {length(@relatorio.schemas)} de {length(@exigidos)}
          </span>
        </h2>

        <%= if @ausentes != [] do %>
          <div
            id="esquemas-ausentes"
            class="mt-2 rounded-lg border border-red-300 bg-red-50 px-4 py-3 text-sm text-red-900"
          >
            <strong>Ausentes: {Enum.join(@ausentes, ", ")}.</strong>
            Sem eles, arquivos daquele tipo seriam pulados enquanto a contagem permanece maior que
            zero — e a validação aprovaria.
          </div>
        <% end %>

        <table id="esquemas" class="mt-2 w-full border-collapse text-sm">
          <tbody>
            <tr :for={s <- @relatorio.schemas} id={"esquema-#{s.id}"} class="border-b border-zinc-100">
              <td class="py-1.5 pr-4 font-mono text-xs">{s.id}</td>
              <td class="py-1.5 pr-4 text-zinc-600">{s.describes}</td>
              <td class="py-1.5 font-mono text-xs text-zinc-400">{s.path}</td>
            </tr>
          </tbody>
        </table>

        <%= if @relatorio.violacoes != [] do %>
          <h2 class="mt-8 text-sm font-semibold uppercase tracking-wide text-red-600">
            O que a validação recusou
          </h2>
          <ul id="violacoes" class="mt-2 space-y-2">
            <li
              :for={{v, i} <- Enum.with_index(@relatorio.violacoes)}
              id={"violacao-#{i}"}
              class="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm"
            >
              <div class="font-mono text-xs text-red-900">
                {v.path}
                <%= if v.line do %>
                  :{v.line}
                  <%= if v.column do %>
                    :{v.column}
                  <% end %>
                <% end %>
              </div>
              <div class="mt-0.5 text-red-800">{v.message}</div>
            </li>
          </ul>
        <% end %>

        <%= if @relatorio.ignorados != [] do %>
          <p id="ignorados" class="mt-6 text-xs text-zinc-500">
            {length(@relatorio.ignorados)} arquivo(s) ignorado(s): {Enum.join(
              @relatorio.ignorados,
              ", "
            )}.
            A contagem aparece porque exclusão que não é contada é indistinguível de arquivo que não
            foi encontrado.
          </p>
        <% end %>

        <div
          id="limitacao"
          class="mt-8 rounded-lg border border-zinc-200 bg-zinc-50 px-4 py-3 text-xs text-zinc-600"
        >
          <strong>O que esta verificação ainda NÃO cobre.</strong>
          Integridade de documento e manifesto são verificados. Validação de campo por esquema,
          vocabulários fechados e reciprocidade entre conceito e relação <strong>não são</strong>
          — issue #22. Uma tela que dissesse apenas "base válida" afirmaria mais do que a verificação
          garante.
        </div>
      </div>
    </Layouts.app>
    """
  end
end
