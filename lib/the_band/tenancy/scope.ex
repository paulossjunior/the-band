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
  rejeitar. Ver ADR-0002 e `research.md` R2.

  ## O que é garantido, e o que NÃO é

  Uma versão anterior deste módulo afirmava que o escopo "não é construtível de fora" e que
  "não há como fabricar um escopo que aponte para Tenant inexistente ou inativo". **As duas
  afirmações eram falsas**, e foram apontadas em revisão independente.

  `@opaque` é verificado por análise de tipos, não em execução. Qualquer módulo pode escrever
  `%TheBand.Tenancy.Scope{tenant_id: "outro-tenant"}` e a estrutura funciona. Verificado:

      falso = %Scope{tenant_id: id_do_outro_tenant}
      Audit.list_events(falso)   # devolve os eventos do outro Tenant

  Pior: um escopo fabricado apontando para Tenant **desativado** lê os dados normalmente,
  contornando FR-017, e apontando para Tenant **inexistente** devolve conjunto vazio — o mesmo
  modo de falha silenciosa pelo qual Row Level Security foi descartada.

  ### O que É garantido

  Um escopo obtido por `TheBand.Tenancy.scope/1` ou `scope!/1` teve existência e ativação
  verificadas. Toda função que recebe um escopo **desses** herda a garantia.

  ### O que NÃO é garantido, e por quê

  Que todo `%Scope{}` em circulação veio dali. A construção manual é bloqueada por
  `TheBand.Credo.Check.NoDirectRepoAccess`, que reprova a proposta de mudança ao encontrar
  `%TheBand.Tenancy.Scope{` fora de `TheBand.Tenancy`.

  Isso previne **descuido**, não contorno deliberado. Quem escreve código nesta aplicação e
  quer contornar a validação também poderia chamar o repositório direto. A fronteira é para
  quem erra, não para quem decide burlar — e não existe, em Elixir, construção de estrutura que
  resista a quem edita o código.

  Importante para o modelo de ameaça: **não há caminho de entrada externa que produza um
  escopo.** A camada web chama `TheBand.Tenancy.scope/1` com o identificador recebido. Um
  contratante não escreve código da aplicação, então isto não é vetor de vazamento entre
  contratantes — é uma fronteira interna de disciplina.
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
