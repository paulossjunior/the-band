defmodule TheBand.Schema do
  @moduledoc """
  Base de todo schema Ecto do The Band.

  ## Por que existe

  `config :the_band, TheBand.Repo, migration_primary_key: [type: :binary_id]` afeta **apenas
  migrações**. Schemas precisam declarar `@primary_key` e `@foreign_key_type` por conta própria,
  e a omissão não é erro de compilação: a inserção falha em tempo de execução com `id` nulo.

  Foi exatamente o que aconteceu ao escrever os dois primeiros schemas. Com doze ontologias por
  vir, repetir as duas linhas em cada arquivo garantiria que alguém esquecesse — e a falha
  apareceria como violação de restrição no banco, longe da causa.

  ## Uso

      defmodule TheBand.Tenancy.Tenant do
        use TheBand.Schema

        schema "tenants" do
          field :slug, :string
          timestamps()
        end
      end

  ## Padrões e o motivo de cada um

  `binary_id` como chave primária: identificador não sequencial não vaza volume nem ordem de
  criação entre Tenants, e permite gerar a identidade antes de escrever.

  `utc_datetime_usec` nos timestamps: o cálculo de medidas depende de ordenar eventos próximos
  no tempo — tempo até a primeira revisão, cycle time. Precisão de segundo empataria eventos
  distintos e produziria medida errada.
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema

      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
      @timestamps_opts [type: :utc_datetime_usec]
    end
  end
end
