defmodule TheBand.Repo do
  @moduledoc """
  Acesso ao armazenamento de dados do The Band.

  ## Quem pode chamar este módulo

  Apenas `TheBand.Tenancy`, `TheBand.Audit`, as migrações e tarefas Mix administrativas
  explicitamente marcadas. Qualquer outro módulo deve receber um `TheBand.Tenancy.Scope`
  e usar a API pública do módulo correspondente.

  A restrição passará a ser imposta por análise estática, não por convenção: a checagem
  `TheBand.Credo.Check.NoDirectRepoAccess` reprova a proposta de mudança que chame este
  módulo de fora da lista de autorizados. Ver SC-002 na especificação da feature 001.

  **Estado atual: a checagem ainda não existe.** Ela chega com a issue #4, junto com
  `TheBand.Tenancy` e `TheBand.Audit`. Até lá, esta fronteira é convenção — e a única
  chamada existente é a do próprio Ecto. Registrado aqui em vez de descrito como se já
  valesse.

  Motivo: sem essa fronteira, um acesso que esqueça o escopo de Tenant não é barrado por
  nada. Row Level Security do PostgreSQL foi avaliada e descartada nesta feature porque,
  na ausência do contexto, devolve conjunto vazio silenciosamente em vez de rejeitar — o
  que transformaria um defeito em "nenhum dado encontrado". Ver ADR-0002 e research.md R2.
  """

  use Ecto.Repo,
    otp_app: :the_band,
    adapter: Ecto.Adapters.Postgres
end
