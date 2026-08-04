defmodule TheBand.Audit.OperationalEvent do
  @moduledoc """
  Evento operacional — fato sobre a execução desta plataforma, pertencente a um Tenant
  (FR-018, FR-030).

  **Não é `spo.performed_activity`** nem qualquer evento do domínio analisado. Não representa
  atividade de processo de software de projeto observado algum. Ver ADR-0003 (chega na issue #7).
  """

  use TheBand.Schema

  import Ecto.Changeset

  alias TheBand.Telemetry.Handler

  @type t :: %__MODULE__{}

  schema "operational_events" do
    field :type, :string
    field :correlation_id, :string
    field :occurred_at, :utc_datetime_usec
    field :metadata, :map, default: %{}

    belongs_to :tenant, TheBand.Tenancy.Tenant
  end

  @doc """
  Changeset de criação.

  `tenant_id` é injetado pelo escopo, nunca aceito dos atributos: `cast/3` não o inclui, e
  `TheBand.Audit` o define a partir do `Scope`. Aceitar dos atributos permitiria gravar evento
  num Tenant diferente do escopo ativo, que é exatamente o vazamento que FR-019 impede.
  """
  @spec create_changeset(map(), Ecto.UUID.t()) :: Ecto.Changeset.t()
  def create_changeset(attrs, tenant_id) do
    %__MODULE__{}
    |> cast(attrs, [:type, :correlation_id, :occurred_at, :metadata])
    |> put_change(:tenant_id, tenant_id)
    |> validate_required([:type, :correlation_id, :occurred_at, :tenant_id])
    |> validate_length(:type, min: 1, max: 100)
    |> validate_length(:correlation_id, min: 1, max: 64)
    |> validate_metadata_not_sensitive()
    |> foreign_key_constraint(:tenant_id)
  end

  # FR-030 — rejeita na escrita em vez de mascarar na leitura.
  #
  # Mascarar depois pressupõe que o valor já foi persistido em algum lugar, e num banco isso é
  # tarde: ele fica em backup, em réplica e em log de replicação. Rejeitar impede a entrada.
  #
  # Reutiliza a mesma lista de `TheBand.Telemetry.Handler` de propósito: duas listas
  # divergiriam, e a que ficasse desatualizada seria descoberta por um vazamento.
  defp validate_metadata_not_sensitive(changeset) do
    case get_change(changeset, :metadata) do
      nil ->
        changeset

      metadata when is_map(metadata) ->
        sensiveis = metadata |> Map.keys() |> Enum.filter(&Handler.sensitive?/1)

        if sensiveis == [] do
          changeset
        else
          add_error(
            changeset,
            :metadata,
            "contém chave de nome sensível: #{Enum.map_join(sensiveis, ", ", &to_string/1)}. " <>
              "Valor sensível não entra em registro operacional (FR-030)."
          )
        end

      _ ->
        add_error(changeset, :metadata, "deve ser um mapa")
    end
  end
end
