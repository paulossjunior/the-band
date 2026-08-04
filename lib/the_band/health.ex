defmodule TheBand.Health do
  @moduledoc """
  Verificação de saúde em dois níveis (FR-001 a FR-004).

  | Nível | Consulta dependência? | Exige credencial? |
  |---|---|---|
  | público (`TheBandWeb.HealthController`) | **não** | não |
  | `detailed/0` | sim | sim, na camada web |

  O caminho público não consulta nada de propósito. Duas razões: fica barato o suficiente
  para uso como sonda de alta frequência, e não pode revelar estado de componente a quem não
  tem o segredo de operação — o repositório é público e a URL fica documentada.

  Não há função de vivacidade aqui. Ela existiu, devolvia `true` sempre, e o compilador
  reprovou o ramo morto que a consumia. Chegar ao controlador já é a prova. A garantia de que
  o caminho público não toca dependência é verificada no teste de contrato, com dublê que
  falha se for chamado — garantia mais forte, porque vale para o caminho HTTP inteiro.
  """

  alias TheBand.Health.Checker

  @type report :: %{status: :healthy | :unhealthy, components: %{atom() => Checker.status()}}

  @doc """
  Relatório por componente.

  Consulta **todos** os componentes, mesmo depois de um já ter falhado: parar no primeiro
  erro esconderia falhas simultâneas e obrigaria a corrigir uma para descobrir a outra.

  Exceção levantada por um verificador é tratada como componente fora, nunca propagada. A
  verificação de saúde não pode falhar por causa da coisa que está verificando: propagar
  devolveria erro genérico em vez de diagnóstico com o componente nomeado.
  """
  @spec detailed() :: report()
  def detailed do
    components = %{
      database: safe_check(:database),
      background_jobs: safe_check(:background_jobs)
    }

    status = if Enum.all?(components, fn {_k, v} -> v == :up end), do: :healthy, else: :unhealthy

    :telemetry.execute([:the_band, :health, :check], %{}, %{status: status})

    %{status: status, components: components}
  end

  defp safe_check(component) do
    apply(checker(), component, [])
  rescue
    _ -> :down
  catch
    :exit, _ -> :down
  end

  defp checker do
    Application.get_env(:the_band, :health_checker, TheBand.Health.SystemChecker)
  end
end
