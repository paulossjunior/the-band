# Contract — Verificação de saúde

**Feature**: 001 | **Requisitos**: FR-001 a FR-004, SC-009 | **Decisão**: [research.md](../research.md) R9

Dois caminhos **distintos**, não um caminho com corpo variável. Separar os caminhos evita
que um defeito de autorização exponha o corpo detalhado.

---

## `GET /health` — público

Não exige credencial. **Não consulta dependência alguma** — responde a partir do próprio
processo, o que o torna barato para uso como sonda de infraestrutura em alta frequência.

### Resposta — plataforma viva

```text
HTTP/1.1 200 OK
Content-Type: application/json
X-Correlation-Id: <uuid>
```

```json
{ "status": "alive" }
```

### Contrato negativo — obrigatório em teste

O corpo **não pode** conter, em nenhuma circunstância:

- nome de componente (`database`, `postgres`, `oban`, `repo`, `queue`, …)
- estado de componente
- versão de dependência, de linguagem ou de plataforma de execução
- endereço interno, nome de host, porta
- contagem, medição de tempo ou qualquer valor derivado de consulta

Verificação: `health_contract_test.exs` afirma que o corpo tem **exatamente** a chave
`status` e nada mais (SC-009).

### Se a plataforma não estiver viva

Nenhuma resposta é produzida — o processo não está atendendo. Ausência de resposta ou
recusa de conexão é o sinal. Este caminho nunca devolve `503` derivado de estado de
dependência, porque não consulta dependência.

---

## `GET /health/detail` — restrito a operação

Exige o segredo de operação. **Consulta** o armazenamento de dados e o mecanismo de
trabalho assíncrono.

### Requisição

```text
GET /health/detail
Authorization: Bearer <THE_BAND_OPERATOR_SECRET>
```

### Resposta — todos os componentes saudáveis

```text
HTTP/1.1 200 OK
Content-Type: application/json
X-Correlation-Id: <uuid>
```

```json
{
  "status": "healthy",
  "components": { "database": "up", "background_jobs": "up" }
}
```

### Resposta — componente com falha

```text
HTTP/1.1 503 Service Unavailable
```

```json
{
  "status": "unhealthy",
  "components": { "database": "down", "background_jobs": "up" }
}
```

O corpo identifica **qual** componente falhou, sem expor credencial, endereço interno,
mensagem de erro do driver nem rastro de pilha (FR-004).

### Resposta — sem credencial, credencial inválida, ou segredo não configurado

```text
HTTP/1.1 401 Unauthorized
Content-Type: application/json
```

```json
{ "error": "unauthorized" }
```

Idêntica nos três casos. O corpo **não** revela estado de componente nem distingue entre
"credencial errada" e "segredo não configurado no servidor" — distinguir informaria a um
atacante que a instalação tem o caminho aberto por configuração ausente.

**Segredo ausente da configuração recusa todo acesso**, nunca libera (edge case registrado
na especificação).

### Comparação do segredo

Comparação em **tempo constante**, para não permitir inferência por medição de tempo. Em
Elixir: `Plug.Crypto.secure_compare/2`.

---

## Cabeçalho de correlação

Ambos os caminhos devolvem `X-Correlation-Id`. Se a requisição trouxer o cabeçalho, o
valor é propagado; caso contrário é gerado (FR-029).

---

## Contrato de teste

| Caso | Esperado | Critério |
|---|---|---|
| `GET /health` | `200`, corpo com exatamente `{"status":"alive"}` | FR-001, SC-009 |
| `GET /health` com armazenamento indisponível | `200` — não consulta dependência | FR-001 |
| `GET /health/detail` sem cabeçalho | `401`, corpo `{"error":"unauthorized"}` | FR-003, SC-009 |
| `GET /health/detail` com segredo errado | `401`, corpo idêntico ao caso anterior | FR-003, SC-009 |
| `GET /health/detail` com segredo não configurado | `401` | FR-003, edge case |
| `GET /health/detail` com segredo válido | `200`, `components` com as duas chaves | FR-002 |
| `GET /health/detail` com armazenamento indisponível | `503`, `database: "down"` | FR-002, FR-004 |
| qualquer caminho | `X-Correlation-Id` presente | FR-029 |
