defmodule TheBand.Tenancy.Scope do
  @moduledoc """
  Escopo de Tenant validado. A única chave de acesso a dado tenant-scoped.

  ## A invariante que este módulo existe para sustentar

  > Ausência de contexto de Tenant **levanta erro**. Nunca devolve conjunto vazio.

  É por isso que o isolamento é imposto aqui, na aplicação, e não por Row Level Security do
  PostgreSQL. RLS foi testada de ponta a ponta: com o contexto definido isola corretamente e
  rejeita inserção cruzada, mas **sem o contexto devolve zero linhas silenciosamente**.

  Um defeito que perdesse o contexto produziria "nenhum dado encontrado" em vez de falha
  visível — pior que a ausência de proteção, porque parece funcionamento normal. FR-014 exige
  rejeitar. Ver ADR-0002 (chega na issue #7) e `research.md` R2.

  ## Não é construtível de fora

  Só `TheBand.Tenancy.scope/1` e `scope!/1` produzem esta estrutura, e ambas consultam
  existência e ativação antes. Não há como fabricar um escopo que aponte para Tenant
  inexistente ou inativo, o que significa que qualquer função que receba `Scope.t()` já tem
  essa garantia sem precisar reverificar.
  """

  @enforce_keys [:tenant_id]
  defstruct [:tenant_id]

  @opaque t :: %__MODULE__{tenant_id: Ecto.UUID.t()}

  @doc false
  # Deliberadamente `@doc false`: chamada apenas por `TheBand.Tenancy`, depois de validar.
  # Expor isto como API pública permitiria criar escopo sem validação, que é o único jeito de
  # furar a invariante do módulo.
  @spec new(Ecto.UUID.t()) :: t()
  def new(tenant_id) when is_binary(tenant_id), do: %__MODULE__{tenant_id: tenant_id}

  @doc """
  Devolve o identificador do Tenant do escopo.

  Levanta `ArgumentError` para qualquer coisa que não seja um escopo — incluindo `nil`.

  A mensagem de erro nomeia a invariante de propósito: quem tropeça nela precisa entender que
  devolver vazio seria pior, não que faltou uma verificação de nulo.
  """
  @spec tenant_id!(t()) :: Ecto.UUID.t()
  def tenant_id!(%__MODULE__{tenant_id: tenant_id}), do: tenant_id

  def tenant_id!(outro) do
    raise ArgumentError, """
    acesso a dado tenant-scoped sem escopo de Tenant.

    Recebido: #{inspect(outro)}

    Isto levanta em vez de devolver conjunto vazio, e a diferença é o requisito FR-014.
    Devolver vazio transformaria a perda de contexto em "nenhum dado encontrado" — uma falha
    silenciosa que parece funcionamento normal.

    Obtenha um escopo com TheBand.Tenancy.scope/1 ou scope!/1.
    """
  end

  @doc """
  Diz se o valor é um escopo válido. Útil em guarda de fronteira.
  """
  @spec scope?(term()) :: boolean()
  def scope?(%__MODULE__{}), do: true
  def scope?(_), do: false
end
