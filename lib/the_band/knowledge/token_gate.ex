defmodule TheBand.Knowledge.TokenGate do
  @moduledoc """
  Primeira passagem da validação: recusa arquivo **antes de qualquer termo ser construído**.

  ## Por que isto existe, e por que não é otimização

  Interpretar YAML tem duas etapas — tokenizar e construir o termo. Este módulo lê a primeira e
  recusa antes da segunda acontecer. Há duas razões, e as duas são medidas.

  **Razão 1: depois da construção, a informação já não existe.**

      "a: 1\\na: 2"      -> %{"a" => 1}              perdeu-se que havia chave duplicada
      "a:\\n\\tb: 1"      -> %{"a" => nil, "b" => 1}   perdeu-se que `b` deveria estar DENTRO de `a`

  Olhando `%{"a" => 1}` é impossível saber que o arquivo tinha `a` duas vezes. O interpretador já
  escolheu uma e descartou a outra. E `yaml_elixir` mantém a **primeira** enquanto `yamerl` mantém a
  **última** — o mesmo documento produz dados diferentes conforme a camada (research.md R4).

  **Razão 2: a bomba explode durante a construção.**

      588 bytes -> termo de 101.348.108 palavras (~800 MB) em 786 ms
      814 bytes -> NÃO TERMINA em 15 segundos, processo morto

  Apelidos aninhados em estilo de bloco. Nenhuma biblioteca de YAML oferece limite de nós, de
  profundidade ou de fator de expansão (research.md R6). Verificar depois da construção é verificar
  depois do estrago. Este repositório é público e aceita propostas de mudança: sem este portão, 814
  bytes derrubam a verificação obrigatória de status.

  ## Detecção por token, nunca por expressão regular

  Medido em R10: `t: "& e * dentro de texto"` produz **zero** token de âncora, enquanto `a: &x 1`
  produz `:yamerl_anchor` e `:yamerl_alias`. Uma varredura textual acusaria o primeiro caso e
  travaria conteúdo legítimo.

  Os registros de token vêm de `Record.extract/2` sobre o cabeçalho do próprio `yamerl`. Isso é
  deliberado: se uma atualização mudar a forma dos registros, a **compilação quebra**, em vez de
  este módulo indexar tuplas erradas em silêncio. O portão nunca pode degradar para "não detectei
  nada" com código de saída zero — é a classe de defeito que a feature 001 encontrou na análise
  estática.

  ## O que este portão NÃO faz

  Não valida esquema, não olha conteúdo semântico, não constrói termo. Ele só decide se o arquivo
  pode chegar à segunda passagem.
  """

  require Record

  alias TheBand.Knowledge.TokenGate.Violation

  @hrl [from_lib: "yamerl/include/yamerl_tokens.hrl"]

  Record.defrecordp(:tk_anchor, :yamerl_anchor, Record.extract(:yamerl_anchor, @hrl))
  Record.defrecordp(:tk_alias, :yamerl_alias, Record.extract(:yamerl_alias, @hrl))
  Record.defrecordp(:tk_scalar, :yamerl_scalar, Record.extract(:yamerl_scalar, @hrl))
  Record.defrecordp(:tk_map_key, :yamerl_mapping_key, Record.extract(:yamerl_mapping_key, @hrl))
  Record.defrecordp(:tk_doc_start, :yamerl_doc_start, Record.extract(:yamerl_doc_start, @hrl))

  Record.defrecordp(
    :tk_coll_start,
    :yamerl_collection_start,
    Record.extract(:yamerl_collection_start, @hrl)
  )

  Record.defrecordp(
    :tk_coll_end,
    :yamerl_collection_end,
    Record.extract(:yamerl_collection_end, @hrl)
  )

  @doc """
  Tipos de token de que este portão depende. Existe para o teste que reprova quando um deles
  desaparece de `yamerl` — ver `TheBand.Knowledge.TokenGateContractTest`.
  """
  @spec tipos_de_token_exigidos() :: [atom()]
  def tipos_de_token_exigidos do
    [
      :yamerl_anchor,
      :yamerl_alias,
      :yamerl_scalar,
      :yamerl_mapping_key,
      :yamerl_collection_start,
      :yamerl_collection_end,
      :yamerl_doc_start
    ]
  end

  # FR-092. Derivados de R11: o arquivo realista de conceito tem 766 bytes e leva 0,27 ms. 256 KiB é
  # cerca de 340 vezes o tamanho, e 2 s cerca de 7.400 vezes o tempo, do conteúdo legítimo.
  @max_bytes 256 * 1024
  @timeout_ms 2_000

  @spec max_bytes() :: pos_integer()
  def max_bytes, do: @max_bytes

  @spec timeout_ms() :: pos_integer()
  def timeout_ms, do: @timeout_ms

  @doc """
  Inspeciona um arquivo do disco.

  Recusa ligação simbólica que aponte para fora de `base_dir`, quando `base_dir` é informado.
  """
  @spec inspect_file(Path.t(), keyword()) :: :ok | {:error, [Violation.t()]}
  def inspect_file(path, opts \\ []) do
    rotulo = Keyword.get(opts, :label, path)

    with :ok <- verificar_ligacao_simbolica(path, rotulo, opts),
         {:ok, bytes} <- ler(path, rotulo) do
      inspect_source(bytes, rotulo)
    end
  end

  @doc """
  Inspeciona o conteúdo bruto de um arquivo. `path` só serve para as mensagens.

  Devolve `:ok`, ou `{:error, violacoes}` com **todas** as violações encontradas — FR-015 proíbe
  parar na primeira, porque parar transforma uma correção em muitas rodadas.
  """
  @spec inspect_source(binary(), Path.t()) :: :ok | {:error, [Violation.t()]}
  def inspect_source(bytes, path) when is_binary(bytes) do
    # A ordem importa. Tamanho e codificação são baratos e independentes; rodam primeiro para que um
    # arquivo absurdo nunca chegue ao tokenizador. Se a codificação é inválida, tokenizar não faz
    # sentido, então este caso interrompe.
    with :ok <- verificar_tamanho(bytes, path),
         :ok <- verificar_codificacao(bytes, path) do
      # Tabulação na indentação é verificada no texto bruto de propósito: o tokenizador de `yamerl`
      # aceita e o construtor achata a estrutura em silêncio (R7), então o token não carrega a
      # informação.
      violacoes_de_texto = tabulacoes_na_indentacao(bytes, path)
      violacoes_de_token = inspecionar_tokens(bytes, path)

      case violacoes_de_texto ++ violacoes_de_token do
        [] -> :ok
        v -> {:error, ordenar(v)}
      end
    end
  end

  @doc """
  Inspeciona todos os arquivos YAML de um diretório, recursivamente.

  Devolve `{:ok, relatorio}` ou `{:error, relatorio}`. O relatório **sempre** informa quantos
  arquivos foram inspecionados e quantos foram ignorados — FR-013 e FR-016.

  Arquivo cujo nome começa por ponto é ignorado, e a contagem é relatada. Exclusão que não é contada
  é indistinguível de arquivo que não foi encontrado, e "não encontrei nada" com aprovação é a classe
  de defeito que a feature 001 encontrou na análise estática.
  """
  @spec inspect_dir(Path.t()) ::
          {:ok | :error,
           %{inspecionados: non_neg_integer(), ignorados: [Path.t()], violacoes: [Violation.t()]}}
  def inspect_dir(base) do
    {candidatos, ignorados} = varrer(base)

    violacoes =
      candidatos
      |> Enum.sort()
      |> Enum.flat_map(fn caminho ->
        case inspect_file(caminho, base_dir: base, label: Path.relative_to(caminho, base)) do
          :ok -> []
          {:error, v} -> v
        end
      end)

    relatorio = %{
      inspecionados: length(candidatos),
      ignorados: Enum.sort(ignorados),
      violacoes: violacoes
    }

    if violacoes == [], do: {:ok, relatorio}, else: {:error, relatorio}
  end

  defp varrer(base) do
    base
    |> Path.join("**/*")
    |> Path.wildcard(match_dot: true)
    |> Enum.reject(&File.dir?/1)
    |> Enum.split_with(fn caminho ->
      not oculto?(caminho, base) and Path.extname(caminho) in [".yaml", ".yml"]
    end)
    |> then(fn {yamls, resto} ->
      {yamls, Enum.map(resto, &Path.relative_to(&1, base))}
    end)
  end

  # Qualquer segmento do caminho relativo à base começando por ponto torna o arquivo oculto. Cobre
  # `.DS_Store` e também `.git/config` se alguém apontar a base para o lugar errado.
  defp oculto?(caminho, base) do
    caminho
    |> Path.relative_to(base)
    |> Path.split()
    |> Enum.any?(&String.starts_with?(&1, "."))
  end

  # ── tamanho, codificação, ligação simbólica ──────────────────────────────────────────────────

  defp verificar_tamanho(bytes, path) do
    tamanho = byte_size(bytes)

    if tamanho > @max_bytes do
      {:error,
       [
         v(
           :too_large,
           path,
           nil,
           nil,
           "arquivo com #{tamanho} bytes excede o limite de #{@max_bytes} bytes " <>
             "(#{div(@max_bytes, 1024)} KiB). O maior arquivo de conhecimento plausível tem menos " <>
             "de 1 KiB — ver research.md R11"
         )
       ]}
    else
      :ok
    end
  end

  defp verificar_codificacao(bytes, path) do
    # A marca de ordem de bytes é tolerada: é formatação e não muda significado (FR-072).
    sem_bom = descartar_bom(bytes)

    if String.valid?(sem_bom) do
      :ok
    else
      {:error,
       [
         v(
           :invalid_encoding,
           path,
           nil,
           nil,
           "arquivo contém byte que não é UTF-8 válido. A posição não é reportada porque a " <>
             "biblioteca não a fornece para esta classe de erro — ver research.md R9"
         )
       ]}
    end
  end

  defp verificar_ligacao_simbolica(path, rotulo, opts) do
    base = Keyword.get(opts, :base_dir)

    cond do
      is_nil(base) ->
        :ok

      not match?({:ok, %File.Stat{type: :symlink}}, File.lstat(path)) ->
        :ok

      true ->
        alvo = path |> File.read_link!() |> Path.expand(Path.dirname(path))

        if String.starts_with?(alvo, Path.expand(base) <> "/") do
          :ok
        else
          {:error,
           [
             v(
               :symlink_outside_base,
               rotulo,
               nil,
               nil,
               "ligação simbólica aponta para fora da base de conhecimento"
             )
           ]}
        end
    end
  end

  defp descartar_bom(<<0xEF, 0xBB, 0xBF, resto::binary>>), do: resto
  defp descartar_bom(bytes), do: bytes

  # ── tabulação na indentação ─────────────────────────────────────────────────────────────────

  # Regra deliberadamente simples: se a indentação de uma linha contém tabulação, recusa.
  #
  # Limitação registrada: isto também recusa tabulação na indentação do conteúdo de um escalar de
  # bloco. É aceitável — a especificação YAML proíbe tabulação para indentação em qualquer lugar, e
  # o conteúdo desta base nunca precisa dela. Tabulação DENTRO do texto de uma linha, depois do
  # primeiro caractere que não é espaço, passa.
  defp tabulacoes_na_indentacao(bytes, path) do
    bytes
    |> descartar_bom()
    |> String.split(["\r\n", "\n"])
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {linha, n} ->
      indentacao = linha |> String.graphemes() |> Enum.take_while(&(&1 in [" ", "\t"]))

      case Enum.find_index(indentacao, &(&1 == "\t")) do
        nil ->
          []

        idx ->
          [
            v(
              :tab_indentation,
              path,
              n,
              idx + 1,
              "tabulação na indentação. A especificação YAML a proíbe, e as bibliotecas a aceitam " <>
                "reestruturando o documento em silêncio: \"a:\\n\\tb: 1\" produz `b` como IRMÃO de " <>
                "`a`, não como filho — ver research.md R7. Use espaços"
            )
          ]
      end
    end)
  end

  # ── fluxo de tokens ─────────────────────────────────────────────────────────────────────────

  # Roda num processo próprio por dois motivos: o limite de tempo de FR-092 exige poder matar o
  # trabalho, e os tokens chegam por mensagem — num processo dedicado eles não se misturam com a
  # caixa de mensagens de quem chamou.
  defp inspecionar_tokens(bytes, path) do
    pai = self()
    ref = make_ref()

    {pid, monitor} =
      spawn_monitor(fn ->
        send(pai, {ref, coletar_e_analisar(bytes, path)})
      end)

    receive do
      {^ref, resultado} ->
        Process.demonitor(monitor, [:flush])
        resultado

      {:DOWN, ^monitor, :process, _, motivo} ->
        [
          v(
            :syntax,
            path,
            nil,
            nil,
            "o interpretador de YAML encerrou de forma anormal: #{inspect(motivo)}"
          )
        ]
    after
      @timeout_ms ->
        Process.exit(pid, :kill)

        [
          v(
            :too_slow,
            path,
            nil,
            nil,
            "o processamento excedeu #{@timeout_ms} ms. Arquivo que faz a verificação girar sem " <>
              "terminar bloqueia a verificação obrigatória tanto quanto um que esgota memória"
          )
        ]
    end
  end

  defp coletar_e_analisar(bytes, path) do
    eu = self()
    marca = make_ref()
    fun = fn token -> send(eu, {marca, token}) && :ok end

    resultado_do_parser =
      try do
        :yamerl_parser.string(bytes, [{:token_fun, fun}])
        :ok
      catch
        :throw, {:yamerl_exception, erros} -> {:erro_de_sintaxe, erros}
      end

    tokens = drenar(marca, [])

    case resultado_do_parser do
      :ok -> analisar(tokens, path)
      {:erro_de_sintaxe, erros} -> [violacao_de_sintaxe(erros, path)]
    end
  end

  defp drenar(marca, acc) do
    receive do
      {^marca, token} -> drenar(marca, [token | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  # ── análise do fluxo ────────────────────────────────────────────────────────────────────────

  defp analisar(tokens, path) do
    estado = %{
      violacoes: [],
      # pilha de mapeamentos abertos, cada um com as chaves já vistas
      pilha: [],
      # o próximo escalar é uma chave de mapeamento?
      esperando_chave?: false,
      documentos: 0
    }

    final = Enum.reduce(tokens, estado, &passo(&1, &2, path))

    documentos = final.documentos

    extra =
      cond do
        documentos == 0 ->
          [
            v(
              :empty_document,
              path,
              nil,
              nil,
              "arquivo sem documento algum: vazio, apenas comentários, ou apenas o separador. " <>
                "Todo arquivo da base declara exatamente um documento"
            )
          ]

        documentos > 1 ->
          [
            v(
              :multiple_documents,
              path,
              nil,
              nil,
              "arquivo com #{documentos} documentos. Cada arquivo da base contém exatamente um. " <>
                "`read_from_string/2` devolveria apenas o último, descartando os anteriores em " <>
                "silêncio — ver research.md R8"
            )
          ]

        true ->
          []
      end

    Enum.reverse(final.violacoes) ++ extra
  end

  defp passo(tk_anchor(line: l, column: c), estado, path) do
    acrescentar(
      estado,
      v(
        :anchor,
        path,
        l,
        c,
        "âncora não é permitida na base de conhecimento. Um arquivo de 814 bytes de apelidos " <>
          "aninhados não termina em 15 segundos e mata o processo, e nenhuma biblioteca de YAML " <>
          "oferece limite de nós — ver research.md R6 e ADR-0005"
      )
    )
  end

  defp passo(tk_alias(line: l, column: c), estado, path) do
    acrescentar(
      estado,
      v(
        :alias,
        path,
        l,
        c,
        "apelido não é permitido na base de conhecimento. Além do risco de expansão descontrolada, " <>
          "âncora sobre coleção em estilo de fluxo produz dado ERRADO em silêncio — ver " <>
          "research.md R5"
      )
    )
  end

  defp passo(tk_doc_start(), estado, _path) do
    %{estado | documentos: estado.documentos + 1}
  end

  defp passo(tk_coll_start(), estado, _path) do
    %{estado | pilha: [%{} | estado.pilha], esperando_chave?: false}
  end

  defp passo(tk_coll_end(), estado, _path) do
    %{estado | pilha: tl_seguro(estado.pilha), esperando_chave?: false}
  end

  defp passo(tk_map_key(), estado, _path), do: %{estado | esperando_chave?: true}

  defp passo(tk_scalar(line: l, column: c, text: texto), %{esperando_chave?: true} = estado, path) do
    chave = to_string(texto)

    case estado.pilha do
      [atual | resto] ->
        case Map.fetch(atual, chave) do
          {:ok, {l0, c0}} ->
            estado
            |> acrescentar(
              v(
                :duplicate_key,
                path,
                l,
                c,
                "chave \"#{chave}\" declarada duas vezes no mesmo mapeamento; a primeira está em " <>
                  "#{l0}:#{c0}. As bibliotecas aceitam em silêncio e DISCORDAM entre si sobre qual " <>
                  "vence — ver research.md R4"
              )
            )
            |> Map.put(:esperando_chave?, false)

          :error ->
            %{estado | pilha: [Map.put(atual, chave, {l, c}) | resto], esperando_chave?: false}
        end

      [] ->
        %{estado | esperando_chave?: false}
    end
  end

  defp passo(_token, estado, _path), do: %{estado | esperando_chave?: false}

  defp tl_seguro([]), do: []
  defp tl_seguro([_ | resto]), do: resto

  defp acrescentar(estado, violacao), do: %{estado | violacoes: [violacao | estado.violacoes]}

  # ── erro de sintaxe ─────────────────────────────────────────────────────────────────────────

  defp violacao_de_sintaxe(erros, path) do
    {linha, coluna, texto} =
      Enum.find_value(erros, {nil, nil, "documento YAML inválido"}, fn
        {_, :error, msg, l, c, _, _, _} when is_integer(l) -> {l, c, to_string(msg)}
        _ -> nil
      end)

    v(:syntax, path, linha, coluna, "documento YAML inválido: #{texto}")
  end

  # ── auxiliares ──────────────────────────────────────────────────────────────────────────────

  defp ler(path, rotulo) do
    case File.read(path) do
      {:ok, bytes} ->
        {:ok, bytes}

      {:error, motivo} ->
        {:error,
         [
           v(
             :syntax,
             rotulo,
             nil,
             nil,
             "não foi possível ler o arquivo: #{:file.format_error(motivo)}"
           )
         ]}
    end
  end

  defp v(kind, path, line, column, message) do
    %Violation{kind: kind, path: path, line: line, column: column, message: message}
  end

  # Ordem estável para que a evidência de duas execuções seja comparável — FR-091.
  defp ordenar(violacoes) do
    Enum.sort_by(violacoes, &{&1.line || 0, &1.column || 0, Atom.to_string(&1.kind)})
  end
end
