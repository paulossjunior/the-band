# Semeadura de desenvolvimento.
#
#     mix ecto.setup       # cria, migra e semeia
#     mix run priv/repo/seeds.exs
#
# Idempotente: rodar duas vezes não duplica nem falha. `mix ecto.setup` é o primeiro comando de
# quem está começando, e um script de semeadura que falha na segunda execução transforma o
# primeiro contato com o projeto em depuração.
#
# Usa a API pública, não o repositório direto. O comentário original do gerador sugeria
# `TheBand.Repo.insert!/1`, o que contornaria o escopo de Tenant — exatamente o que a checagem
# de análise estática impede em `lib/`. Aqui a regra vale por coerência, não por imposição.
#
# NÃO cria segredo, credencial nem dado pessoal. O repositório é público.

alias TheBand.Audit
alias TheBand.Tenancy

require Logger

slug = "dev"

tenant =
  case Enum.find(Tenancy.admin_list_tenants(), &(&1.slug == slug)) do
    nil ->
      {:ok, novo} =
        Tenancy.register_tenant(%{slug: slug, name: "Tenant de Desenvolvimento"})

      Logger.info("Tenant de desenvolvimento criado: #{novo.slug} (#{novo.id})")
      novo

    existente ->
      Logger.info("Tenant de desenvolvimento já existe: #{existente.slug}")
      existente
  end

{:ok, scope} = Tenancy.scope(tenant.id)

# Um evento operacional, para que o Tenant não nasça sem nada a consultar: quem está explorando
# pela primeira vez precisa ver a listagem devolver algo. Só é registrado se ainda não houver
# nenhum, o que mantém a idempotência.
if Audit.count_events(scope) == 0 do
  {:ok, _} =
    Audit.record_event(scope, %{
      type: "seed.tenant_created",
      metadata: %{"source" => "priv/repo/seeds.exs"}
    })

  Logger.info("Evento operacional de semeadura registrado")
end

Logger.info("""

Semeadura concluída.

  Tenant:        #{tenant.slug}
  Identificador: #{tenant.id}
  Eventos:       #{Audit.count_events(scope)}

Para explorar:

    iex -S mix
    {:ok, scope} = TheBand.Tenancy.scope_by_slug("#{slug}")
    TheBand.Audit.list_events(scope)
    TheBand.Audit.count_events(nil)   # LEVANTA — é o requisito FR-014
""")
