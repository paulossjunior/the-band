# ADR-0003 — Tenant não é Organização

- **Status**: aceita
- **Data**: 2026-08-04
- **Feature**: 001 — Fundação e governança
- **Requisitos**: FR-043, e a seção `Terminologia canônica` da especificação
- **Decide**: vocabulário e modelagem de dois conceitos que a mesma palavra designava

## Contexto

A feature 001 introduz a unidade de isolamento da instalação. A feature 005 introduz a ontologia
EO, que tem o conceito `eo.organization`.

A primeira versão da especificação chamava a unidade de isolamento de **"organização
atendida"**, e no corpo do texto abreviava para **"organização"**. Ao mesmo tempo, a rede de
ontologias reserva `eo.organization` para a organização do mundo real analisada.

Uma palavra, dois conceitos, e o mais estrutural do sistema. Isso não é imprecisão de redação: é
o começo de uma fusão de conceitos, que a constituição trata como o único erro capaz de bloquear
uma feature.

## Decisão

**São dois conceitos distintos, com termos distintos, em tabelas distintas.**

| Termo | O que é | Onde vive |
|---|---|---|
| **Tenant** | Unidade de isolamento da instalação. Quem **contrata** e opera este The Band | Feature 001. Tabela `tenants`, coluna `tenant_id` |
| **Organização** | Organização do mundo real cujo desenvolvimento de software é **analisado** — objeto social do domínio | Feature 005, ontologia EO. Tabela `eo_organizations` |

**Um Tenant contém várias Organizações.**

A palavra "organização" **não** é usada como sinônimo de Tenant em lugar algum — nem em código,
nem em especificação, nem em mensagem de commit, nem em revisão.

`eo_organizations` terá `tenant_id`. **Isso não é redundância**: `tenant_id` diz a qual
instalação a linha pertence; a identidade da organização de domínio é outra coisa.

## Por que fundir destruiria o produto

Exemplo concreto. A **Conecta Academy** contrata o The Band para analisar o desenvolvimento de
software de três clientes:

```text
Tenant = Conecta Academy                    ← 1 registro em `tenants`
  ├── eo.organization = Prefeitura de Vitória   ← 3 registros em `eo_organizations`
  ├── eo.organization = Banco X                    (todos com o mesmo tenant_id)
  └── eo.organization = Startup Y
```

Cada conceito responde uma pergunta diferente:

- **Tenant**: de quem é esta instalação? Quem paga? Quais dados nunca podem se misturar com
  dados de outro contratante do The Band?
- **Organização**: qual organização do mundo real produziu este commit, esta equipe, este
  projeto?

### Se fundir, a Conecta Academy precisaria de três instalações isoladas

E aí ela **perde a capacidade central do produto**: não consegue mais perguntar

> qual dos meus três clientes tem pior cycle time?

Porque a resposta exigiria cruzar Tenants, que é exatamente o que o isolamento proíbe. A fusão
transforma a funcionalidade principal em violação de segurança.

### O inverso também quebra

Um cliente único que seja holding com cinco subsidiárias precisa de cinco `eo.organization` e
**um** Tenant. Com os conceitos fundidos, ou ele perde a distinção entre subsidiárias, ou ganha
cinco instalações que não conversam.

## A distinção vizinha, e igualmente inviolável

A mesma pressa que funde Tenant com Organização tende a modelar:

```text
eo_people
  id
  name
  organization_id   ← ERRADO
```

Pessoa **não pertence** a organização. Pessoa é agente físico e existe independentemente. O
vínculo é contextual, com papel e período:

```text
eo_people              pessoa: agente físico
eo_teams               equipe: pertence a organização   ← aqui "pertence" está correto
eo_team_memberships    pessoa + equipe + papel + início + fim   ← o vínculo
```

`Team Member` é o **papel**. `Team Membership` é o **vínculo com período**.

Três informações que `organization_id` em `eo_people` destruiria:

1. **Pessoa em duas organizações.** Um consultor atende Prefeitura e Banco X ao mesmo tempo. Com
   `organization_id`, viram duas "pessoas" que são a mesma — e "quantas pessoas trabalham nestes
   projetos?" passa a contar errado.
2. **Papel.** A mesma pessoa é desenvolvedora num projeto e revisora em outro.
   `organization_id` não tem onde guardar isso, e "quais pessoas acumulam papéis?" — que está na
   visão do produto — fica inrespondível.
3. **Tempo.** A pessoa saiu da equipe em março. Ou se apaga o vínculo, perdendo histórico, ou se
   mantém, mentindo sobre o presente. Cycle time por equipe fica errado nos dois casos.

Projeto é conceito de SPO e tem **stakeholders**, não dono único.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| **"Organização atendida"** em português, `tenant_id` no banco | Mantém a palavra "organização" em ambos os lados. A ambiguidade sobrevive na conversa e na revisão de código, que é onde o erro acontece |
| **"Cliente"** / `customer` | Sem ambiguidade ontológica, mas sugere relação de faturamento e fica incorreto quando o Tenant for interno |
| **Um só conceito**, com organizações como unidades organizacionais dentro dele | É a fusão. Destrói a pergunta comparativa, como mostrado acima |
| **Tenant** (adotada) | Termo de indústria, sem colisão com o vocabulário ontológico. "Organização" fica livre para significar exatamente o que a ontologia EO diz |

## Consequências

### Aceitas

- **Um termo em inglês no meio de documentação em português.** Deliberado: a alternativa era
  ambiguidade permanente sobre o conceito mais estrutural do sistema.
- **Toda tabela ontológica terá `tenant_id`**, inclusive `eo_organizations`. Parece redundante à
  primeira vista e não é.

### Ganhas

- Uma consultoria pode comparar seus próprios clientes sem violar isolamento.
- Uma holding pode distinguir subsidiárias dentro de um contrato.
- As features 005 e 006 chegam com o vocabulário já resolvido, em vez de negociá-lo sob pressão
  de implementação.

## Verificação

A distinção é verificada por teste, não apenas documentada. A constituição autoriza bloquear
feature por risco semântico; documentação avisa, teste impede.

`test/the_band/semantic_boundaries_test.exs` afirma que:

- `tenants` **não** tem `organization_id`, `org_id`, `company_id`, `customer_id` nem
  `organizational_unit_id`;
- `tenants` tem exatamente os campos previstos — lista fechada, para que um campo novo apareça no
  diff com a razão;
- `tenants` é a **única** tabela sem `tenant_id`, porque não pertence a si mesma;
- `operational_events` **não** referencia projeto, atividade, processo, sprint nem user story;
- nenhum módulo sob `TheBand.Ontology` existe nesta feature;
- nenhuma tabela usa prefixo de ontologia;
- dois Tenants podem ter o **mesmo nome** — porque `name` é rótulo humano do contratante, não
  identidade de organização de domínio.

## Quando reconsiderar

Não há cenário previsto para fundir os conceitos. O que pode mudar é o **termo**: se "Tenant"
provar-se obstáculo de comunicação com quem usa a plataforma, o rótulo de interface pode ser
traduzido, mantendo `tenant_id` no modelo. Isso é mudança de apresentação, não desta decisão.

## Referências

- `specs/001-phoenix-foundation-governance/spec.md` — seção `Terminologia canônica`
- `test/the_band/semantic_boundaries_test.exs` — as guardas
- `CLAUDE.md` — seção `Termo canônico: Tenant ≠ Organização`
- ADR-0002 — estratégia de isolamento por Tenant
