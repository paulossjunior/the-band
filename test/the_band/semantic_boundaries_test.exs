defmodule TheBand.SemanticBoundariesTest do
  @moduledoc """
  Guarda contra fusão de conceitos (T042).

  ## Por que um teste, e não apenas documentação

  A constituição autoriza bloquear feature por risco semântico, e a fusão de conceitos é o único
  erro que ela trata assim. Documentação avisa; teste impede.

  O risco concreto: quando a ontologia EO chegar (feature 005), alguém pode olhar a tabela
  `tenants` e pensar "já temos organização". Não temos. Um Tenant é quem **contrata** esta
  instalação; `eo.organization` é a organização do mundo real **analisada**. Uma consultoria que
  analisa doze clientes é **um** Tenant e **doze** organizações.

  Fundir os dois destruiria a capacidade de responder "qual dos meus clientes tem pior cycle
  time?", porque a resposta exigiria cruzar Tenants — exatamente o que o isolamento proíbe.

  Estes testes falham se alguém começar a fundir, e falham cedo.
  """

  use TheBand.DataCase, async: true

  import TheBand.TenancyFixtures

  alias Ecto.Adapters.SQL
  alias TheBand.Audit.OperationalEvent
  alias TheBand.Repo
  alias TheBand.Tenancy.Tenant

  describe "Tenant não é eo.organization" do
    test "tenants não tem coluna de organização de domínio" do
      colunas = Tenant.__schema__(:fields)

      proibidas = [
        :organization_id,
        :organization,
        :org_id,
        :company_id,
        :customer_id,
        :organizational_unit_id
      ]

      for coluna <- proibidas do
        refute coluna in colunas, """
        `tenants` ganhou a coluna #{inspect(coluna)}.

        Se a intenção é referenciar a organização de domínio, ela pertence à ontologia EO
        (feature 005) e a relação é o inverso: `eo_organizations` tem `tenant_id`, porque um
        Tenant contém várias organizações.

        Ver ADR-0003.
        """
      end
    end

    test "tenants tem exatamente os campos previstos" do
      # Lista fechada de propósito. Um campo novo aqui é decisão de modelagem da fronteira de
      # isolamento, e merece aparecer no diff junto com a razão.
      assert Enum.sort(Tenant.__schema__(:fields)) ==
               Enum.sort([:id, :slug, :name, :active, :inserted_at, :updated_at])
    end

    test "tenants é a única tabela sem tenant_id" do
      refute :tenant_id in Tenant.__schema__(:fields),
             "a tabela de Tenants não pertence a si mesma"

      assert :tenant_id in OperationalEvent.__schema__(:fields),
             "toda outra entidade precisa pertencer a um Tenant (FR-012)"
    end
  end

  describe "evento operacional não é spo.performed_activity" do
    test "não referencia projeto, atividade nem processo" do
      colunas = OperationalEvent.__schema__(:fields)

      proibidas = [
        :project_id,
        :activity_id,
        :process_id,
        :performed_activity_id,
        :performed_process_id,
        :sprint_id,
        :user_story_id
      ]

      for coluna <- proibidas do
        refute coluna in colunas, """
        `operational_events` ganhou a coluna #{inspect(coluna)}.

        Evento operacional é registro de execução DESTA plataforma. Atividade e processo de
        software do domínio analisado são conceitos das ontologias SPO e SRO, e chegam nas
        features 006 e 013 em tabelas próprias.

        Ver ADR-0003.
        """
      end
    end

    test "tem exatamente os campos previstos" do
      assert Enum.sort(OperationalEvent.__schema__(:fields)) ==
               Enum.sort([:id, :tenant_id, :type, :correlation_id, :occurred_at, :metadata])
    end
  end

  describe "nenhuma ontologia foi implementada nesta feature" do
    test "não existe módulo sob TheBand.Ontology" do
      modulos =
        :code.all_available()
        |> Enum.map(fn {nome, _, _} -> to_string(nome) end)
        |> Enum.filter(&String.starts_with?(&1, "Elixir.TheBand.Ontology"))

      assert modulos == [], """
      Módulos ontológicos apareceram: #{inspect(modulos)}

      A feature 001 é a fundação e não implementa ontologia. UFO, SEON e Continuum chegam a
      partir da feature 003, depois da infraestrutura comum de ontologias.
      """
    end

    test "não existem diretórios de ontologia nem de base de conhecimento" do
      # A constituição proíbe criar pasta vazia antes de a feature justificar.
      refute File.dir?("lib/the_band/ontology"),
             "lib/the_band/ontology/ pertence às features 003 em diante"

      refute File.dir?("priv/knowledge_base"),
             "priv/knowledge_base/ pertence à feature 002"
    end

    test "nenhuma tabela usa prefixo de ontologia" do
      prefixos = ~w(eo_ spo_ sysswo_ rsro_ cmpo_ roost_ qapo_ osdef_ sro_ ciro_ cdro_)

      %{rows: rows} =
        SQL.query!(
          Repo,
          "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'",
          []
        )

      tabelas = List.flatten(rows)

      for tabela <- tabelas, prefixo <- prefixos do
        refute String.starts_with?(tabela, prefixo),
               "tabela #{tabela} usa prefixo de ontologia, mas nenhuma ontologia foi " <>
                 "implementada nesta feature"
      end
    end
  end

  describe "o vocabulário canônico é respeitado" do
    test "um Tenant pode ter nome igual a outro — não é identidade de organização" do
      # Se `name` fosse identidade de organização de domínio, unicidade faria sentido. Não é: é
      # rótulo humano do contratante, e dois contratantes podem se chamar igual.
      nome = "Prefeitura de Vitória"

      a = tenant_fixture(%{name: nome})
      b = tenant_fixture(%{name: nome})

      refute a.id == b.id
      assert a.name == b.name
    end
  end
end
