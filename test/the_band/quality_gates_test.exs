defmodule TheBand.QualityGatesTest do
  @moduledoc """
  Protege o alias `mix gates` contra a regressão da issue #29.

  ## O defeito que este teste impede

  `mix gates` termina em `test`, e `mix test` **se recusa a rodar fora do ambiente `:test`**. Sem
  `gates` em `preferred_envs`, o alias executava quatro portões, morria no quinto com
  `** (Mix) "mix test" is running in the "dev" environment` e saía com código 1 — enquanto
  `CLAUDE.md` e `README.md` o documentavam como o comando que roda os cinco na ordem exigida pela
  constituição.

  ## Por que aqui um teste sobre configuração é o certo

  Este projeto trata leitura de configuração como **não-evidência**: a especificação da feature 002
  exige provar o bloqueio de incorporação por tentativa real, não lendo a proteção da linha
  principal. A regra continua valendo.

  A diferença é que aqui a configuração **é** o defeito. A omissão de uma entrada em
  `preferred_envs` foi a causa, e afirmar a presença dela é afirmar exatamente o que quebrou. A
  evidência de que a correção funciona é outra coisa, e vive no Pull Request: `mix gates` executado,
  código de saída 0, com a contagem de testes na saída.

  Este teste impede a **regressão**. Ele não prova a correção.
  """

  use ExUnit.Case, async: true

  @config Mix.Project.config()

  # `preferred_envs` vem do callback `cli/0`, NÃO de `project/0`. `Mix.Project.config()[:cli]` é
  # `nil` — verificado, e foi o primeiro defeito deste próprio teste.
  @preferidos Mix.Project.get().cli()[:preferred_envs] || []

  # A ordem que a constituição exige, na seção Quality Gates. A ordem não é cosmética: `mix credo`
  # não compila o projeto antes de rodar, e sem a compilação as checagens próprias sob
  # `credo_checks/` não carregam — o Credo imprime "Ignoring an undefined check" e sai com código 0.
  @ordem_constitucional [
    "format --check-formatted",
    "compile --warnings-as-errors",
    "credo --strict",
    "dialyzer",
    "test"
  ]

  describe "o alias gates" do
    test "existe" do
      assert Keyword.has_key?(@config[:aliases], :gates),
             "o alias `gates` desapareceu do mix.exs; CLAUDE.md e README.md o documentam"
    end

    test "roda os cinco portões na ordem que a constituição exige" do
      assert @config[:aliases][:gates] == @ordem_constitucional, """
      A composição ou a ordem do alias `gates` mudou.

      Esperado: #{inspect(@ordem_constitucional)}
      Recebido: #{inspect(@config[:aliases][:gates])}

      A ordem não é preferência de estilo. `mix credo` não compila o projeto antes de rodar, e sem a
      compilação as checagens próprias do projeto não carregam: o Credo imprime
      "Ignoring an undefined check" e sai com código 0 — um portão que aprova sem ter verificado.
      """
    end
  end

  describe "ambiente preferido — a causa da issue #29" do
    test "gates roda no ambiente de teste" do
      assert @preferidos[:gates] == :test, """
      `gates` não está em `preferred_envs` com `:test`.

      Recebido: #{inspect(@preferidos)}

      Consequência exata, medida na issue #29: o alias executa os quatro primeiros portões, morre no
      quinto com

          ** (Mix) "mix test" is running in the "dev" environment

      e sai com código 1. `mix test` NUNCA roda. E `CLAUDE.md` e `README.md` documentam `mix gates`
      como o comando que roda os cinco portões.
      """
    end

    test "todo alias que termina em test roda no ambiente de teste" do
      # Generaliza a correção em vez de consertar só o caso conhecido. Qualquer alias futuro que
      # termine em `test` cai na mesma armadilha, e a armadilha é silenciosa para quem escreve o
      # alias: ela só aparece na execução.
      #
      # `:test` é a exceção legítima, e este teste a descobriu por conta própria ao acusá-la: o Mix
      # já coloca `mix test` no ambiente `:test` por padrão, então o alias homônimo não precisa de
      # entrada em `preferred_envs`. Sem esta ressalva, o teste reprovaria configuração correta.
      culpados =
        for {nome, passos} <- @config[:aliases],
            nome != :test,
            is_list(passos),
            List.last(passos) == "test",
            @preferidos[nome] != :test,
            do: nome

      assert culpados == [], """
      Estes aliases terminam em `test` e não declaram `:test` como ambiente preferido: #{inspect(culpados)}

      Cada um vai falhar em execução do mesmo modo que a issue #29. Acrescente-os a
      `preferred_envs` no `mix.exs`.
      """
    end
  end
end
