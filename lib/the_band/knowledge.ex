defmodule TheBand.Knowledge do
  @moduledoc """
  API pública da base de conhecimento.

  Nada fora de `TheBand.Knowledge.*` alcança `TokenGate`, `Loader` ou `Manifest` direto — é o padrão
  que `CLAUDE.md` exige de todo módulo, e há teste que reprova o acesso externo.

  ## O que esta feature entrega, e o que não

  Entrega: o manifesto, os nove esquemas, o portão de tokens, o carregador, `mix knowledge.validate`
  e a tela que mostra a base. **Não** entrega validação de campo por esquema, vocabulários fechados
  nem reciprocidade entre conceito e relação — isso é a issue #22.

  A distinção importa porque `inspect_base/1` **não** afirma que o conteúdo está semanticamente
  correto. Ela afirma que cada arquivo é um documento YAML íntegro, sem âncora, sem chave duplicada,
  sem tabulação na indentação, com um único documento na raiz, e que o manifesto é válido.

  Dizer mais do que isso seria a mentira que esta feature inteira existe para evitar.
  """

  alias TheBand.Knowledge.{Loader, Manifest, Schema, TokenGate, Validator}

  @padrao "priv/knowledge_base"

  @typedoc "Relatório de uma inspeção da base."
  @type relatorio :: %{
          base: Path.t(),
          manifest: Manifest.t() | nil,
          schemas: [%{id: String.t(), path: String.t(), describes: String.t()}],
          arquivos_inspecionados: non_neg_integer(),
          ignorados: [String.t()],
          violacoes: [TokenGate.Violation.t()]
        }

  @doc "Diretório da base. Configurável para os testes usarem base temporária."
  @spec base_dir() :: Path.t()
  def base_dir do
    Application.get_env(:the_band, :knowledge_base_dir) || Application.app_dir(:the_band, @padrao)
  end

  @doc """
  Inspeciona uma base inteira e devolve o relatório.

  Devolve `{:ok, relatorio}` quando não há violação, `{:error, relatorio}` quando há. **Nos dois
  casos o relatório vem completo** — quem chama precisa da contagem mesmo quando reprova, e um erro
  que descarta o que foi apurado obriga a rodar de novo para saber o tamanho do problema.
  """
  @spec inspect_base(Path.t() | nil) :: {:ok, relatorio()} | {:error, relatorio()}
  def inspect_base(base \\ nil) do
    base = base || base_dir()

    {estado_do_portao, portao} = TokenGate.inspect_dir(base)

    {manifesto, violacoes_do_manifesto} =
      case Manifest.load(base) do
        {:ok, m} -> {m, []}
        {:error, v} -> {nil, v}
      end

    {esquemas_carregados, violacoes_de_esquema} = Schema.load_all(base)

    # A validação estrita só roda com manifesto e esquemas em pé. Sem eles não há contra o que
    # validar, e reportar "nenhuma violação de campo" seria afirmar cobertura que não houve.
    violacoes_de_campo =
      if not is_nil(manifesto) and esquemas_carregados != %{} and portao.violacoes == [],
        do: validar_conteudo(base, esquemas_carregados, manifesto),
        else: []

    todas =
      portao.violacoes ++ violacoes_do_manifesto ++ violacoes_de_esquema ++ violacoes_de_campo

    relatorio = %{
      base: base,
      manifest: manifesto,
      schemas: esquemas(base),
      arquivos_inspecionados: portao.inspecionados,
      ignorados: portao.ignorados,
      violacoes: ordenar(todas)
    }

    if estado_do_portao == :ok and todas == [] do
      {:ok, relatorio}
    else
      {:error, relatorio}
    end
  end

  @doc """
  Carrega um arquivo da base pelo caminho relativo.
  """
  @spec load(Path.t(), Path.t() | nil) ::
          {:ok, map()} | {:error, [TokenGate.Violation.t()]}
  def load(relativo, base \\ nil) do
    base = base || base_dir()
    Loader.load_file(Path.join(base, relativo), base_dir: base, label: relativo)
  end

  @doc """
  Os nove tipos de arquivo de conhecimento que a base precisa saber validar.

  Existe para que a ausência de um esquema seja detectável. Contar arquivos **não** fecha esse
  caminho: um esquema que falta faz os arquivos daquele tipo serem pulados enquanto a contagem
  permanece maior que zero, e a validação aprova. É a falha da feature 001 transposta (FR-089).
  """
  @spec tipos_exigidos() :: [String.t()]
  def tipos_exigidos do
    ~w(ontology concept relation mapping competency-question information-need
       measurement glossary connector-definition)
  end

  @doc """
  Quais dos nove esquemas estão ausentes da base.
  """
  @spec esquemas_ausentes(Path.t() | nil) :: [String.t()]
  def esquemas_ausentes(base \\ nil) do
    base = base || base_dir()
    presentes = esquemas(base) |> Enum.map(& &1.id)
    tipos_exigidos() -- presentes
  end

  # Os arquivos de esquema NÃO passam pela validação de campo: eles descrevem os tipos, e validá-los
  # contra si mesmos seria recursivo. A integridade deles é garantida por `Schema.load_all/1`, que
  # reprova quando um não carrega — e um esquema que não carrega faz os arquivos daquele tipo serem
  # pulados em silêncio (FR-089).
  defp validar_conteudo(base, esquemas, manifesto) do
    base
    |> Path.join("**/*.{yaml,yml}")
    |> Path.wildcard()
    |> Enum.reject(&(String.contains?(&1, "/schemas/") or Path.basename(&1) == "manifest.yaml"))
    |> Enum.sort()
    |> Enum.flat_map(fn caminho ->
      rel = Path.relative_to(caminho, base)

      case Loader.load_file(caminho, base_dir: base, label: rel) do
        {:ok, doc} -> Validator.validate(doc, rel, esquemas, manifesto)
        {:error, v} -> v
      end
    end)
  end

  defp esquemas(base) do
    base
    |> Path.join("schemas/*.schema.yaml")
    |> Path.wildcard()
    |> Enum.sort()
    |> Enum.map(fn caminho ->
      rel = Path.relative_to(caminho, base)

      case Loader.load_file(caminho, base_dir: base, label: rel) do
        {:ok, %{"schema" => s}} when is_map(s) ->
          %{
            id: to_string(s["id"] || ""),
            path: rel,
            describes: to_string(s["describes"] || ""),
            ok: true
          }

        _ ->
          %{id: "", path: rel, describes: "", ok: false}
      end
    end)
  end

  defp ordenar(violacoes) do
    Enum.sort_by(violacoes, &{&1.path, &1.line || 0, &1.column || 0, Atom.to_string(&1.kind)})
  end
end
