# The Band Constitution

The Band é uma plataforma de integração semântica e análise de dados de Engenharia de
Software. Coleta dados de ferramentas usadas no desenvolvimento de software, harmoniza
esses dados semanticamente, preserva origem e rastreabilidade, e disponibiliza
informação confiável para análise e tomada de decisão.

The Band **não** é um dashboard, um data lake sem semântica, um conjunto de scripts de
extração, uma cópia dos modelos de dados das ferramentas, um chatbot ligado ao banco,
nem um conjunto de tabelas espelhando payloads externos.

## Core Principles

### I. Especificação antes de código (NÃO NEGOCIÁVEL)

Nenhuma linha de código de produto sem o ciclo completo do Spec Kit: `spec.md`
aprovado, `clarify` concluído, `checklist` aprovado, `plan.md` aprovado, `tasks.md`
aprovado, Issues criadas, `analyze` sem inconsistência crítica.

Entenda o problema antes de alterar código. Explore o repositório antes de propor
solução. Não presuma a stack — identifique o que já existe. Proibido "vibe coding".

Se um novo requisito aparecer durante a implementação, atualize os artefatos do Spec
Kit antes de mudar o código. Nunca amplie escopo silenciosamente. Nunca invente
requisito. Havendo incerteza relevante, pare e apresente alternativas.

### II. Semântica primeiro, ferramenta depois

O núcleo do domínio é organizado pelas ontologias, nunca pelas ferramentas externas. O
domínio central não depende dos modelos dos fornecedores. A API externa nunca é o
modelo de domínio.

Não trate conceitos como equivalentes só porque têm nomes semelhantes. Diferencie
eventos, objetos, agentes, papéis, estados e documentos. Quando um conceito já existe
em ontologia mais geral, reutilize — não duplique conceitos entre ontologias.

Nenhuma transformação ocorre sem mapeamento semântico explícito e versionado.

Distinções obrigatórias e não negociáveis:

- `Person` (EO) não é `Team Member`; `Team Member` é papel e `Team Membership` é a
  relação contextual.
- Processo planejado (`Intended Process`) não é processo executado
  (`Performed Process`).
- Código (`Code`) não é o programa (`Program`).
- Documento de requisitos não é o requisito.
- Pull Request não é o merge nem a decisão de aprovação.
- Teste planejado (`Test Case`) não é execução de teste (`Test Execution`).
- Code smell não é automaticamente defeito.
- `Failure` é evento; `Defect` não é necessariamente `Failure`.

### III. Proveniência e rastreabilidade ponta a ponta

Todo dado integrado preserva sua proveniência: `source_system`, `source_instance`,
`external_id`, `collected_at`, payload bruto, `mapping_id`, `schema_version`.

Rastreabilidade obrigatória na cadeia: necessidade de informação → especificação →
tarefa → issue → branch → código → teste → PR → entrega → medida.

O sistema deve poder responder: de quais fontes um indicador foi derivado, como uma
medida foi calculada, e quais dados e relações explicam qualquer resposta dada.

### IV. Nenhuma métrica sem necessidade de informação

Nenhuma medida, indicador ou dashboard existe sem uma necessidade de informação
declarada em YAML, com pergunta respondida, decisão apoiada, stakeholders, conceitos e
relações requeridos, fórmula, unidade, escopo, limitações e interpretações incorretas
possíveis.

Corolário: nenhuma ontologia é implementada sem consumidor identificado.

### V. Evidência antes de conclusão (NÃO NEGOCIÁVEL)

Nenhum agente declara sucesso sem evidência executada e anexada. Tarefa não é marcada
concluída sem evidência. Nenhuma inconsistência do `analyze` é ignorada.

Proibido: reduzir ou remover testes para o pipeline passar; esconder erro com mock
excessivo ou valor fixo; declarar aprovado sem rodar os quality gates.

A verificação é independente de quem implementa. Enquanto houver mais de uma pessoa
mantenedora, essa independência é humana: quem implementa não aprova. Com uma única
pessoa mantenedora, a independência é mecânica e está definida na cláusula
`Mantenedor único` da seção Development Workflow — nunca dispensada.

### VI. Simplicidade evolutiva

Monólito modular multitenant em Elixir/Phoenix. Não crie microserviços
prematuramente. Não introduza nova tecnologia quando as atuais bastarem. Prefira
mudanças pequenas, verificáveis e reversíveis. Preserve padrões existentes quando
adequados. Não faça refatoração sem relação com a feature em curso. Não misture
features independentes no mesmo PR.

Não crie pastas vazias antecipadamente — crie quando a fundação ou uma feature
justificar.

### VII. Idempotência

Todo processamento repetido é idempotente. Reprocessar a mesma fonte, página ou
payload não duplica entidade, não corrompe estado e não altera medida.

### VIII. Base de conhecimento como artefato de domínio

Os YAMLs em `priv/knowledge_base/` são base de conhecimento declarativa, versionada,
validável e auditável — não arquivos de configuração. São artefatos de domínio:
versionados, validados no CI e revisados.

Todo YAML possui schema, versão, identificador estável, dependências declaradas e
proveniência declarada. Schema estrito rejeita campo desconhecido. YAML inválido nunca
é aceito. Mudança que altere semântica, contrato ou comportamento exige teste e
revisão semântica. Mudança incompatível é declarada explicitamente.

Nenhum YAML contém segredo, token ou credencial.

## Fundamentação Ontológica

Referências: UFO-A, UFO-B, UFO-C, SEON, EO, SPO, SysSwO, RSRO, CMPO, ROoST, QAPO,
OSDEF, Continuum, SRO, CIRO, CDRO.

Rede e organização modular:

```text
UFO
└── SEON
    ├── EO      ├── SPO     ├── SysSwO  ├── RSRO
    ├── CMPO    ├── ROoST   ├── QAPO    ├── OSDEF
    └── Continuum
        ├── SRO  ├── CIRO   └── CDRO
```

A dependência vai do módulo mais específico para o mais geral.

Permitido: `SRO → EO|SPO|SysSwO|RSRO`; `CIRO → SPO|SysSwO|CMPO|ROoST|QAPO|OSDEF`;
`CDRO → SPO|SysSwO|CIRO`.

Proibido: `EO → SRO`; `SPO → CIRO`; `SysSwO → CDRO`. Ciclos falham o build
(`mix knowledge.graph`).

Cada ontologia expõe API pública pelo módulo principal. Outros módulos nunca acessam
schemas internos nem detalhes de persistência de outra ontologia. Conectores nunca
escrevem direto nos schemas Ecto dos módulos ontológicos.

Tabelas usam prefixo por ontologia (`eo_`, `spo_`, `sysswo_`, `rsro_`, `cmpo_`,
`roost_`, `qapo_`, `osdef_`, `sro_`, `ciro_`, `cdro_`).

## Restrições Tecnológicas

Stack obrigatória: Elixir, Erlang/OTP, Phoenix, Phoenix LiveView, Ecto, PostgreSQL,
Oban, Req, ExUnit, Mox, Credo, Dialyzer, ExDoc, Docker Compose, Phoenix Releases.

Biblioteca adicional exige justificativa registrada no `plan.md` da feature.

Proibido por padrão, só por feature específica + análise comparativa + ADR: Python,
FastAPI, Go, frontend separado em TypeScript, Node.js como requisito central, NATS,
Kafka, RabbitMQ, Redis como fila obrigatória, Apache AGE, Neo4j, pgvector,
Kubernetes, Helm, microserviços, GraphRAG completo na fundação.

Multitenancy: uma base PostgreSQL, tabelas compartilhadas, `tenant_id` nas entidades
relevantes, políticas de acesso. Não um banco por tenant. Todo acesso considera o
tenant atual. Jobs Oban carregam e validam `tenant_id`. YAMLs de conhecimento são
globais por padrão.

Segurança: nunca versionar token, senha, chave privada, secret, credencial, dado
pessoal sensível ou `.env` real. Usar variáveis de ambiente e secret manager. Logs
não expõem token nem payload sensível completo.

Decisões que exigem ADR: abandonar monólito modular; introduzir microserviços;
introduzir backend adicional; introduzir frontend separado; substituir PostgreSQL;
substituir Oban; introduzir broker externo; introduzir banco de grafos; introduzir
pgvector; alterar estratégia multitenant; alterar organização por ontologias; alterar
YAML como base de conhecimento; alterar versionamento dos YAMLs; alterar separação
entre fonte externa e domínio; alterar contratos públicos; abandonar Spec Kit.

## Development Workflow

Ciclo obrigatório por feature:

```text
Necessidade → Discovery → Feature Request
→ /speckit-specify → /speckit-clarify → /speckit-checklist → aprovação
→ /speckit-plan → revisão arquitetural → revisão semântica
→ /speckit-tasks → /speckit-taskstoissues → /speckit-analyze
→ branch → implementação → testes → quality gates → convergência
→ Pull Request → verificação independente → merge
```

A "verificação independente" é aprovação humana de outra pessoa quando houver mais de uma
pessoa mantenedora, e verificação mecânica na cláusula `Mantenedor único` quando não
houver. Nunca é ausência de verificação.

Toda implementação está associada a uma GitHub Issue. Toda mudança ocorre em branch
própria (`feature|fix|refactor|docs|test|chore/<issue>-<descricao>`) e é submetida por
Pull Request. Nunca push direto na main. Nunca merge com teste falhando.

Commits seguem `tipo(escopo): descrição imperativa` — ex.:
`feat(sro): add user story knowledge definition`. Mensagem vaga é rejeitada.

### Mantenedor único

Enquanto o projeto tiver **uma única pessoa com permissão de escrita**, exigir aprovação
humana de outra pessoa tornaria toda incorporação impossível, e adotar a exigência
sabendo disso seria uma regra decorativa. Esta cláusula substitui a aprovação humana por
verificação mecânica, mais estrita em tudo que pode ser automatizado.

Vale enquanto, e somente enquanto, houver uma única pessoa com permissão de escrita.

**Permanece obrigatório, sem exceção:**

- toda mudança em branch própria e submetida por Pull Request;
- escrita direta na linha principal bloqueada no servidor, sem ator de exceção,
  inclusive para quem administra o repositório;
- reescrita de histórico e remoção da linha principal bloqueadas;
- **todos os quality gates registrados como verificações obrigatórias de status no
  servidor**, não apenas executadas — incorporação impossível com qualquer verificação
  reprovada, ausente ou pendente;
- resolução obrigatória de todos os comentários abertos;
- descarte de aprovações obsoletas a cada novo envio.

**O que muda:** a contagem de aprovações humanas exigidas passa a zero. A pessoa
mantenedora pode incorporar o próprio Pull Request **após** todas as verificações
obrigatórias passarem, e apenas então.

**Compensações obrigatórias**, porque nenhuma pessoa vai ler o diff de novo:

- todo requisito verificável precisa de verificação automatizada; o que só uma pessoa
  poderia conferir vira teste, checagem estática ou verificação de status;
- o Pull Request declara requisito por requisito qual evidência o cobre;
- achado do `analyze` classificado `CRITICAL` ou `HIGH` bloqueia a incorporação, e o
  bloqueio é registrado no Pull Request;
- revisão independente por outro agente antes da incorporação, com o resultado anexado
  ao Pull Request. Não substitui revisão humana e não é tratada como equivalente — é
  redução de risco, e essa limitação fica registrada.

**Enquanto as verificações obrigatórias de status não existirem no servidor**, a proteção
se reduz a "obrigatório passar por Pull Request". Este é um estado transitório conhecido,
registrado como risco, e encerrado pela tarefa que registra os quality gates como
verificações obrigatórias.

**Reversão automática:** ao entrar a segunda pessoa com permissão de escrita, esta
cláusula deixa de valer, a exigência de uma aprovação humana é restaurada, e a proibição
de aprovar o próprio Pull Request volta a vigorar sem necessidade de nova emenda.

Documentação, contratos, migrações, YAMLs e testes acompanham o código no mesmo PR.
Decisões arquiteturais relevantes são registradas em ADR em `docs/adr/`.

Toda feature ontológica identifica: ontologia principal, ontologias das quais depende,
conceitos adicionados ou alterados, relações, cardinalidades, constraints, perguntas de
competência, YAMLs criados ou alterados, mapeamentos externos, migrações, testes
conceituais e riscos semânticos.

## Quality Gates

Obrigatórios antes de abrir PR e no CI:

```bash
mix format --check-formatted
mix compile --warnings-as-errors
mix credo --strict
mix dialyzer
mix test
mix knowledge.validate   # a partir da feature 002
mix knowledge.graph      # a partir da feature 002
mix knowledge.test       # a partir da feature 002
```

Quando aplicável: `mix ecto.migrate`, `mix test --only integration`.

**Todos os quality gates aplicáveis são registrados como verificações obrigatórias de
status no servidor.** Executar localmente não substitui: a incorporação precisa ser
impossível com verificação reprovada, ausente ou pendente. Sob a cláusula
`Mantenedor único` este registro é o que sustenta a independência da verificação, e por
isso não é opcional.

PR só é aprovado quando: critérios de aceitação atendidos; testes passando; YAMLs
validados; perguntas de competência verificadas; build aprovado; análise estática
aprovada; migrações validadas; documentação atualizada; revisão semântica concluída;
ausência de segredos; sem achado `BLOCKER` ou `MAJOR`.

## Governance

Esta constituição prevalece sobre qualquer outra prática do projeto. Conflito entre
esta constituição e um `spec.md`, `plan.md` ou preferência de implementação resolve-se
em favor da constituição.

Emenda exige: PR próprio, justificativa registrada, avaliação de impacto nas features
em andamento e bump de versão (semver — MAJOR para remoção ou redefinição incompatível
de princípio, MINOR para novo princípio ou seção, PATCH para clarificação sem mudança
de obrigação).

Todo PR e toda revisão verificam conformidade com esta constituição. Complexidade
adicional deve ser justificada. O agente de Ontologia e Integração Semântica pode
bloquear qualquer feature por risco semântico.

Guia operacional de desenvolvimento: `CLAUDE.md` na raiz do repositório.

### Histórico de emendas

| Versão | Data | Mudança |
|---|---|---|
| 1.0.0 | 2026-08-03 | Ratificação inicial |
| 2.0.0 | 2026-08-03 | Cláusula `Mantenedor único`. Redefine a independência da verificação: humana com mais de uma pessoa mantenedora, mecânica com uma só. Torna explícito que os quality gates são verificações obrigatórias de status no servidor, não apenas execução local. Reversão automática ao entrar a segunda pessoa. **MAJOR** porque redefine de forma incompatível uma obrigação do princípio V |

**Version**: 2.0.0 | **Ratified**: 2026-08-03 | **Last Amended**: 2026-08-03
