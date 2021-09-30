defmodule Backend.Hearthstone.MinionType do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :integer, []}
  schema "hs_minion_types" do
    field :game_modes, {:array, :integer}
    field :name, :string
    field :slug, :string

    timestamps()
  end

  @doc false
  def changeset(minion_type, %Hearthstone.Metadata.MinionType{} = struct) do
    attrs = Map.from_struct(struct)

    minion_type
    |> cast(attrs, [:id, :name, :slug, :game_modes])
    |> validate_required([:id, :name, :slug, :game_modes])
  end
end
