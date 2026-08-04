# The Band

Plataforma de integração semântica e análise de dados de Engenharia de Software.

The Band coleta dados de ferramentas usadas ao longo do desenvolvimento de software,
harmoniza esses dados semanticamente com base em uma rede de ontologias de referência,
preserva origem e rastreabilidade, e disponibiliza informação confiável para análise e
tomada de decisão.

## Estado

**Bootstrap.** Spec Kit inicializado e constituição ratificada. A aplicação Phoenix
ainda não existe — será entregue pela feature `001 — Fundação Phoenix e governança`.

## Perguntas que o sistema deve responder

- Quais projetos apresentam maior retrabalho?
- Quais equipes apresentam maior cycle time?
- Quais Pull Requests aguardam mais tempo por revisão?
- Quais projetos apresentam baixa taxa de sucesso de pipeline?
- Quais componentes concentram maior número de defeitos?
- De quais fontes um indicador foi derivado, e como a medida foi calculada?

## Fundamentação

O modelo semântico usa como referência UFO (A/B/C) e a rede SEON: EO, SPO, SysSwO,
RSRO, CMPO, ROoST, QAPO, OSDEF e Continuum (SRO, CIRO, CDRO).

## Stack

Elixir · Phoenix · Phoenix LiveView · Ecto · PostgreSQL · Oban · Req · ExUnit · Mox ·
Credo · Dialyzer · Docker Compose · Phoenix Releases.

Arquitetura: monólito modular multitenant, organizado pelas ontologias.

## Documentação

- [Constituição do projeto](.specify/memory/constitution.md) — normas obrigatórias
- [CLAUDE.md](CLAUDE.md) — guia operacional, arquitetura e roadmap
- `specs/` — especificações por feature (Spec Kit)
- `docs/` — arquitetura, ontologias, integrações, medidas e ADRs

## Desenvolvimento

Requisitos locais: Elixir 1.20+, Erlang/OTP 29, Docker (PostgreSQL via Compose).

Instruções de execução serão adicionadas pela feature 001.

## Licença

A definir na feature 001.
