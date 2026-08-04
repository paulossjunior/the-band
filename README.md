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

### Pré-requisitos

| Item | Versão verificada | Conferir com |
|---|---|---|
| Elixir | 1.20.2 | `elixir --version` |
| Erlang/OTP | 29 | `elixir --version` |
| Docker | daemon ativo | `docker info` |

Se `mix` reclamar de Hex ou rebar:

```bash
mix local.hex --force && mix local.rebar --force
```

### Subir a plataforma

```bash
git clone https://github.com/paulossjunior/the-band.git
cd the-band
cp .env.example .env        # preencher os valores locais
docker compose up -d        # sobe apenas o PostgreSQL
mix deps.get
mix ecto.setup              # cria a base, migra e semeia
mix phx.server
```

Confirmar que está viva:

```bash
curl -s http://localhost:4000/health
# {"status":"alive"}
```

Pronto. Nenhum passo manual além destes.

### Verificação de saúde

Dois caminhos distintos, de propósito.

| Caminho | Credencial | O que responde |
|---|---|---|
| `GET /health` | não | apenas se a plataforma está viva. **Não consulta dependência alguma** e não nomeia componente |
| `GET /health/detail` | sim | estado de cada componente: armazenamento e trabalho assíncrono |

O caminho público não detalha nada porque este repositório é público e a URL fica
documentada: resposta detalhada aberta entregaria reconhecimento de infraestrutura a
qualquer pessoa.

Para usar o caminho detalhado, gere e exporte o segredo de operação:

```bash
export THE_BAND_OPERATOR_SECRET=$(mix phx.gen.secret 48)

curl -s -H "Authorization: Bearer $THE_BAND_OPERATOR_SECRET" \
  http://localhost:4000/health/detail
# {"status":"healthy","components":{"background_jobs":"up","database":"up"}}
```

Sem o segredo configurado, o caminho detalhado **recusa** todo acesso — nunca libera. O
público continua respondendo.

### Portões de qualidade

```bash
mix gates
```

Roda, nesta ordem: formatação, compilação sem alerta, análise estática estrita, análise de
tipos e testes. **A ordem importa** — `mix credo` não compila o projeto antes de rodar, e sem
a compilação as checagens próprias do projeto não carregam.

Testes de integração ficam fora da execução padrão por velocidade, e são obrigatórios no
fluxo de verificação automática:

```bash
mix test --only integration
```

A primeira execução de `mix dialyzer` constrói o PLT e leva cerca de 1m20s. As seguintes
levam segundos.

### Fluxo de contribuição

Toda mudança: issue → branch própria → Pull Request → verificações → merge. Nunca push
direto na `main`, que é protegida no servidor sem ator de exceção.

Ver [`CLAUDE.md`](CLAUDE.md) para o guia operacional e
[`.specify/memory/constitution.md`](.specify/memory/constitution.md) para as normas — em
conflito, a constituição prevalece.

## Licença

**Apache-2.0.** Ver [`LICENSE`](LICENSE) e [`NOTICE`](NOTICE).
