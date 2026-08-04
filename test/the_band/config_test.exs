defmodule TheBand.ConfigTest do
  @moduledoc """
  FR-007 — variável de ambiente obrigatória ausente falha nomeando a variável.

  O que estes testes protegem: que a plataforma nunca suba com configuração que ninguém
  escolheu. Um padrão silencioso em produção é pior que uma falha, porque a falha é
  visível e o padrão não.
  """

  use ExUnit.Case, async: false

  alias TheBand.Config
  alias TheBand.Config.InvalidEnvError
  alias TheBand.Config.MissingEnvError

  @var "THE_BAND_TEST_CONFIG_VAR"

  setup do
    System.delete_env(@var)
    on_exit(fn -> System.delete_env(@var) end)
  end

  describe "require_env!/2" do
    test "devolve o valor quando a variável está definida" do
      System.put_env(@var, "valor-definido")

      assert Config.require_env!(@var) == "VALOR-DELIBERADAMENTE-ERRADO-PARA-PROVAR-O-PORTAO"
    end

    test "levanta NOMEANDO a variável quando está ausente" do
      erro = assert_raise MissingEnvError, fn -> Config.require_env!(@var) end

      assert erro.message =~ @var,
             "a mensagem precisa nomear a variável, senão quem opera não sabe o que definir"

      assert erro.message =~ "ausente"
    end

    test "levanta NOMEANDO a variável quando está definida mas vazia" do
      System.put_env(@var, "")

      erro = assert_raise MissingEnvError, fn -> Config.require_env!(@var) end

      assert erro.message =~ @var
      assert erro.message =~ "vazia"
    end

    test "inclui a dica na mensagem quando fornecida" do
      erro =
        assert_raise MissingEnvError, fn ->
          Config.require_env!(@var, hint: "Gere um valor com: mix phx.gen.secret")
        end

      assert erro.message =~ "mix phx.gen.secret"
    end

    test "nunca devolve valor padrão" do
      # Não existe cláusula de `require_env!/2` que aceite padrão. Se alguém adicionar uma,
      # este teste deixa de compilar ou de passar, e a discussão volta à revisão.
      refute function_exported?(Config, :require_env, 2)
    end
  end

  describe "get_env/2" do
    test "devolve o valor quando definido" do
      System.put_env(@var, "definido")

      assert Config.get_env(@var, "padrao") == "definido"
    end

    test "devolve o padrão quando ausente" do
      assert Config.get_env(@var, "padrao") == "padrao"
    end

    test "devolve o padrão quando vazio, em vez de string vazia" do
      System.put_env(@var, "")

      assert Config.get_env(@var, "padrao") == "padrao"
    end
  end

  describe "get_env_integer/2" do
    test "converte valor válido" do
      System.put_env(@var, "4001")

      assert Config.get_env_integer(@var, 4000) == 4001
    end

    test "devolve o padrão quando ausente ou vazio" do
      assert Config.get_env_integer(@var, 4000) == 4000

      System.put_env(@var, "")
      assert Config.get_env_integer(@var, 4000) == 4000
    end

    test "levanta InvalidEnvError, nao MissingEnvError, quando o valor e invalido" do
      # A distincao importa para quem opera: "ausente" e "presente com valor errado" pedem
      # correcoes diferentes.
      System.put_env(@var, "quatro-mil")

      erro = assert_raise InvalidEnvError, fn -> Config.get_env_integer(@var, 4000) end

      assert erro.message =~ @var
      assert erro.message =~ "inteiro"
    end

    test "levanta em valor parcialmente numérico, em vez de aceitar o prefixo" do
      # `Integer.parse("4000abc")` devolve `{4000, "abc"}`. Aceitar isso faria a plataforma
      # escutar numa porta que ninguém pediu.
      System.put_env(@var, "4000abc")

      assert_raise InvalidEnvError, fn -> Config.get_env_integer(@var, 4000) end
    end
  end
end
