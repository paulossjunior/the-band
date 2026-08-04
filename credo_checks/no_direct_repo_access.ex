defmodule TheBand.Credo.Check.NoDirectRepoAccess do
  @moduledoc """
  Reprova chamada direta a `TheBand.Repo` fora dos módulos autorizados (SC-002).

  ## Por que isto existe

  SC-002 exige que **100% dos acessos a dados passem pela abstração de escopo de Tenant**, e
  exige que isso seja verificado automaticamente — não por revisão. Sob a cláusula
  `Mantenedor único` da constituição não existe revisão humana a que recorrer.

  Em Elixir não é possível tornar um módulo privado. A fronteira precisa ser imposta por
  análise estática, ou é só um comentário.

  ## Por que esta checagem, e não Row Level Security

  RLS do PostgreSQL barraria no banco, o que seria mais forte. Foi testada e descartada nesta
  feature: sem o contexto definido, devolve **zero linhas silenciosamente** em vez de rejeitar,
  transformando perda de contexto em "nenhum dado encontrado". Ver ADR-0002 (chega na issue #7).

  Sem RLS, nada no banco barra um acesso que ignore a abstração. Esta checagem é o que ocupa
  esse lugar.

  ## O que detecta

  Chamada cujo módulo termina em `Repo`, em qualquer forma de qualificação:

      TheBand.Repo.all(...)   # totalmente qualificada
      Repo.all(...)           # após `alias TheBand.Repo`

  A segunda forma é a **idiomática** em Elixir, e a primeira versão desta checagem só
  detectava a primeira. O furo foi encontrado provando a checagem contra uma violação
  deliberada com alias: ela não sinalizou nada. Uma checagem que perde a forma que todo mundo
  escreve é pior que nenhuma, porque dá a impressão de cobertura.

  ## Limitação registrada

  Não detecta:

    * `Ecto.Adapters.SQL.query(TheBand.Repo, ...)`, onde o repositório é argumento e não
      receptor da chamada. Aparece no código legítimo e não é alvo.
    * `alias TheBand.Repo, as: Armazem` seguido de `Armazem.all(...)`
    * `apply/3` com o módulo em variável

  As duas últimas são contorno deliberado. Análise estática não previne contorno deliberado —
  previne descuido. Contorno deliberado é o que revisão de intenção previne, e a limitação fica
  registrada aqui em vez de escondida.
  """

  use Credo.Check,
    id: "TB001",
    base_priority: :higher,
    category: :warning,
    explanations: [
      check: """
      Acesso a dado tenant-scoped precisa passar pela abstração de escopo.

      Chamar `TheBand.Repo` direto contorna o escopo de Tenant, e sem Row Level Security nada no
      banco barra o acesso — a consulta simplesmente devolve dado de todos os contratantes.

      Em vez de:

          TheBand.Repo.all(TheBand.Audit.OperationalEvent)

      Use a API pública do módulo correspondente, com escopo validado:

          {:ok, scope} = TheBand.Tenancy.scope(tenant_id)
          TheBand.Audit.list_events(scope)

      Se este módulo realmente precisa acesso direto, acrescente-o à lista de autorizados na
      própria checagem, com o motivo. A lista curta e revisável é o ponto: ampliar é mudança
      visível em revisão, não efeito colateral.
      """
    ]

  # Módulos autorizados a chamar `TheBand.Repo` diretamente.
  #
  # Cada entrada é uma exceção consciente, com motivo. A lista é intencionalmente curta:
  # ampliá-la é uma mudança que aparece no diff e precisa ser justificada.
  @authorized [
    # Definem a fronteira. São eles que aplicam o filtro por `tenant_id`.
    "TheBand.Tenancy.Queries",
    "TheBand.Tenancy.Commands",
    "TheBand.Audit.Queries",
    "TheBand.Audit.Commands",

    # Sonda de conectividade. Executa `SELECT 1` e não lê linha alguma: a regra existe para
    # impedir acesso a DADO de Tenant sem escopo, e aqui não há dado.
    "TheBand.Health.SystemChecker"
  ]

  # Migrações rodam fora de qualquer contexto de Tenant por natureza.
  @authorized_prefixes ["TheBand.Repo.Migrations."]

  # Casa qualquer módulo cujo último segmento seja `Repo`, cobrindo tanto
  # `TheBand.Repo.all(...)` quanto `Repo.all(...)` após `alias TheBand.Repo`.
  #
  # Existe apenas um repositório neste projeto, então o risco de falso positivo é teórico. Se um
  # segundo módulo terminado em `Repo` aparecer e não for um repositório Ecto, a decisão passa a
  # ser explícita: acrescentar à lista de autorizados ou tornar a correspondência mais estreita.
  @repo_segment :Repo

  @impl true
  def run(%SourceFile{} = source_file, params \\ []) do
    issue_meta = IssueMeta.for(source_file, params)

    if authorized?(source_file) do
      []
    else
      Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    end
  end

  defp authorized?(source_file) do
    case module_name(source_file) do
      nil ->
        false

      name ->
        name in @authorized or
          Enum.any?(@authorized_prefixes, &String.starts_with?(name, &1))
    end
  end

  defp module_name(source_file) do
    source_file
    |> SourceFile.ast()
    |> find_module_name()
  end

  defp find_module_name({:defmodule, _, [{:__aliases__, _, parts} | _]}) do
    Enum.map_join(parts, ".", &Atom.to_string/1)
  end

  defp find_module_name({:__block__, _, children}) do
    Enum.find_value(children, &find_module_name/1)
  end

  defp find_module_name(_), do: nil

  defp traverse(
         {{:., meta, [{:__aliases__, _, parts}, fun]}, _, _args} = ast,
         issues,
         issue_meta
       ) do
    if List.last(parts) == @repo_segment do
      modulo = Enum.map_join(parts, ".", &Atom.to_string/1)
      {ast, [issue_for(issue_meta, meta[:line], modulo, fun) | issues]}
    else
      {ast, issues}
    end
  end

  defp traverse(ast, issues, _issue_meta), do: {ast, issues}

  defp issue_for(issue_meta, line_no, modulo, fun) do
    format_issue(issue_meta,
      message:
        "Chamada direta a #{modulo}.#{fun} fora dos módulos autorizados. " <>
          "Use a API pública com escopo de Tenant validado (SC-002).",
      trigger: "#{modulo}.#{fun}",
      line_no: line_no
    )
  end
end
