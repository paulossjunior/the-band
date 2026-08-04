defmodule TheBand.CredoCheckTest do
  @moduledoc """
  Guarda da checagem que impõe SC-002 (T054, T056).

  ## O problema que estes testes existem para impedir

  Quando o Credo não consegue carregar uma checagem declarada em `.credo.exs`, ele imprime
  `Ignoring an undefined check` e **sai com código zero**. Verificado. O portão passa, e SC-002
  deixa de ser verificado sem nada falhar — pior que a ausência da checagem, porque parece
  cumprido.

  As duas causas dessa falha são: o diretório `credo_checks/` deixar de casar com o glob de
  `requires:`, e o nome do módulo divergir do declarado em `checks.enabled`. É exatamente isso
  que os testes abaixo verificam.

  ## Por que a verificação é textual

  O módulo da checagem **não** é compilado na aplicação: ele vive fora de `elixirc_paths` de
  propósito, porque usa `Credo.Check`, e `credo` é `only: [:dev, :test]` — um módulo em `lib/`
  que o use quebraria `MIX_ENV=prod`. O Credo o carrega do código-fonte por conta própria.

  Consequência: um teste não pode referenciar o módulo. Estes testes leem os arquivos, o que é
  fraco como técnica mas cobre precisamente as duas causas do no-op silencioso.

  A verificação de **comportamento** é feita no fluxo de verificação automática, que reprova
  quando a saída do Credo contém `Ignoring an undefined check`. As duas camadas juntas fecham o
  problema; nenhuma sozinha fecha.
  """

  use ExUnit.Case, async: true

  @check_file "credo_checks/no_direct_repo_access.ex"
  @check_module "TheBand.Credo.Check.NoDirectRepoAccess"
  @config ".credo.exs"

  describe "a checagem é carregável pelo Credo" do
    test "o arquivo existe no lugar declarado" do
      assert File.exists?(@check_file), """
      #{@check_file} não existe.

      Se foi movido, o glob de `requires:` em #{@config} deixou de casar, e o Credo passa a
      ignorar a checagem SILENCIOSAMENTE, saindo com código zero.
      """
    end

    test ".credo.exs declara requires apontando para o diretório da checagem" do
      config = File.read!(@config)

      assert config =~ ~s(requires: ["./credo_checks/**/*.ex"]), """
      `requires:` não aponta para credo_checks/.

      Sem isso o módulo da checagem não é carregado, e o Credo ignora a checagem declarada
      saindo com código zero.
      """
    end

    test ".credo.exs habilita a checagem pelo nome exato do módulo" do
      config = File.read!(@config)
      fonte = File.read!(@check_file)

      assert config =~ @check_module, "#{@check_module} não está em checks.enabled"

      assert fonte =~ "defmodule #{@check_module} do", """
      O nome do módulo em #{@check_file} divergiu do declarado em #{@config}.

      Divergência aqui produz `Ignoring an undefined check` e código de saída zero: o portão
      passa e SC-002 deixa de ser verificado.
      """
    end

    test "a checagem está restrita a lib/" do
      config = File.read!(@config)

      assert config =~ ~s({TheBand.Credo.Check.NoDirectRepoAccess, files: %{included: ["lib/"]}}),
             """
             A restrição a `lib/` faz parte do desenho: testes chamam o repositório direto de
             propósito, e um teste que lê o banco para verificar isolamento está fazendo
             exatamente o certo.
             """
    end
  end

  describe "construção manual de escopo é reprovada" do
    test "a checagem cobre %TheBand.Tenancy.Scope{}" do
      fonte = File.read!(@check_file)

      assert fonte =~ "@scope_struct",
             """
             A regra que reprova construção manual de escopo desapareceu.

             `@opaque` é verificado por análise de tipos, não em execução: sem esta regra,
             qualquer módulo fabrica `%Scope{tenant_id: outro}` e lê dado de Tenant desativado,
             contornando FR-017. Apontado em revisão independente.
             """

      assert fonte =~ ~s("TheBand.Tenancy"),
             "TheBand.Tenancy precisa ser o único autorizado a construir escopo"
    end

    test "a limitação da regra está registrada" do
      fonte = File.read!("lib/the_band/tenancy/scope.ex")

      assert fonte =~ "O que é garantido, e o que NÃO é", """
      A seção que distingue o que o escopo garante do que não garante foi removida.

      Uma versão anterior afirmava que o escopo "não é construtível de fora" — falso. Afirmação
      de garantia inexistente é pior que ausência de documentação.
      """
    end
  end

  describe "a lista de módulos autorizados" do
    test "contém exatamente os módulos esperados" do
      fonte = File.read!(@check_file)

      esperados = [
        "TheBand.Tenancy.Queries",
        "TheBand.Tenancy.Commands",
        "TheBand.Audit.Queries",
        "TheBand.Audit.Commands",
        "TheBand.Health.SystemChecker"
      ]

      for modulo <- esperados do
        assert fonte =~ ~s("#{modulo}"), "#{modulo} saiu da lista de autorizados"
      end

      # Conta as entradas para pegar acréscimos, não só remoções. Ampliar a lista é decisão que
      # precisa aparecer no diff e ser justificada — não efeito colateral de outra mudança.
      [_, bloco] = String.split(fonte, "@authorized [", parts: 2)
      [bloco, _] = String.split(bloco, "]", parts: 2)
      quantidade = bloco |> String.split(~s(")) |> length() |> div(2)

      assert quantidade == length(esperados), """
      A lista de módulos autorizados tem #{quantidade} entradas, esperado #{length(esperados)}.

      Se um módulo novo precisa de acesso direto ao repositório, a decisão é legítima — mas
      precisa ser consciente. Atualize este teste junto, com o motivo no diff.
      """
    end

    test "migrações são autorizadas por prefixo" do
      fonte = File.read!(@check_file)

      assert fonte =~ ~s("TheBand.Repo.Migrations."),
             "migrações rodam fora de contexto de Tenant por natureza"
    end

    test "a limitação da checagem está registrada, não escondida" do
      fonte = File.read!(@check_file)

      assert fonte =~ "Limitação registrada", """
      A seção de limitações foi removida.

      A checagem não detecta `Ecto.Adapters.SQL.query(TheBand.Repo, ...)`, apelido renomeado nem
      `apply/3` com módulo em variável. Esconder isso daria falsa sensação de cobertura, que é
      pior que a cobertura parcial declarada.
      """
    end
  end
end
