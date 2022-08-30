defmodule Backend.Leaderboards.Season do
  use Ecto.Schema
  import Ecto.Changeset

  schema "leaderboards_seasons" do
    field :leaderboard_id, :string
    field :region, :string
    field :season_id, :integer

    timestamps()
  end

  @doc false
  def changeset(season, attrs) do
    season
    |> cast(attrs, [:season_id, :leaderboard_id, :region])
    |> validate_required([:season_id, :leaderboard_id, :region])
  end

  @spec uniq_string(%__MODULE__{} | Hearthstone.Leaderboards.Season.t()) :: string
  def uniq_string(season) do
    "#{season.leaderboard_id}_#{season.season_id}_#{season.region}"
  end
end
