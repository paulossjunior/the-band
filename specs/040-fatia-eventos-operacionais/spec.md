# Feature 040 — Fatia vertical: eventos operacionais na tela

**Branch**: `feature/33-fatia-eventos-operacionais` · **Issue**: #33 · **Data**: 2026-08-06

**Status**: aprovada por delegação permanente (ver `AGENTS.md`)

> **Cerimônia proporcional, de propósito.** Especificação, plano e tarefas em **um** arquivo, com um
> checklist. A feature 002 recebeu 98 requisitos, 24 critérios e três checklists para um validador de
> YAML, e isso foi excesso meu, não exigência da constituição. O ciclo continua completo — o que muda
> é o tamanho.

## Por que existe

O roadmap punha a primeira tela na feature **035, de 39**. As features 002 e 003 são infraestrutura
pura, com zero saída visível. Semanas sem nada que se pudesse olhar, e sem saber se o que foi
construído serve — porque não havia consumidor.

Esta fatia atravessa **todas** as camadas com dado que já existe: banco → escopo de Tenant → consulta
→ LiveView → tela. Nenhuma ontologia, nenhum YAML, nenhum conector.

## História

Quem opera a plataforma abre uma tela, escolhe um Tenant, e vê os eventos operacionais dele —
filtrando por tipo e por período. Ao clicar num identificador de correlação, vê tudo que aconteceu na
mesma operação.

**Teste independente**: com dois Tenants semeados, abrir a tela de um e confirmar que nenhum evento do
outro aparece, nem na lista nem na contagem.

## Requisitos

**Consulta**

- **FR-001**: A listagem MUST aceitar filtro por tipo, por instante inicial e por identificador de
  correlação, sempre **dentro** do escopo de Tenant.
- **FR-002**: A contagem MUST aceitar **os mesmos** filtros da listagem. Hoje `count_events/1` não
  aceita filtro algum enquanto `list_events/2` aceita tipo: uma tela que filtrasse a lista e usasse a
  contagem sem filtro exibiria "142 eventos" mostrando 3 — número que contradiz a tela.
- **FR-003**: MUST existir consulta dos tipos distintos presentes no Tenant, para alimentar o filtro.
  Lista de tipos fixa no código mentiria assim que um tipo novo aparecesse.
- **FR-004**: Nenhuma das consultas novas MUST alcançar outro Tenant — nem em conteúdo, nem em
  contagem, nem na lista de tipos. Volume e vocabulário já são informação sobre o outro contratante.

**Tela**

- **FR-005**: A tela MUST listar os eventos do Tenant, mais recentes primeiro, com instante, tipo e
  identificador de correlação.
- **FR-006**: A tela MUST oferecer filtro por tipo e por período, e a contagem exibida MUST
  corresponder ao filtro aplicado.
- **FR-007**: O identificador de correlação MUST ser navegável, levando a todos os eventos da mesma
  correlação.
- **FR-008**: A tela MUST distinguir "nenhum evento neste Tenant" de "nenhum evento com este filtro".
  As duas frases são respostas diferentes, e confundi-las faz quem opera procurar no lugar errado.
- **FR-009**: Tenant inexistente MUST produzir recusa clara, sem revelar se o slug existe em outro
  lugar.

**Acesso**

- **FR-010**: A tela MUST existir **apenas** em desenvolvimento, e MUST NOT ser roteada fora dele. Não
  existe autenticação nesta plataforma; uma rota que aceita o slug do Tenant sem controle de acesso
  deixaria qualquer pessoa ler qualquer Tenant. Verificado por teste.
- **FR-011**: A limitação de FR-010 MUST estar declarada na própria tela, visível para quem a usa —
  não apenas nesta especificação.

## Critérios de sucesso

- **SC-001**: Com dois Tenants e eventos em ambos, a tela de um mostra **zero** eventos do outro, e a
  contagem também.
- **SC-002**: A contagem exibida é igual ao número de linhas que o filtro produz, verificado com
  filtro aplicado e sem filtro.
- **SC-003**: A rota não existe quando `dev_routes` está desligado, verificado por teste.
- **SC-004**: A tela abre em menos de 1 segundo com 500 eventos no Tenant.
- **SC-005**: `mix gates` exit 0, sem teste removido ou enfraquecido.

## Fora de escopo

- autenticação e autorização — é o que torna FR-010 necessário;
- escrita pela tela;
- qualquer ontologia, YAML ou conector;
- **contrato OpenAPI**: a regra vale para superfície consumida por outro programa. LiveView é
  consumida por navegador, por pessoa. Não dispara. Registrado para não parecer esquecido.

## Plano

| Item | Escolha | Razão |
|---|---|---|
| Camada de tela | Phoenix LiveView | está na stack obrigatória; é tela **e** backend na mesma entrega |
| Acesso | rota sob `dev_routes`, como o LiveDashboard | não existe autenticação; alternativa seria segurança de fachada |
| Filtros | na consulta, dentro do escopo | filtrar em memória depois de carregar tudo vazaria volume e não escalaria |
| Dependência nova | **nenhuma** | — |

Nenhuma decisão desta feature exige ADR. Nada da lista de tecnologias proibidas é introduzido.

## Tarefas

- [ ] **T001** Estender `Audit.Queries` com filtros de tipo, instante inicial e correlação, sempre a
  partir de `scoped/1`. [FR-001]
- [ ] **T002** `count/2` aceitando os mesmos filtros de `list/2`. [FR-002]
- [ ] **T003** `list_types/1` devolvendo os tipos distintos do Tenant, ordenados. [FR-003]
- [ ] **T004** Expor as três em `TheBand.Audit` por `defdelegate` — nada fora do módulo alcança
  `Queries` direto. [FR-001 a FR-003]
- [ ] **T005** Testes de que as três **não** alcançam outro Tenant, e de que levantam sem escopo.
  [FR-004, SC-001]
- [ ] **T006** Teste de que a contagem filtrada concorda com o tamanho da lista filtrada — a
  correspondência é o requisito, não a implementação. [FR-002, SC-002]
- [ ] **T007** LiveView com lista, filtros de tipo e período, e contagem. [FR-005, FR-006]
- [ ] **T008** Navegação por correlação. [FR-007]
- [ ] **T009** Estados vazios distintos: sem evento no Tenant × sem evento com o filtro. [FR-008]
- [ ] **T010** Recusa de Tenant inexistente sem revelar existência alheia. [FR-009]
- [ ] **T011** Rota sob `dev_routes`, e teste de que ela **não** existe fora de desenvolvimento.
  [FR-010, SC-003]
- [ ] **T012** Aviso na própria tela de que ela é de desenvolvimento e não tem controle de acesso.
  [FR-011]
- [ ] **T013** Teste de tela: lista, filtra, e a contagem acompanha. [SC-002]
- [ ] **T014** Medir a abertura com 500 eventos. [SC-004]
- [ ] **T015** `mix gates`, e evidência requisito por requisito no PR. [SC-005]

## Checklist de qualidade

- [x] Requisitos testáveis e sem adjetivo vago
- [x] Critérios mensuráveis
- [x] Escopo delimitado, com o que **não** entra e por quê
- [x] A limitação de acesso está declarada, não escondida
- [x] Todo requisito tem tarefa; toda tarefa tem requisito
- [x] Nenhuma dependência nova
- [x] Cerimônia proporcional: um arquivo, um checklist
