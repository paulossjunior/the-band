defmodule Mix.Tasks.Knowledge.Validate do
  @shortdoc "Valida a base de conhecimento YAML"

  @moduledoc """
  Valida `priv/knowledge_base/`.

  ## O que esta tarefa garante, e o que NÃO garante

  Garante: cada arquivo é um documento YAML íntegro, sem âncora, sem apelido, sem chave duplicada,
  sem tabulação na indentação, com um único documento e um mapeamento na raiz; o manifesto é válido;
  e os nove esquemas exigidos estão presentes.

  **Não** garante que o conteúdo esteja semanticamente correto — validação de campo por esquema,
  vocabulários fechados e reciprocidade são a issue #22. O relatório diz isso em voz alta, porque uma
  tarefa cujo nome promete mais do que ela verifica é pior que nenhuma tarefa.

  ## Por que ela reprova quando não encontra arquivo algum

  FR-016. Aprovar sem ter verificado nada é a classe de defeito que a feature 001 encontrou na
  análise estática: `mix credo` sem compilar não carregava as checagens próprias, imprimia
  `Ignoring an undefined check` e **saía com código 0**.

  Por isso esta tarefa reprova em três situações que parecem sucesso: nenhum arquivo inspecionado,
  esquema exigido ausente, e manifesto ilegível.

  ## Uso

      mix knowledge.validate
      mix knowledge.validate --base caminho/para/base
  """

  use Mix.Task

  alias TheBand.Knowledge
  alias TheBand.Knowledge.TokenGate.Violation

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [base: :string])
    base = opts[:base] || Knowledge.base_dir()

    {estado, r} = Knowledge.inspect_base(base)
    ausentes = Knowledge.esquemas_ausentes(base)

    imprimir(r, ausentes)

    cond do
      estado == :error ->
        Mix.raise("A base de conhecimento tem #{length(r.violacoes)} violação(ões).")

      # Contar arquivos NÃO fecha este caminho: um esquema ausente faz os arquivos daquele tipo
      # serem pulados enquanto a contagem permanece maior que zero, e a validação aprova (FR-089).
      ausentes != [] ->
        Mix.raise(
          "Faltam #{length(ausentes)} dos #{length(Knowledge.tipos_exigidos())} esquemas exigidos: " <>
            Enum.join(ausentes, ", ") <>
            ". Sem eles, arquivos daquele tipo seriam pulados sem que nada reprovasse."
        )

      r.arquivos_inspecionados == 0 ->
        Mix.raise(
          "Nenhum arquivo foi inspecionado em #{base}. Aprovar sem ter verificado nada é o " <>
            "defeito que esta verificação existe para impedir."
        )

      true ->
        Mix.shell().info("\n  Base de conhecimento válida.")
    end
  end

  defp imprimir(r, ausentes) do
    sh = Mix.shell()
    sh.info("\n  Base: #{r.base}")

    case r.manifest do
      nil ->
        sh.error("  Manifesto: ILEGÍVEL")

      m ->
        sh.info("  Manifesto: #{m.name} #{m.version}")
        sh.info("  Idiomas exigidos: #{Enum.join(m.required_languages, ", ")}")
        sh.info("  Versão de esquema: #{m.default_schema_version}")

        sh.info(
          "  Ontologias declaradas: #{if m.ontologies == [], do: "nenhuma", else: Enum.join(m.ontologies, ", ")}"
        )
    end

    sh.info("  Esquemas: #{length(r.schemas)} de #{length(Knowledge.tipos_exigidos())}")
    if ausentes != [], do: sh.error("  Esquemas AUSENTES: #{Enum.join(ausentes, ", ")}")

    sh.info("  Arquivos inspecionados: #{r.arquivos_inspecionados}")

    # Exclusão que não é contada é indistinguível de arquivo que não foi encontrado (FR-072).
    if r.ignorados != [] do
      sh.info(
        "  Ignorados: #{length(r.ignorados)} — #{Enum.join(Enum.take(r.ignorados, 5), ", ")}"
      )
    end

    if r.violacoes != [] do
      sh.error("\n  #{length(r.violacoes)} violação(ões):\n")

      # Todas, nunca só a primeira (FR-015). Parar na primeira transforma uma correção em muitas
      # rodadas.
      Enum.each(r.violacoes, fn v ->
        sh.error("    " <> Violation.to_line(v))
      end)
    end

    sh.info(
      "\n  Esta verificação cobre integridade de documento e o manifesto. Validação de campo por " <>
        "esquema, vocabulários fechados e reciprocidade ainda NÃO são verificados — issue #22."
    )
  end
end
