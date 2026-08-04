defmodule TheBand.Config do
  @moduledoc """
  Leitura de configuração vinda do ambiente, com falha explícita.

  Existe como módulo, e não como função anônima dentro de `config/runtime.exs`, para que
  o comportamento seja testável. FR-007 exige que a ausência de uma variável obrigatória
  falhe a inicialização **nomeando** a variável, e um requisito não verificável não é
  requisito.
  """

  defmodule MissingEnvError do
    @moduledoc """
    Levantada quando uma variável de ambiente obrigatória está ausente ou vazia.
    """

    defexception [:message]
  end

  defmodule InvalidEnvError do
    @moduledoc """
    Levantada quando a variável está presente mas o valor não serve.

    Separada de `MissingEnvError` de propósito: "ausente" e "presente com valor inválido"
    exigem correções diferentes de quem opera, e um tipo de erro só para os dois casos
    mentiria sobre o que aconteceu.
    """

    defexception [:message]
  end

  @doc """
  Devolve o valor da variável de ambiente `name`.

  Levanta `TheBand.Config.MissingEnvError` quando a variável está ausente ou vazia,
  com mensagem que **nomeia** a variável e explica como obter um valor válido.

  Nunca devolve valor padrão: partir com padrão silencioso é exatamente o que FR-007
  proíbe. Quando um padrão for legítimo — porta de escuta, host de desenvolvimento —
  use `get_env/2`, que é explícito sobre isso.

  ## Exemplos

      iex> System.put_env("THE_BAND_EXAMPLE", "valor")
      iex> TheBand.Config.require_env!("THE_BAND_EXAMPLE")
      "valor"

      iex> System.delete_env("THE_BAND_ABSENT")
      iex> TheBand.Config.require_env!("THE_BAND_ABSENT")
      ** (TheBand.Config.MissingEnvError) variável de ambiente THE_BAND_ABSENT está ausente.
  """
  @spec require_env!(String.t(), keyword()) :: String.t()
  def require_env!(name, opts \\ []) when is_binary(name) do
    case System.get_env(name) do
      nil -> raise MissingEnvError, message: message_for(name, "está ausente", opts)
      "" -> raise MissingEnvError, message: message_for(name, "está definida mas vazia", opts)
      value -> value
    end
  end

  @doc """
  Devolve o valor da variável, ou `default` quando ausente ou vazia.

  Use apenas onde o padrão é seguro e a ausência não é erro. Se o padrão puder ser
  inseguro em produção, use `require_env!/2`.
  """
  @spec get_env(String.t(), String.t()) :: String.t()
  def get_env(name, default) when is_binary(name) and is_binary(default) do
    case System.get_env(name) do
      nil -> default
      "" -> default
      value -> value
    end
  end

  @doc """
  Igual a `get_env/2`, convertendo para inteiro.

  Levanta quando o valor está presente mas não é um inteiro — um valor inválido é erro de
  configuração, não motivo para cair no padrão silenciosamente.
  """
  @spec get_env_integer(String.t(), integer()) :: integer()
  def get_env_integer(name, default) when is_binary(name) and is_integer(default) do
    case System.get_env(name) do
      nil ->
        default

      "" ->
        default

      value ->
        case Integer.parse(value) do
          {int, ""} ->
            int

          _ ->
            raise InvalidEnvError,
              message:
                "variável de ambiente #{name} deve ser um número inteiro, " <>
                  "e recebeu um valor que não é. Corrija o valor no ambiente."
        end
    end
  end

  defp message_for(name, situation, opts) do
    base = "variável de ambiente #{name} #{situation}."

    case Keyword.get(opts, :hint) do
      nil -> base
      hint -> base <> " " <> hint
    end
  end
end
