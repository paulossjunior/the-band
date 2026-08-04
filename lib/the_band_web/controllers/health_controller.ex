defmodule TheBandWeb.HealthController do
  @moduledoc """
  Verificação de saúde **pública** (FR-001, SC-009).

  Responde apenas se a plataforma está viva. **Não consulta dependência alguma** e não nomeia
  componente algum.

  O corpo tem exatamente uma chave. Isso é contrato, não estilo: um campo acrescentado aqui
  passa a ser reconhecimento de infraestrutura entregue a qualquer pessoa, porque o
  repositório é público e a URL fica documentada. O teste de contrato afirma igualdade
  estrita de chaves justamente para que um acréscimo descuidado falhe.

  ## Por que não há chamada a uma função de vivacidade

  Uma versão anterior consultava `TheBand.Health.alive?/0` e ramificava no resultado. O
  compilador reprovou: a função não tinha caminho falso, então o ramo era código morto, e
  `--warnings-as-errors` transformou isso em falha de portão — corretamente.

  A conclusão é que a função não acrescentava nada: **chegar até aqui já é a prova**. A
  ausência de resposta é o sinal de que a plataforma não está viva; um corpo dizendo "fora"
  exigiria um processo vivo para produzi-lo, o que se contradiz.

  A garantia que importava — que este caminho não toca dependência — passou a ser verificada
  no teste de contrato, com dublê que falha se for chamado. É uma garantia mais forte que a
  função anterior dava, porque vale para o caminho HTTP inteiro e não só para uma função.
  """

  use TheBandWeb, :controller

  def show(conn, _params) do
    json(conn, %{status: "alive"})
  end
end
