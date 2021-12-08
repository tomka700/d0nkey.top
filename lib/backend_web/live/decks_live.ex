defmodule BackendWeb.DecksLive do
  @moduledoc false
  use Surface.LiveView
  alias Backend.Blizzard
  alias Backend.Hearthstone.Deck
  alias Components.DeckWithStats
  alias Components.Filter.PlayableCardSelect
  alias Components.LivePatchDropdown
  alias Hearthstone.DeckTracker
  alias Hearthstone.Enums.Format
  alias BackendWeb.Router.Helpers, as: Routes
  alias Components.ClassStatsModal
  import BackendWeb.LiveHelpers

  @default_limit 15
  @max_limit 30
  @min_min_games 50
  @default_min_games 100
  # standard
  @default_format 2
  @default_order_by "winrate"
  data(user, :any)
  data(filters, :map)
  def mount(_params, session, socket), do: {:ok, socket |> assign_defaults(session)}

  def render(assigns) do
    filters =
      assigns.filters
      |> ensure_required(["limit", "min_games", "format", "order_by", "period", "rank"])
      |> cap_param("limit", @max_limit)
      |> floor_param("min_games", @min_min_games)

    deck_stats = DeckTracker.deck_stats(filters)

    ~F"""
    <Context put={user: @user} >
      <div class="container">
        <div class="title is-2">Decks</div>
        <div class="subtitle is-6">
        To contribute use <a href="https://www.firestoneapp.com/">Firestone</a>
        </div>

        <LivePatchDropdown
          options={format_options()}
          title={"Format"}
          param={"format"}
          url_params={@filters}
          selected_params={filters}
          normalizer={&to_string/1}
          live_view={__MODULE__} />
        <LivePatchDropdown
          options={rank_options()}
          title={"Rank"}
          param={"rank"}
          url_params={@filters}
          selected_params={filters}
          live_view={__MODULE__} />

        <LivePatchDropdown
          options={period_options()}
          title={"Period"}
          param={"period"}
          url_params={@filters}
          selected_params={filters}
          live_view={__MODULE__} />

        <LivePatchDropdown
          options={limit_options()}
          title={"Decks"}
          param={"limit"}
          selected_as_title={false}
          url_params={@filters}
          selected_params={filters}
          normalizer={&to_string/1}
          live_view={__MODULE__} />

        <LivePatchDropdown
          options={class_options("Any Class")}
          title={"Class"}
          param={"player_class"}
          url_params={@filters}
          selected_params={filters}
          live_view={__MODULE__} />

        <LivePatchDropdown
          options={class_options("Any Opponent")}
          title={"Opponent Class"}
          param={"opponent_class"}
          url_params={@filters}
          selected_params={filters}
          live_view={__MODULE__} />


        <LivePatchDropdown
          options={min_games_options()}
          title={"Min Games"}
          param={"min_games"}
          selected_as_title={false}
          url_params={@filters}
          selected_params={filters}
          normalizer={&to_string/1}
          live_view={__MODULE__} />

        <LivePatchDropdown
          options={order_by_options()}
          title={"Order By"}
          param={"order_by"}
          url_params={@filters}
          selected_params={filters}
          live_view={__MODULE__} />

        <PlayableCardSelect id={"player_deck_includes"} update_fun={update_cards(@filters, "player_deck_includes")} selected={filters["player_deck_includes"] || []} title="Include cards"/>
        <PlayableCardSelect id={"player_deck_excludes"} update_fun={update_cards(@filters, "player_deck_excludes")} selected={filters["player_deck_excludes"] || []} title="Exclude cards"/>
        <ClassStatsModal class="dropdown" id="class_stats_modal" get_stats={fn -> filters |> class_stats_filters() |> DeckTracker.class_stats() end} title="As Class" />
        <ClassStatsModal class="dropdown" id="opponent_class_stats_modal" get_stats={fn -> filters |> class_stats_filters() |> DeckTracker.opponent_class_stats() end} title={"Vs Class"}/>
        <br>
        <br>

        <div class="columns is-multiline is-mobile is-narrow is-centered">
          <div :for={deck_with_stats <- deck_stats} class="column is-narrow">
            <DeckWithStats deck_with_stats={deck_with_stats} />
          </div>
          <div :if={!(Enum.any?(deck_stats))} >
            <br>
            <br>
            <br>
            <br>
            No decks available for these filters
          </div>
        </div>
      </div>
    </Context>
    """
  end

  defp class_stats_filters(filters), do: Map.delete(filters, "min_games") |> Map.delete("order_by")
  defp update_cards(params, param) do
    fn val ->
      new_params = Map.put(params, param, val)
      Process.send_after(self(), {:update_params, new_params}, 0)
    end
  end

  def handle_info({:update_params, params}, socket) do
    {:noreply, push_patch(socket, to: Routes.live_path(socket, __MODULE__, params))}
  end

  def rank_options(), do: [{"legend", "Legend"}, {"diamond_to_legend", "Diamond-Legend"}, {"all", "All"}]
  def period_options(), do: [{"past_30_days", "Past 30 Days"}, {"past_2_weeks", "Past 2 Weeks"}, {"past_week", "Past Week"}, {"past_day", "Past Day"}, {"past_3_days", "Past 3 Days"}, {"alterac_valley", "Alterac Valley"}]
  def limit_options(), do: [10, 15, 20, 25, 30]
  def class_options(any_name \\ "Any"), do: [{nil, any_name} | Enum.map(Deck.classes(), & {&1, Deck.class_name(&1)})]
  def format_options(), do:
    Enum.map(Format.all(), fn {id, name} ->
      {to_string(id), name}
    end)
  def region_options(), do:
    [
      {nil, "All Regions"}
      | Enum.map(Blizzard.regions(), & {to_string(&1), Blizzard.get_region_name(&1, :long)})
    ]
  def min_games_options(), do: [50, 100, 200, 400, 800, 1600, 3200]
  def order_by_options(), do: [{"winrate", "Winrate %"}, {"total", "Total Games"}]



  def handle_event("deck_copied", _, socket), do: {:noreply, socket}

  def handle_params(params, _uri, socket) do
    filters = extract_filters(params)
    {:noreply, assign(socket, :filters, filters)}
  end

  def extract_filters(params) do
    params
    |> Map.take(["rank", "period", "limit", "order_by", "player_class", "opponent_class", "format", "offset", "region", "min_games", "player_deck_includes", "player_deck_excludes"])
    |> parse_int(["limit", "min_games", "format", "offset", "player_deck_includes", "player_deck_excludes"])
  end

  defp parse_int(params, to_parse) when is_list(to_parse), do:
    Enum.reduce(to_parse, params, &parse_int(&2, &1))

  defp parse_int(params, param) do
    curr = Map.get(params, param)
    new_val = if is_list(curr) do
      Enum.map(curr, &Util.to_int_or_orig/1)
    else
      Util.to_int_or_orig(curr)
    end

    if new_val && new_val != curr do
      Map.put(params, param, new_val)
    else
      params
    end
  end

  defp ensure_required(params, required), do: Enum.reduce(required, params, & ensure(&2, &1))
  defp ensure(params, "min_games"), do: Map.put_new(params, "min_games", @default_min_games)
  defp ensure(params, "limit"), do: Map.put_new(params, "limit", @default_limit)
  defp ensure(params, "format"), do: Map.put_new(params, "format", @default_format)
  defp ensure(params, "period"), do: Map.put_new(params, "period", default_period())
  defp ensure(params, "rank"), do: Map.put_new(params, "rank", "diamond_to_legend")
  defp ensure(params, "order_by"), do: Map.put_new(params, "order_by", @default_order_by)

  defp default_period() do
    case {alterac_valley_out?(), week_past_alterac_valley?()} do
      {true, false} -> "alterac_valley"
      _ -> "past_week"
    end
  end

  defp week_past_alterac_valley?() do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.add(-7 * 24 * 60 * 60, :second)
    |> NaiveDateTime.compare(~N[2021-12-07 18:00:00])
    |> case do
      :lt -> false
      _ -> true
    end
  end
  defp alterac_valley_out?() do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.compare(~N[2021-12-08 02:00:00])
    |> case do
      :lt -> false
      _ -> true
    end
  end


  defp cap_param(params, param, max),
    do: limit_param(params, param, max, &Kernel.>/2)

  defp floor_param(params, param, min),
    do: limit_param(params, param, min, &Kernel.</2)

  defp limit_param(params, param, limit, limiter) do
    curr = Map.get(params, param)
    if curr && limiter.(curr, limit) do
      Map.put(params, param, limit)
    else
      params
    end
  end

end
