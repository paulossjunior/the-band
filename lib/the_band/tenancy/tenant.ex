defmodule TheBand.Tenancy.Tenant do
  @moduledoc """
  Tenant — a unidade de isolamento da instalação (FR-009 a FR-011, FR-017).

  **Não é `eo.organization`.** Um Tenant é quem contrata e opera esta instalação. A organização
  do mundo real, analisada, é conceito da ontologia EO e chega na feature 005, com `tenant_id`
  própria. Um Tenant contém várias organizações — uma consultoria que analisa doze clientes é
  um Tenant e doze organizações. Fundir os dois destruiria a capacidade de comparar
  organizações dentro do mesmo contratante, que é uma das perguntas centrais do produto.
  Ver ADR-0003.
  """

  use TheBand.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @slug_format ~r/\A[a-z0-9-]{3,63}\z/

  schema "tenants" do
    field :slug, :string
    field :name, :string
    field :active, :boolean, default: true

    timestamps()
  end

  @doc """
  Changeset de criação.

  `slug` é aceito **apenas aqui**. Não existe changeset que o altere — é assim que a
  imutabilidade de FR-010 é imposta, e não por verificação condicional que alguém possa
  esquecer de chamar.
  """
  @spec create_changeset(map()) :: Ecto.Changeset.t()
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:slug, :name])
    |> validate_required([:slug, :name])
    |> validate_format(:slug, @slug_format,
      message: "deve conter apenas minúsculas, dígitos e hífen, com 3 a 63 caracteres"
    )
    |> validate_length(:name, min: 1, max: 255)
    |> unique_constraint(:slug)
    |> check_constraint(:slug, name: :slug_format, message: "formato inválido")
  end

  @doc """
  Changeset de renomeação.

  Aceita **apenas** `name`. `slug` ausente da lista de campos permitidos significa que
  `cast/3` o descarta silenciosamente se vier nos atributos: não há caminho de alteração.
  """
  @spec rename_changeset(t(), map()) :: Ecto.Changeset.t()
  def rename_changeset(%__MODULE__{} = tenant, attrs) do
    tenant
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 255)
  end

  @doc """
  Changeset de ativação e desativação.

  Altera **apenas** `active`. Desativar não remove, não anonimiza e não toca em nenhum outro
  campo (FR-017).
  """
  @spec activation_changeset(t(), boolean()) :: Ecto.Changeset.t()
  def activation_changeset(%__MODULE__{} = tenant, active) when is_boolean(active) do
    change(tenant, active: active)
  end

  @doc "Expressão regular do identificador legível. Exposta para teste e documentação."
  @spec slug_format() :: Regex.t()
  def slug_format, do: @slug_format
end
