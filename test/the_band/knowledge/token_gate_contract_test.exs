defmodule TheBand.Knowledge.TokenGateContractTest do
  @moduledoc """
  T016 — o portão nunca pode degradar para "não detectei nada".

  ## O risco que este teste cobre

  `TheBand.Knowledge.TokenGate` depende de `:yamerl_parser` e dos registros de token de `yamerl`.
  **Nada disso é API pública de `yaml_elixir`** — é interface interna de uma dependência
  transitiva. Uma atualização pode mudar os nomes, a forma dos registros ou a existência da opção
  `token_fun`.

  O modo de falha que importa não é o portão quebrar: é o portão **continuar rodando e não detectar
  nada**, aprovando arquivos que deveria recusar. Foi exatamente a forma do defeito da feature 001 —
  `mix credo` sem compilar, checagem que não carrega, `Ignoring an undefined check`, código de saída
  0.

  `Record.extract/2` no módulo garante que uma mudança na **forma** dos registros quebre a
  compilação. Este teste cobre o resto: que os tipos ainda existam no fluxo, e que o fluxo ainda
  chegue.
  """

  use ExUnit.Case, async: true

  alias TheBand.Knowledge.TokenGate

  describe "o fluxo de tokens de yamerl" do
    test "a opção token_fun continua existindo e entregando tokens" do
      eu = self()
      marca = make_ref()

      :yamerl_parser.string("a: &x 1\nb: *x\nc:\n  d: 2\n", [
        {:token_fun, fn token -> send(eu, {marca, token}) && :ok end}
      ])

      tokens = drenar(marca, [])

      assert length(tokens) > 5, """
      O fluxo de tokens entregou #{length(tokens)} tokens para um documento com âncora, apelido e
      mapeamento aninhado. A opção `token_fun` de `:yamerl_parser` mudou de comportamento, e o portão
      de tokens está cego — ele aprovaria arquivos que deveria recusar.
      """
    end

    test "todos os tipos de token de que o portão depende aparecem no fluxo" do
      eu = self()
      marca = make_ref()

      # Um documento que exercita cada tipo da lista: âncora, apelido, escalar, chave de mapeamento,
      # início e fim de coleção, início de documento.
      fonte = "raiz: &a 1\nfilho: *a\nmapa:\n  interno: 2\n"

      :yamerl_parser.string(fonte, [
        {:token_fun, fn token -> send(eu, {marca, token}) && :ok end}
      ])

      presentes =
        drenar(marca, [])
        |> Enum.filter(&is_tuple/1)
        |> Enum.map(&elem(&1, 0))
        |> Enum.uniq()

      faltando = TokenGate.tipos_de_token_exigidos() -- presentes

      assert faltando == [], """
      Estes tipos de token desapareceram do fluxo de `yamerl`: #{inspect(faltando)}

      O portão de tokens depende deles para recusar âncora, apelido e chave duplicada. Sem eles ele
      **não detecta nada e aprova** — a forma exata do defeito que a feature 001 encontrou na análise
      estática, que saía com código de saída 0 sem ter verificado.

      Presentes no fluxo: #{inspect(presentes)}
      """
    end
  end

  describe "a garantia acaba onde o teste acaba" do
    test "o portão de fato recusa, e não apenas declara depender dos tokens" do
      # Uma lista de tipos exigidos que ninguém consulta seria decoração. Este caso liga a declaração
      # ao comportamento: se o portão parar de recusar, este teste reprova mesmo que a lista continue
      # correta.
      assert {:error, violacoes} = TokenGate.inspect_source("a: &x 1\nb: *x\n", "x.yaml")
      tipos = violacoes |> Enum.map(& &1.kind) |> Enum.uniq()
      assert :anchor in tipos
      assert :alias in tipos
    end
  end

  defp drenar(marca, acc) do
    receive do
      {^marca, token} -> drenar(marca, [token | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end
end
