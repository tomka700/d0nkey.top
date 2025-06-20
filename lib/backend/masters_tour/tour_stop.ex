defmodule Backend.MastersTour.TourStop do
  @moduledoc false
  import TypedStruct
  alias Backend.Blizzard

  defmacro is_tour_stop(tour_stop) do
    quote do
      unquote(tour_stop) in [
        :"Las Vegas",
        :Seoul,
        :Bucharest,
        :Arlington,
        :Indonesia,
        :Jönköping,
        :"Asia-Pacific",
        :Montréal,
        :Madrid,
        :Ironforge,
        :Orgrimmar,
        :Dalaran,
        :Silvermoon,
        :Stormwind,
        :Undercity,
        :"Masters Tour One",
        :"Masters Tour Two",
        :"Masters Tour Three",
        :"Masters Tour Four",
        :"Masters Tour Five",
        :"Masters Tour Six",
        :"Masters Tour 2023_1",
        :"Masters Tour 2023_2",
        :"Masters Tour 2023_3",
        :"Masters Tour 2024_1",
        :"Masters Tour 2024_2",
        :"Masters Tour 2025_1",
        :"Masters Tour 2025_2",
        :"Worlds 2025"
      ]
    end
  end

  typedstruct enforce: true do
    field :id, :atom
    field :battlefy_id, Backend.Battlefy.tournament_id(), enforce: false
    field :ladder_seasons, [integer]
    field :ladder_invites, enforce: false
    field :ladder_points, [integer] | nil
    field :qualifiers_period, {Date.t(), Date.t()}
    field :region, Blizzard.region()
    field :start_time, NaiveDateTime.t(), enforce: false
    field :old_id, atom, enforce: false
    field :ladder_priority, atom
    field :min_qualifiers_for_winrate, integer | nil
    field :swiss_rounds, integer
    field :aliases, [String.t()]
    field :display_name, String.t() | nil
    field :year, integer
  end

  def all() do
    [
      %__MODULE__{
        id: :"Las Vegas",
        battlefy_id: "5cdb04cdce130203069be2dd",
        ladder_seasons: [],
        ladder_points: nil,
        ladder_invites: 0,
        ladder_priority: nil,
        region: :US,
        qualifiers_period: {~D[2019-03-05], ~D[2019-04-29]},
        start_time: ~N[2019-06-14 16:00:00],
        min_qualifiers_for_winrate: nil,
        aliases: [],
        display_name: nil,
        swiss_rounds: 13,
        year: 2019
      },
      %__MODULE__{
        id: :Seoul,
        battlefy_id: "5d3117357045a2325e167ad6",
        ladder_seasons: [],
        ladder_points: nil,
        ladder_invites: 0,
        ladder_priority: nil,
        region: :AP,
        qualifiers_period: {~D[2019-05-07], ~D[2019-07-01]},
        start_time: ~N[2019-08-16 01:00:00],
        min_qualifiers_for_winrate: nil,
        aliases: [],
        display_name: nil,
        swiss_rounds: 13,
        year: 2019
      },
      %__MODULE__{
        id: :Bucharest,
        battlefy_id: "5d8276701d82bf1a20dbf45b",
        ladder_seasons: [],
        ladder_points: nil,
        ladder_invites: 0,
        ladder_priority: nil,
        region: :EU,
        qualifiers_period: {~D[2019-07-04], ~D[2019-08-26]},
        start_time: ~N[2019-10-18 06:00:00],
        min_qualifiers_for_winrate: nil,
        swiss_rounds: 9,
        aliases: [],
        display_name: nil,
        year: 2019
      },
      %__MODULE__{
        id: :Arlington,
        battlefy_id: "5e1cf8ff1e66fd33ebbfc0ed",
        ladder_seasons: [72, 73],
        ladder_points: nil,
        ladder_priority: :regional,
        ladder_invites: 16,
        region: :US,
        start_time: ~N[2020-01-31 15:00:00],
        qualifiers_period: {~D[2019-10-04], ~D[2019-11-24]},
        min_qualifiers_for_winrate: nil,
        aliases: [],
        display_name: nil,
        swiss_rounds: 9,
        year: 2020
      },
      %__MODULE__{
        id: :Indonesia,
        battlefy_id: "5e5d80217506f5240ebad221",
        ladder_seasons: [74, 75],
        ladder_points: nil,
        ladder_priority: :regional,
        ladder_invites: 16,
        region: :AP,
        qualifiers_period: {~D[2019-12-13], ~D[2020-01-26]},
        start_time: ~N[2020-03-20 16:00:00],
        min_qualifiers_for_winrate: nil,
        aliases: ["Los Angeles"],
        display_name: "Los Angeles",
        swiss_rounds: 9,
        year: 2020
      },
      %__MODULE__{
        id: :Jönköping,
        battlefy_id: "5ec5ca7153702b1ab2a5c9dd",
        ladder_seasons: [76, 77],
        ladder_points: nil,
        ladder_priority: :regional,
        ladder_invites: 16,
        region: :EU,
        start_time: ~N[2020-06-12 12:15:00],
        qualifiers_period: {~D[2020-02-07], ~D[2020-03-29]},
        min_qualifiers_for_winrate: nil,
        aliases: [],
        display_name: nil,
        swiss_rounds: 9,
        year: 2020
      },
      %__MODULE__{
        id: :"Asia-Pacific",
        battlefy_id: "5efbcdaca2b8f022508f65c3",
        ladder_seasons: [78, 79],
        ladder_points: nil,
        ladder_priority: :regional,
        ladder_invites: 16,
        region: :AP,
        start_time: ~N[2020-07-17 00:00:00],
        qualifiers_period: {~D[2020-04-03], ~D[2020-05-24]},
        min_qualifiers_for_winrate: nil,
        aliases: [],
        display_name: nil,
        swiss_rounds: 9,
        year: 2020
      },
      %__MODULE__{
        id: :Montréal,
        battlefy_id: "5f3c3c6066bf242962711d60",
        ladder_seasons: [80, 81],
        ladder_points: nil,
        ladder_priority: :regional,
        ladder_invites: 16,
        region: :US,
        old_id: :Montreal,
        start_time: ~N[2020-09-11 15:15:00],
        qualifiers_period: {~D[2020-06-05], ~D[2020-07-26]},
        min_qualifiers_for_winrate: nil,
        aliases: ["Montreal"],
        display_name: nil,
        swiss_rounds: 9,
        year: 2020
      },
      %__MODULE__{
        id: :Madrid,
        battlefy_id: "5f8100994e9faf3dd1a80ad0",
        ladder_priority: :regional,
        ladder_points: nil,
        ladder_seasons: [82, 83],
        ladder_invites: 16,
        region: :EU,
        start_time: ~N[2020-10-23 12:15:00],
        qualifiers_period: {~D[2020-08-07], ~D[2020-09-27]},
        min_qualifiers_for_winrate: nil,
        aliases: [],
        display_name: nil,
        swiss_rounds: 9,
        year: 2020
      },
      %__MODULE__{
        id: :Ironforge,
        battlefy_id: "60368b4367dfd71a9ffe0848",
        ladder_priority: :regional,
        ladder_points: nil,
        ladder_seasons: [87],
        ladder_invites: 32,
        region: :US,
        start_time: ~N[2021-03-12 16:15:00],
        qualifiers_period: {~D[2021-01-28], ~D[2021-02-28]},
        min_qualifiers_for_winrate: nil,
        aliases: [],
        display_name: nil,
        swiss_rounds: 9,
        year: 2021
      },
      %__MODULE__{
        id: :Orgrimmar,
        battlefy_id: "607996932a7af81040b485e0",
        ladder_priority: :timezone,
        ladder_points: nil,
        ladder_seasons: [88, 89],
        ladder_invites: 16,
        region: :EU,
        qualifiers_period: {~D[2021-03-04], ~D[2021-04-12]},
        start_time: ~N[2021-04-30 12:15:00],
        min_qualifiers_for_winrate: nil,
        aliases: [],
        display_name: nil,
        swiss_rounds: 9,
        year: 2021
      },
      %__MODULE__{
        id: :Dalaran,
        battlefy_id: "60b75695c2e3fd31243ff2c3",
        ladder_priority: :timezone,
        ladder_points: nil,
        ladder_seasons: [90, 91],
        ladder_invites: 16,
        qualifiers_period: {~D[2021-04-15], ~D[2021-05-24]},
        region: :AP,
        start_time: ~N[2021-06-18 22:00:00],
        min_qualifiers_for_winrate: nil,
        aliases: [],
        display_name: nil,
        swiss_rounds: 9,
        year: 2021
      },
      %__MODULE__{
        id: :Silvermoon,
        battlefy_id: "6107b8dba3f8bf704c2fbb09",
        ladder_priority: :timezone,
        ladder_points: nil,
        ladder_seasons: [92, 93],
        ladder_invites: 16,
        region: :US,
        start_time: ~N[2021-08-27 17:15:00],
        qualifiers_period: {~D[2021-06-03], ~D[2021-07-19]},
        min_qualifiers_for_winrate: nil,
        aliases: [],
        display_name: nil,
        swiss_rounds: 8,
        year: 2021
      },
      %__MODULE__{
        id: :Stormwind,
        battlefy_id: "6154604ce73db130628d7563",
        ladder_priority: :timezone,
        ladder_points: nil,
        ladder_seasons: [94, 95],
        ladder_invites: 16,
        region: :US,
        start_time: ~N[2021-10-22 12:15:00],
        qualifiers_period: {~D[2021-07-22], ~D[2021-09-06]},
        min_qualifiers_for_winrate: 20,
        aliases: [],
        display_name: nil,
        swiss_rounds: 8,
        year: 2021
      },
      %__MODULE__{
        id: :Undercity,
        battlefy_id: "6188ed89a422682f8a42a6ab",
        ladder_priority: :timezone,
        ladder_points: nil,
        ladder_seasons: [96],
        ladder_invites: 32,
        region: :AP,
        start_time: ~N[2021-11-19 13:00:00],
        qualifiers_period: {~D[2021-09-09], ~D[2021-10-18]},
        min_qualifiers_for_winrate: 20,
        aliases: [],
        display_name: nil,
        swiss_rounds: 8,
        year: 2021
      },
      %__MODULE__{
        id: :"Masters Tour One",
        battlefy_id: "61fa914887d821355e9372fe",
        ladder_priority: :timezone,
        ladder_points: nil,
        ladder_seasons: [99],
        ladder_invites: 50,
        region: :AP,
        start_time: ~N[2022-02-17 22:15:00],
        qualifiers_period: {~D[2022-01-01], ~D[2022-01-30]},
        min_qualifiers_for_winrate: 10,
        aliases: ["Onyxia's Lair", "Onyxia", "One"],
        display_name: "Onyxia's Lair",
        swiss_rounds: 8,
        year: 2022
      },
      %__MODULE__{
        id: :"Masters Tour Two",
        battlefy_id: "621f5e9ad862666b1acacb9d",
        ladder_priority: :timezone,
        ladder_points: nil,
        ladder_seasons: [100],
        ladder_invites: 50,
        region: :AP,
        start_time: ~N[2022-03-18 14:00:00],
        qualifiers_period: {~D[2022-02-01], ~D[2022-02-28]},
        min_qualifiers_for_winrate: 10,
        aliases: ["Ruins of Alterac", "Alterac", "Two"],
        display_name: "Ruins of Alterac",
        swiss_rounds: 8,
        year: 2022
      },
      %__MODULE__{
        id: :"Masters Tour Three",
        battlefy_id: "624d91cfdcea614f50cfcc50",
        ladder_priority: :timezone,
        ladder_points: nil,
        ladder_seasons: [101],
        ladder_invites: 50,
        region: :AP,
        start_time: ~N[2022-04-29 05:00:00],
        qualifiers_period: {~D[2022-03-01], ~D[2022-03-30]},
        min_qualifiers_for_winrate: 10,
        aliases: ["Voyage to the Sunken City", "Sunken City", "Sunken", "Three"],
        display_name: "Sunken City",
        swiss_rounds: 8,
        year: 2022
      },
      %__MODULE__{
        id: :"Masters Tour Four",
        battlefy_id: "62a851101c699e31f8ec2510",
        ladder_priority: :timezone,
        ladder_seasons: [102],
        ladder_points: nil,
        ladder_invites: 50,
        region: :AP,
        start_time: ~N[2022-06-30 22:15:00],
        qualifiers_period: {~D[2022-04-01], ~D[2022-05-02]},
        min_qualifiers_for_winrate: 10,
        aliases: ["Vashj'ir", "Vashjir"],
        display_name: "Vashj'ir",
        swiss_rounds: 8,
        year: 2022
      },
      %__MODULE__{
        id: :"Masters Tour Five",
        battlefy_id: "62dfd83d5324e12299816774",
        ladder_priority: :timezone,
        ladder_points: nil,
        ladder_seasons: [103],
        ladder_invites: 50,
        region: :AM,
        start_time: ~N[2022-08-12 14:15:00],
        qualifiers_period: {~D[2022-05-04], ~D[2022-05-30]},
        min_qualifiers_for_winrate: 10,
        aliases: ["Murder at Castle Nathria", "Murder", "Nathria", "Castle Nathria"],
        display_name: "Murder",
        swiss_rounds: 8,
        year: 2022
      },
      %__MODULE__{
        id: :"Masters Tour Six",
        battlefy_id: "632c2f3650477e51b2fd7789",
        ladder_priority: :timezone,
        ladder_seasons: [104],
        ladder_invites: 50,
        ladder_points: nil,
        region: :EU,
        start_time: ~N[2022-10-07 08:15:00],
        qualifiers_period: {~D[2022-06-01], ~D[2022-07-30]},
        min_qualifiers_for_winrate: 10,
        aliases: ["The Maw and Disorder", "Maw and Disorder"],
        display_name: "Disorder",
        swiss_rounds: 8,
        year: 2022
      },
      %__MODULE__{
        id: :"Masters Tour 2023_1",
        battlefy_id: "64399a194e7f0e0f9b334be9",
        ladder_priority: nil,
        ladder_seasons: [111, 112, 113],
        ladder_invites: nil,
        ladder_points: [
          {{1, 1}, 8},
          {{2, 5}, 7},
          {{6, 10}, 6},
          {{11, 20}, 5},
          {{21, 30}, 4},
          {{31, 40}, 3},
          {{41, 50}, 2},
          {{51, 100}, 1}
        ],
        region: :EU,
        start_time: ~N[2023-04-21 16:00:00],
        qualifiers_period: {~D[2023-03-01], ~D[2022-03-01]},
        min_qualifiers_for_winrate: nil,
        aliases: [],
        display_name: "MT Spring Championship",
        swiss_rounds: 0,
        year: 2023
      },
      %__MODULE__{
        id: :"Masters Tour 2023_2",
        battlefy_id: "64d1c90aa7f1f73b08054d38",
        ladder_priority: nil,
        ladder_seasons: [114, 115, 116],
        ladder_invites: nil,
        ladder_points: [
          {{1, 1}, 8},
          {{2, 5}, 7},
          {{6, 10}, 6},
          {{11, 20}, 5},
          {{21, 30}, 4},
          {{31, 40}, 3},
          {{41, 50}, 2},
          {{51, 100}, 1}
        ],
        region: :EU,
        start_time: ~N[2023-08-19 16:00:00],
        qualifiers_period: {~D[2023-06-01], ~D[2022-06-01]},
        min_qualifiers_for_winrate: nil,
        aliases: [],
        display_name: "MT Summer Championship",
        swiss_rounds: 0,
        year: 2023
      },
      %__MODULE__{
        id: :"Masters Tour 2023_3",
        battlefy_id: "653708cd1138c96e02a38e28",
        ladder_priority: nil,
        ladder_seasons: [117, 118, 119],
        ladder_invites: nil,
        ladder_points: [
          {{1, 1}, 8},
          {{2, 5}, 7},
          {{6, 10}, 6},
          {{11, 20}, 5},
          {{21, 30}, 4},
          {{31, 40}, 3},
          {{41, 50}, 2},
          {{51, 100}, 1}
        ],
        region: :EU,
        start_time: ~N[2023-10-28 16:00:00],
        qualifiers_period: {~D[2023-09-01], ~D[2022-09-01]},
        min_qualifiers_for_winrate: nil,
        aliases: [],
        display_name: "MT Fall Championship",
        swiss_rounds: 0,
        year: 2023
      },
      %__MODULE__{
        id: :"Masters Tour 2024_1",
        battlefy_id: "66104524c69b9f10c243d1fa",
        ladder_priority: nil,
        ladder_seasons: [124, 125],
        ladder_invites: nil,
        ladder_points: [
          {{1, 1}, 8},
          {{2, 5}, 7},
          {{6, 10}, 6},
          {{11, 20}, 5},
          {{21, 30}, 4},
          {{31, 40}, 3},
          {{41, 50}, 2},
          {{51, 100}, 1}
        ],
        region: :EU,
        start_time: ~N[2024-04-12 16:00:00],
        qualifiers_period: {~D[2023-03-01], ~D[2022-03-01]},
        min_qualifiers_for_winrate: nil,
        aliases: [],
        display_name: "MT Spring Championship",
        swiss_rounds: 0,
        year: 2024
      },
      %__MODULE__{
        id: :"Masters Tour 2024_2",
        battlefy_id: "66b25ac6aedcd30040d10543",
        ladder_priority: nil,
        ladder_seasons: [128, 129],
        ladder_invites: nil,
        ladder_points: [
          {{1, 1}, 8},
          {{2, 5}, 7},
          {{6, 10}, 6},
          {{11, 20}, 5},
          {{21, 30}, 4},
          {{31, 40}, 3},
          {{41, 50}, 2},
          {{51, 100}, 1}
        ],
        region: :EU,
        start_time: ~N[2024-08-15 16:00:00],
        qualifiers_period: {~D[2023-06-01], ~D[2022-06-01]},
        min_qualifiers_for_winrate: nil,
        aliases: [],
        display_name: "MT Summer Championship",
        swiss_rounds: 0,
        year: 2024
      },
      %__MODULE__{
        id: :"Masters Tour 2025_1",
        battlefy_id: "6840e6e5158cc10018215c79",
        ladder_priority: nil,
        ladder_seasons: [137, 138],
        ladder_invites: nil,
        ladder_points: [
          {{1, 1}, 7},
          {{2, 5}, 6},
          {{6, 10}, 5},
          {{11, 25}, 4},
          {{26, 50}, 3},
          {{51, 75}, 2},
          {{76, 100}, 1}
        ],
        region: :EU,
        start_time: ~N[2025-06-06 16:00:00],
        qualifiers_period: {~D[2025-03-01], ~D[2025-03-01]},
        min_qualifiers_for_winrate: nil,
        aliases: [],
        display_name: "MT Spring Championship",
        swiss_rounds: 0,
        year: 2025
      },
      %__MODULE__{
        id: :"Masters Tour 2025_2",
        battlefy_id: nil,
        ladder_priority: nil,
        ladder_seasons: [140, 141],
        ladder_invites: nil,
        ladder_points: [
          {{1, 1}, 7},
          {{2, 5}, 6},
          {{6, 10}, 5},
          {{11, 25}, 4},
          {{26, 50}, 3},
          {{51, 75}, 2},
          {{76, 100}, 1}
        ],
        region: :EU,
        start_time: ~N[2025-09-15 16:00:00],
        qualifiers_period: {~D[2025-06-01], ~D[2025-06-01]},
        min_qualifiers_for_winrate: nil,
        aliases: [],
        display_name: "MT Summer Championship",
        swiss_rounds: 0,
        year: 2025
      },
      %__MODULE__{
        id: :"Worlds 2025",
        battlefy_id: nil,
        ladder_priority: nil,
        ladder_seasons: [143, 144],
        ladder_invites: nil,
        ladder_points: [
          {{1, 1}, 7},
          {{2, 5}, 6},
          {{6, 10}, 5},
          {{11, 25}, 4},
          {{26, 50}, 3},
          {{51, 75}, 2},
          {{76, 100}, 1}
        ],
        region: :EU,
        start_time: ~N[2025-08-15 16:00:00],
        qualifiers_period: {~D[2025-06-01], ~D[2025-06-01]},
        min_qualifiers_for_winrate: nil,
        aliases: [],
        display_name: "Worlds 2025",
        swiss_rounds: 0,
        year: 2025
      }
    ]
  end

  def get_by(attr, value) do
    all()
    |> Enum.find(&(value == &1 |> Map.get(attr)))
  end

  def get(tour_stop, attr, default \\ nil)
  def get(ts = %__MODULE__{}, attr, default), do: Map.get(ts, attr, default)

  def get(tour_stop, attr, default)
      when (is_tour_stop(tour_stop) or is_binary(tour_stop)) and is_atom(attr) do
    case get(tour_stop) do
      ts = %{id: _} -> Map.get(ts, attr, default)
      _ -> default
    end
  end

  def get(_, _, default), do: default

  def get_battlefy_id(tour_stop) when is_tour_stop(tour_stop) do
    id_unknown = {:error, "ID unknown for tour stop #{tour_stop}}"}

    case get(tour_stop) do
      nil -> {:error, "Unknown tour stop #{tour_stop}"}
      %{battlefy_id: battlefy_id} when is_binary(battlefy_id) -> {:ok, battlefy_id}
      _ -> id_unknown
    end
  end

  def get_battlefy_id!(tour_stop), do: get_battlefy_id(tour_stop) |> Util.bangify()

  @doc """
  Gets the tour stop a ladder season qualifies for

  ## Example
    iex> Backend.MastersTour.TourStop.get_id_for_season(72)
    {:ok, :Arlington}
    iex> Backend.MastersTour.TourStop.get_id_for_season(79)
    {:ok, :"Asia-Pacific"}
  """
  @spec get_id_for_season(integer()) :: {:ok, Blizzard.tour_stop()} | {:error, String.t()}
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def get_id_for_season(season_id) when is_integer(season_id) do
    all()
    |> Enum.find(fn ts -> Enum.member?(ts.ladder_seasons, season_id) end)
    |> case do
      %{id: id} -> {:ok, id}
      _ -> {:error, "No tour stop for ladder season #{season_id}"}
    end
  end

  def get_id_for_season!(season_id), do: Util.bangify(get_id_for_season(season_id))

  def get(ts = %__MODULE__{}), do: ts

  def get(tour_stop) when is_tour_stop(tour_stop) do
    all()
    |> Enum.find(fn ts -> ts.id == tour_stop end)
  end

  def get(tour_stop) when is_binary(tour_stop) do
    all()
    |> Enum.find(fn
      ts ->
        to_string(ts.id) == tour_stop ||
          String.downcase(tour_stop) in Enum.map(ts.aliases, &String.downcase/1)
    end)
  end

  def get(_), do: nil

  @spec display_name(t()) :: String.t() | nil
  def display_name(%{display_name: name}) when is_binary(name), do: name
  def display_name(%{id: id}), do: to_string(id)

  def display_name(tour_stop) when is_binary(tour_stop) or is_atom(tour_stop) do
    case get(tour_stop) do
      ts = %{id: _} -> display_name(ts)
      _ -> nil
    end
  end

  def display_name(_), do: nil

  def get_current(hours_before_start \\ 24, hours_after_start \\ 96) do
    all()
    |> Enum.find_value(fn ts ->
      ts |> current?(hours_before_start, hours_after_start) && ts.id
    end)
  end

  @spec current?(t(), hours_before_start :: integer(), hours_after_start :: integer()) :: boolean
  def current?(tour_stop, hours_before_start \\ 1, hours_after_start \\ 96)
  def current?(%{start_time: nil}, _, _), do: false

  def current?(%{start_time: start_time}, hours_before_start, hours_after_start) do
    now = NaiveDateTime.utc_now()
    lower = NaiveDateTime.add(start_time, hours_before_start * -3600)
    upper = NaiveDateTime.add(start_time, hours_after_start * 3600)
    Util.in_range?(now, {lower, upper})
  end

  @spec started?(atom | String.t() | Backend.MastersTour.TourStop.t()) :: boolean
  def started?(%{start_time: start_time}),
    do: NaiveDateTime.compare(start_time, NaiveDateTime.utc_now()) == :lt

  def started?(tour_stop) when is_atom(tour_stop) or is_binary(tour_stop),
    do: tour_stop |> get() |> started?()

  def get_year(tour_stop), do: get(tour_stop, :year)

  @spec get_by_ladder(integer()) :: {:ok, atom} | {:error, String.t()}
  def get_by_ladder(season_id) do
    all()
    |> Enum.find(&(season_id in &1.ladder_seasons))
    |> case do
      %{id: id} -> {:ok, id}
      _ -> {:error, "Invalid tour stop for ladder"}
    end
  end

  def ladder_invites(tour_stop), do: get(tour_stop, :ladder_invites, 0)

  @spec get_current_qualifiers() :: __MODULE__.t() | nil
  def get_current_qualifiers() do
    now = Date.utc_today()

    all()
    |> Enum.find(fn %{qualifiers_period: {start_date, end_date}} ->
      Date.compare(now, start_date) != :lt &&
        Date.compare(now, end_date) != :gt
    end)
  end

  @spec get_current_qualifiers(:id) :: Blizzard.tour_stop() | nil
  def get_current_qualifiers(:id) do
    get_current_qualifiers()
    |> case do
      %{id: id} -> id
      _ -> nil
    end
  end

  def get_next() do
    all()
    |> Enum.find(&(!started?(&1)))
  end

  def get_start_time(ts) when is_binary(ts) or is_atom(ts), do: ts |> get() |> get_start_time()
  def get_start_time(%{start_time: start_time}), do: start_time
  def get_start_time(_), do: nil

  def gm_point_system(%{year: 2020}), do: {:ok, :earnings_2020}
  def gm_point_system(%{year: 2021}), do: {:ok, :points_2021}
  def gm_point_system(_), do: {:error, :no_point_system}

  @spec equal?(any, any) :: boolean
  def equal?(first, second) do
    get(first) == get(second) && get(first) != nil
  end
end
