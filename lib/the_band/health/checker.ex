defmodule TheBand.Health.Checker do
  @moduledoc """
  Fronteira entre a verificação de saúde e os componentes que ela consulta.

  Existe para que "componente fora" seja um estado testável, e não algo que só se reproduz
  derrubando processos no meio da suíte. A implementação real é
  `TheBand.Health.SystemChecker`; em teste, um dublê declarado com `Mox`.

  A escolha vem de configuração — `config :the_band, :health_checker` — e não de um
  parâmetro passado adiante, para que a camada web não precise saber que a fronteira existe.
  """

  @typedoc "Estado de um componente. Deliberadamente binário: não há 'degradado' sem alvo definido."
  @type status :: :up | :down

  @doc "Verifica se o armazenamento de dados aceita consulta."
  @callback database() :: status()

  @doc "Verifica se o mecanismo de trabalho assíncrono está operando."
  @callback background_jobs() :: status()
end
