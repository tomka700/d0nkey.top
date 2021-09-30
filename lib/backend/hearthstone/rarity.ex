defmodule Backend.Hearthstone.Rarity do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :integer, []}
  schema "hs_rarities" do
    field :crafting_cost, {:array, :integer}
    field :dust_value, {:array, :integer}
    field :gold_crafting_cost, :integer
    field :gold_dust_value, :integer
    field :name, :string
    field :normal_crafting_cost, :integer
    field :normal_dust_value, :integer
    field :slug, :string

    timestamps()
  end

  @doc false
  def changeset(rarity, %Hearthstone.Metadata.Rarity{} = struct) do
    attrs = Map.from_struct(struct)

    rarity
    |> cast(attrs, [:id, :name, :slug, :dust_value, :crafting_cost])
    |> put_dust_values(attrs)
    |> put_crafting_costs(attrs)
    |> validate_required([:id, :name, :slug, :dust_value, :crafting_cost])
  end

  defp put_dust_values(cs, %{dust_value: [normal, gold | _]}),
    do:
      cast(cs, %{normal_dust_value: normal, gold_dust_value: gold}, [
        :normal_dust_value,
        :gold_dust_value
      ])

  defp put_dust_values(cs, _), do: cs

  defp put_crafting_costs(cs, %{crafting_cost: [normal, gold | _]}),
    do:
      cast(cs, %{normal_crafting_cost: normal, gold_crafting_cost: gold}, [
        :normal_crafting_cost,
        :gold_crafting_cost
      ])

  defp put_crafting_costs(cs, _), do: cs
end
