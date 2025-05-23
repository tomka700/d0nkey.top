defmodule BackendWeb.BattlefyView do
  require Logger
  use BackendWeb, :view
  alias Backend.MastersTour
  alias Backend.Battlefy
  alias Backend.Battlefy.Organization
  alias Backend.Battlefy.Match
  alias Backend.Battlefy.MatchTeam
  alias Backend.MastersTour
  alias Backend.Battlenet.Battletag
  alias Backend.UserManager.User
  import FunctionComponents.Battlefy

  @type future_opponent_team :: %{
          name: String.t(),
          yaytears: String.t(),
          hsdeckviewer: String.t(),
          decks: any(),
          link: String.t()
        }

  @type standings :: %{
          place: String.t(),
          name: String.t(),
          name_link: String.t(),
          has_score: boolean,
          score: String.t(),
          wins: integer,
          losses: integer,
          hsdeckviewer: String.t(),
          yaytears: String.t()
        }

  @spec handle_opponent_team(Battlefy.MatchTeam.t(), Map.t()) ::
          nil
  def handle_opponent_team(%{team: nil}, _) do
    nil
  end

  @spec handle_opponent_team(Battlefy.MatchTeam.t(), Map.t()) :: future_opponent_team
  def handle_opponent_team(
        %{team: %{name: name}},
        %{
          tournament: %{id: tournament_id},
          conn: conn,
          all_deckcodes: all_deckcodes
        } = params
      ) do
    decks =
      case Map.get(all_deckcodes, name) do
        nil ->
          ""

        codes ->
          live_render(conn, BackendWeb.CompactLineupOnly, session: %{"extra_decks" => codes})
      end

    query_params =
      case Map.get(params, :stage_id) do
        stage_id when is_binary(stage_id) -> %{stage_id: stage_id}
        _ -> %{}
      end

    %{
      name: name,
      yaytears: Backend.Yaytears.create_deckstrings_link(tournament_id, name),
      decks: decks,
      hsdeckviewer: ~p"/battlefy/tournament/#{tournament_id}/decks/#{name}",
      link: ~p"/battlefy/tournament/#{tournament_id}/future/#{name}?#{query_params}"
    }
  end

  def create_organization_dropdown(conn, org) do
    options =
      Battlefy.hardcoded_organizations()
      |> Enum.map(fn o ->
        %{
          selected: org && org.id == o.id,
          display: o |> Organization.display_name(),
          link:
            Routes.battlefy_path(
              conn,
              :organization_tournaments,
              Map.put(conn.query_params, "slug", o.slug)
            )
        }
      end)
      |> Enum.sort_by(fn d -> d.display end, :asc)

    {options, "Choose Organization"}
  end

  def create_daterange_dropdown(conn, {from, to}) do
    options =
      [{:week, "Week"}, {:month, "Month"}, {:year, "Year"}]
      |> Enum.map(fn {r, display} ->
        range = {f, t} = Util.get_range(r)

        %{
          selected: f == from && t == to,
          display: display,
          link: create_org_tour_link(range, conn)
        }
      end)

    {options, "Select Range"}
  end

  def render("tournament_table.html", params = %{conn: conn, raw: raw}) do
    slug = fn t -> (t.organization && t.organization.slug) || params[:slug] end

    tournaments =
      raw
      |> Enum.map(fn t ->
        t
        |> Map.put_new(:link, Battlefy.create_tournament_link(t.slug, t.id, t |> slug.()))
        |> Map.put_new(:standings_link, Routes.battlefy_path(conn, :tournament, t.id))
        |> Map.put_new(:yaytears, Backend.Yaytears.create_tournament_link(t.id))
      end)

    render("tournament_table.html", %{tournaments: tournaments})
  end

  def render("organization_tournaments.html", %{
        from: from,
        to: to,
        tournaments: tour,
        org: org,
        conn: conn
      }) do
    range = {from, to}
    {before_range, after_range} = Util.get_surrounding_ranges(range)
    before_link = create_org_tour_link(before_range, conn)
    after_link = create_org_tour_link(after_range, conn)

    title =
      case org do
        nil ->
          "Choose organization"

        o ->
          assigns = %{
            link: Organization.create_link(o),
            name: o.name
          }

          ~H"""
          <a class="is-link" href={@link}> <%= @name %> </a>
          """
      end

    dropdowns =
      [
        create_organization_dropdown(conn, org),
        create_daterange_dropdown(conn, range)
      ]
      |> add_stats_dropdown(conn, org)

    render("organization_tournaments.html", %{
      title: title,
      before_link: before_link,
      after_link: after_link,
      tournaments: tour || [],
      slug: org && org.slug,
      dropdowns: dropdowns,
      conn: conn
    })
  end

  def render("class_match_stats.html", %{class: _class, bans: 1} = assigns) do
    ~H"""
    <img class="image is-32x32" style="opacity:0.2;" src={class_url(@class)}>
    """
  end

  def render(
        "profile.html",
        params = %{
          tournament: tournament,
          opponent_matches: opponent_matches,
          deckcodes: deckcodes_raw,
          team_name: team_name,
          conn: conn
        }
      ) do
    winner_opponent =
      prepare_future_opponents(opponent_matches.winner, params, tournament)
      |> render_future_opponents("Winner's Future Opponents")

    loser_opponent =
      prepare_future_opponents(opponent_matches.loser, params, tournament)
      |> render_future_opponents("Loser's Future Opponents")

    waiting_opponent =
      prepare_future_opponents(opponent_matches.waiting, params, tournament)
      |> render_future_opponents("Next Opponents")

    {player, class_stats_raw} = handle_player_matches(params)
    hsdeckviewer = Routes.battlefy_path(conn, :tournament_decks, tournament.id, team_name)
    yaytears = Backend.Yaytears.create_deckstrings_link(tournament.id, team_name)
    class_stats = class_stats_raw |> Enum.map(fn {_k, v} -> v end)

    deckcodes = Enum.filter(deckcodes_raw, &Backend.Hearthstone.Deck.valid?/1)

    standings_link_params =
      if params[:stage_id] do
        [stage_id: params[:stage_id]]
      else
        []
      end

    render(
      "future_opponents.html",
      %{
        conn: conn,
        winner_future: winner_opponent,
        loser_future: loser_opponent,
        waiting_future: waiting_opponent,
        show_player: player |> Enum.any?(),
        player_matches: player,
        team_name: team_name,
        hsdeckviewer: hsdeckviewer,
        deckcodes: deckcodes,
        tournament: tournament,
        class_stats: class_stats,
        show_class_stats: class_stats |> Enum.count() > 0,
        standings_link:
          Routes.battlefy_path(conn, :tournament, tournament.id, standings_link_params),
        yaytears: yaytears
      }
      |> add_stage_attrs(
        tournament,
        params[:stage_id],
        &Routes.battlefy_path(conn, :tournament_player, tournament.id, team_name, %{stage_id: &1})
      )
    )
  end

  def render("class_match_stats.html", %{class: class, bans: 0, wins: wins, losses: losses}) do
    {offset, border_css} = build_box_shadow(wins, losses)
    size = 32 - offset

    assigns = %{
      image_url: class_url(class),
      style: border_css <> "height: #{size}px; width: #{size}px; margin: 3px #{offset}px;"
    }

    ~H"""
    <figure class="image is-rounded">
      <img class="image is-rounded" style={@style} src={@image_url} />
    </figure>
    """
  end

  def render("tournaments_stats.html", p = %{conn: conn, tournaments: tournaments}) do
    tournaments_string =
      tournaments
      |> Enum.map_join("\n", fn %{name: name, id: id} ->
        "#{id} # #{name}"
      end)

    assigns = %{
      edit_tournaments_link:
        Routes.battlefy_path(conn, :tournaments_stats, %{edit: tournaments_string})
    }

    table_params =
      p
      |> Map.put(
        :link_creator,
        fn params ->
          Routes.battlefy_path(conn, :tournament_stats, conn.query_params |> Map.merge(params))
        end
      )
      |> Map.put(
        :dropdown_row,
        ~H"""
        <a href={@edit_tournaments_link} class="is-link button">← Edit tournaments</a>
        """
      )

    title = p[:title] || "Custom Tournaments Stats"
    render("tournaments_stats.html", %{conn: conn, table_params: table_params, title: title})
  end

  def render("tournaments_stats_input.html", %{conn: conn, edit: edit}) do
    self_link = Routes.battlefy_path(conn, :tournaments_stats)

    render("tournaments_stats_input.html", %{
      c: conn,
      self_link: self_link,
      title: "Tournament Stats",
      edit: edit
    })
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def render(
        "tournament.html",
        params = %{standings_raw: _}
      ) do
    new_params =
      params
      |> put_param(:ongoing, &calculate_ongoing/1)
      |> put_param(:is_tour_stop, &tour_stop?/1)
      |> Map.put(:use_countries, true)
      |> handle_standings()
      |> handle_highlights()
      |> put_param(:user_subtitle, &user_subtitle/1)
      |> put_param(:subtitle, &tournament_subtitle/1)
      |> put_param(:player_options, &create_player_options/1)
      |> put_param(:dropdowns, &create_tournament_dropdowns/1)
      |> put_param(:streams_subtitle, &create_streams_subtitle/1)
      |> put_param(:explore_decks, &create_explore_decks/1)
      |> add_tournament_stage_attrs()
      |> Kernel.then(fn p ->
        Map.merge(p, %{
          link: Battlefy.create_tournament_link(p.tournament),
          manage_stream_button: manage_stream_button(params),
          name: p.tournament.name,
          show_invited: MapSet.size(p.invited_mapset) > 0,
          show_decks: Enum.any?(p.lineups),
          show_score: Enum.any?(p.standings, fn s -> s.has_score end)
        })
      end)

    Logger.debug("preparing to render")

    render(
      "tournament.html",
      new_params
    )
  end

  def render("user_tournaments.html", %{
        slug: slug,
        page: page,
        tournaments: tournaments,
        conn: conn
      }) do
    render(
      "user_tournaments.html",
      %{
        title: "#{slug}'s Battlefy Tournaments",
        subtitle: "Public tournaments only",
        tournaments: tournaments,
        conn: conn,
        slug: slug,
        prev_button: prev_button(conn, page - 1, slug),
        next_button: next_button(conn, page + 1, slug)
      }
    )
  end

  defp put_param(params, key, func) do
    Map.put(params, key, func.(params))
  end

  defp add_tournament_stage_attrs(params) do
    add_stage_attrs(
      params,
      &Routes.battlefy_path(
        params.conn,
        :tournament,
        params.tournament.id,
        %{stage_id: &1}
      )
    )
  end

  defp create_explore_decks(assigns) do
    ~H"""
    <%= if @has_lineups do %>
      <a class="link" href={~p"/battlefy/tournament/#{@tournament.id}/lineups"}>Lineups</a>
      | <a class="link" href={~p"/tournament-lineups/battlefy/#{@tournament.id}/popularity"}>Popularity</a>
      | <a class="link" href={~p"/tournament-lineups/battlefy/#{@tournament.id}/stats"}>Winrate</a>
      |
    <% end %>
    <%= if !@has_lineups and @tournament.id == "66104524c69b9f10c243d1fa" do %>
      <a class="link" href={~p"/tournament-lineups/masters_tour/Spring2024"}>Lineups (Draft)</a>
      |
    <% end %>
    """
  end

  defp create_streams_subtitle(assigns) do
    ~H"""
    <%= streams_subtitle(@tournament)%>
    <%= if Enum.any?(@other_streams) do %>
      <a href={"/streaming-now?for_tournament=battlefy|#{@tournament.id}"}>Other Streams</a>
      |
    <% end %>
    """
  end

  defp manage_stream_button(%{conn: conn, tournament: %{id: id}}) do
    with user = %User{} <- BackendWeb.AuthUtils.user(conn),
         true <- User.streamer?(user) do
      assigns = %{user: user, conn: conn, id: id}

      ~H"""
        <%= live_render(@conn, BackendWeb.TournamentStreamManagerModalOnlyLive, session: %{"tournament_source" => "battlefy", "tournament_id" => @id}) %>
      """
    end
  end

  defp manage_stream_button(_), do: nil

  defp streams_subtitle(%{streams: streams}) when is_list(streams) do
    twitch_streams =
      Enum.filter(streams, &Backend.Battlefy.Tournament.Stream.twitch?/1)
      |> Enum.map(& &1.link)
      |> Enum.uniq()

    assigns = %{twitch_streams: twitch_streams}

    ~H"""
    <%= for stream <- @twitch_streams do %>
        <a href={stream} class="dropdown">
            <img style="height: 20px;" class="image" alt="Twitch" src="/images/brands/twitch_extruded_wordmark_purple.svg"/>
        </a>
        |
    <% end %>
    """
  end

  defp streams_subtitle(_), do: nil

  defp handle_highlights(params) do
    highlight = if params.highlight == nil, do: [], else: params.highlight
    country_highlight = if params.country_highlight == nil, do: [], else: params.country_highlight
    fantasy_highlight = if params.highlight_fantasy, do: params.fantasy_picks, else: []

    highlighted_standings =
      params.standings
      |> Enum.filter(fn s ->
        highlight |> Enum.member?(s.name) ||
          highlight |> Enum.member?(s.name |> Battletag.shorten()) ||
          (s.country != nil && country_highlight |> Enum.member?(s.country)) ||
          fantasy_highlight |> Enum.member?(s.name) ||
          fantasy_highlight |> Enum.member?(s.name |> Battletag.shorten())
      end)

    params
    |> Map.put(:highlighted_standings, highlighted_standings)
    |> Map.put(:highlight, highlight)
    |> Map.put(:selected_countries, country_highlight)
  end

  defp add_stage_attrs(attrs = %{tournament: tournament, stage_id: stage_id}, create_link),
    do: add_stage_attrs(attrs, tournament, stage_id, create_link)

  defp add_stage_attrs(attrs, tournament, stage_id, create_link) do
    stages =
      (tournament.stages || [])
      |> Enum.map(fn s ->
        %{
          name: s.name,
          link: create_link.(s.id),
          selected: stage_id == s.id
        }
      end)

    selected_stage = stages |> Enum.find_value(fn s -> s.selected && s end)

    attrs
    |> Map.merge(%{
      stages: stages,
      show_stage_selection: Enum.count(stages) > 1,
      stage_selection_text:
        if(selected_stage == nil, do: "Select Stage", else: selected_stage.name)
    })
  end

  def add_stats_dropdown(dropdowns, _, nil), do: dropdowns

  def add_stats_dropdown(dropdowns, conn, org) do
    case org.slug |> Battlefy.organization_stats() do
      stats_configs = [_ | _] ->
        options =
          stats_configs
          |> Enum.map(fn %{title: title, stats_slug: ss} ->
            %{
              selected: false,
              display: title,
              link: Routes.battlefy_path(conn, :organization_tournament_stats, ss)
            }
          end)

        dropdowns ++ [{options, "Stats"}]

      _ ->
        dropdowns
    end
  end

  def create_org_tour_link(range, conn) do
    new_params = conn.query_params |> Util.update_from_to_params(range)
    Routes.battlefy_path(conn, :organization_tournaments, new_params)
  end

  def handle_player_matches(
        %{
          player_matches: player_matches,
          team_name: team_name,
          tournament: tournament,
          conn: _conn
        } = params
      ) do
    player_matches
    |> Enum.map_reduce(%{}, fn match = %{top: top, bottom: bottom, round_number: rn}, acc ->
      {player, opponent, player_place, opponent_place} =
        case {top.team, bottom.team} do
          {%{name: ^team_name}, _} ->
            {top, bottom || Battlefy.MatchTeam.empty(), :top, :bottom}

          {_, %{name: ^team_name}} ->
            {bottom, top || Battlefy.MatchTeam.empty(), :bottom, :top}

          _ ->
            Logger.warning("No team is the players team, wtf #{top.team} #{bottom.team}")
            {Battlefy.MatchTeam.empty(), Battlefy.MatchTeam.empty(), nil, nil}
        end

      class_stats = Match.create_class_stats(match, player_place)
      opponent_class_stats = Match.create_class_stats(match, opponent_place)

      {
        %{
          score: "#{player.score} - #{opponent.score} ",
          match_url:
            Routes.live_path(
              BackendWeb.Endpoint,
              BackendWeb.BattlefyMatchLive,
              tournament.id,
              match.id
            ),
          opponent: handle_opponent_team(opponent, params),
          class_stats: class_stats,
          opponent_class_stats: opponent_class_stats,
          current_round: rn
        },
        class_stats
        |> Battlefy.ClassMatchStats.merge_collections(acc)
      }
    end)
  end

  @spec calculate_ongoing(%{
          matches: [Match.t()],
          show_ongoing: boolean,
          tournament: Battlefy.Tournament.t(),
          conn: Plug.Conn.t()
        }) :: Map.t()
  defp calculate_ongoing(
         params = %{
           matches: matches,
           show_ongoing: true,
           tournament: tournament,
           conn: conn
         }
       ) do
    matches
    |> Enum.filter(&Match.ongoing?/1)
    |> Enum.flat_map(fn m = %{top: t, bottom: b} ->
      [
        {
          t |> MatchTeam.get_name(),
          %{
            score: "#{t.score} - #{b.score}",
            match_url:
              Routes.live_path(
                BackendWeb.Endpoint,
                BackendWeb.BattlefyMatchLive,
                tournament.id,
                m.id
              ),
            opponent: b |> MatchTeam.get_name(),
            opponent_link:
              Routes.battlefy_path(
                conn,
                :tournament_player,
                tournament.id,
                b |> MatchTeam.get_name() || "",
                stage_query_param(params)
              )
          }
        },
        {
          b |> MatchTeam.get_name(),
          %{
            score: "#{b.score} - #{t.score}",
            match_url:
              Routes.live_path(
                BackendWeb.Endpoint,
                BackendWeb.BattlefyMatchLive,
                tournament.id,
                m.id
              ),
            opponent: t |> MatchTeam.get_name(),
            opponent_link:
              if t |> MatchTeam.get_name() do
                Routes.battlefy_path(
                  conn,
                  :tournament_player,
                  tournament.id,
                  t |> MatchTeam.get_name(),
                  stage_query_param(params)
                )
              else
                nil
              end
          }
        }
      ]
    end)
    |> Map.new()
  end

  defp calculate_ongoing(_), do: Map.new()

  defp stage_query_param(%{stage_id: stage_id}) when is_binary(stage_id),
    do: %{stage_id: stage_id}

  # at least two stages. don't wanna add it if there is 1 stage
  defp stage_query_param(%{tournament: %{stages: [_ | [_ | _]]}, standings_stage_id: stage_id}) do
    %{stage_id: stage_id}
  end

  defp stage_query_param(_), do: %{}

  def tour_stop?(%{tournament: tournament}), do: tour_stop?(tournament)

  def tour_stop?(%{id: id}),
    do: !!Backend.MastersTour.TourStop.get_by(:battlefy_id, id)

  # todo move elsewhere
  def class_url(nil), do: nil
  def class_url(class), do: "/images/icons/#{String.downcase(class)}.png"

  @win_color "hsl(141, 53%, 53%)"
  @loss_color "hsl(348, 86%, 61%)"
  @result_width 2
  @border_width 1
  @border_color "black"
  defp build_box_shadow(wins, losses) do
    {
      @border_width + (wins + losses) * @result_width,
      """
      border_radius: 100%;
      box-shadow: 0 0 0 #{@border_width}px #{@border_color}
        , 0 0 0 #{@border_width + losses * @result_width}px #{@loss_color}
        , 0 0 0 #{@border_width + (wins + losses) * @result_width}px #{@win_color}
        ;
      """
    }
  end

  def ongoing_count(ongoing) do
    total = Enum.count(ongoing) |> div(2)

    not_nil_nil =
      ongoing
      |> Enum.filter(fn {_, %{score: score}} -> score != "0 - 0" end)
      |> Enum.count()
      |> div(2)

    {total, not_nil_nil}
  end

  def tournament_subtitle(%{tournament: tournament, standings: standings, ongoing: ongoing}) do
    []
    |> add_duration_subtitle(tournament)
    |> add_player_count_subtitle(standings)
    |> add_ongoing_subtitle(ongoing)
    |> Enum.join(" | ")
  end

  defp user_subtitle(params = %{conn: conn, standings: standings, tournament: %{id: id}}) do
    with %{battletag: battletag} <- BackendWeb.AuthUtils.user(conn),
         [_ | _] <- standings,
         true <- Enum.any?(standings, &(&1.name == battletag)) do
      assigns = %{
        battletag: battletag,
        link:
          Routes.battlefy_path(conn, :tournament_player, id, battletag, stage_query_param(params))
      }

      ~H"""
      <a href={@link}>
        <%= @battletag %>
      </a>
      """
    else
      _ -> nil
    end
  end

  defp user_subtitle(_), do: nil

  def add_duration_subtitle(subtitles, tournament) do
    subtitles ++
      case Backend.Battlefy.Tournament.get_duration(tournament) do
        nil -> ["Duration: ?"]
        duration -> ["Duration: #{Util.human_duration(duration)}"]
      end
  end

  def add_player_count_subtitle(subtitles, standings) do
    subtitles ++
      case standings |> Enum.count() do
        0 -> []
        num -> ["Players: #{num}"]
      end
  end

  def add_ongoing_subtitle(subtitles, ongoing) when ongoing == %{}, do: subtitles

  def add_ongoing_subtitle(subtitles, ongoing) do
    {total_ongoing, not_nil_nil_ongoing} = ongoing_count(ongoing)
    subtitles ++ ["Ongoing: #{total_ongoing}", "Ongoing(not 0-0): #{not_nil_nil_ongoing}"]
  end

  defp handle_standings(params) do
    updates =
      case prepare_standings(params) do
        prepared = [_ | _] ->
          %{
            standings: prepared,
            show_participants: false,
            participants_rows: []
          }

        _ ->
          %{
            standings: [],
            show_participants: true,
            participants_row: prepare_participants(params)
          }
      end

    Map.merge(params, updates)
    |> Map.delete(:standings_raw)
  end

  defp prepare_participants(_), do: []

  @spec prepare_standings(Map.t()) :: [standings]
  defp prepare_standings(
         %{
           standings_raw: standings_raw = [_ | _],
           conn: conn,
           earnings: earnings,
           lineups: lineups,
           show_lineups: show_lineups,
           invited_mapset: invited_mapset,
           tournament: tournament,
           ongoing: ongoing,
           use_countries: use_countries,
           participants: participants
         } = params
       ) do
    participants_map = participants |> Enum.map(&{&1.name, &1}) |> Map.new()
    lineup_map = lineups |> Enum.map(&{&1.name, &1}) |> Map.new()

    standings_raw
    |> Battlefy.filter_and_sort_standings()
    |> Enum.with_index()
    |> Enum.map(fn {s, index} ->
      {country, pre_name_cell} =
        with true <- use_countries,
             cc when is_binary(cc) <- Backend.PlayerInfo.get_country(s.team.name) do
          {cc, country_flag(cc, s.team.name)}
        else
          _ -> {nil, ""}
        end

      place = if(s.place && s.place > 0, do: s.place, else: "?")

      lineup =
        should_render_lineup(index, show_lineups) && render_lineup(lineup_map[s.team.name], conn)

      invited? = MapSet.member?(invited_mapset, s.team.name)

      %{
        place: place,
        country: country,
        name: team_name(s.team.name, participants_map),
        name_class: if(s.disqualified, do: "disqualified-player", else: ""),
        earnings: player_earnings(earnings, s.team.name),
        pre_name_cell: pre_name_cell,
        name_link:
          Routes.battlefy_path(
            conn,
            :tournament_player,
            tournament.id,
            s.team.name,
            stage_query_param(params)
          ),
        has_score: s.wins && s.losses,
        score: "#{s.wins} - #{s.losses}",
        wins: s.wins,
        losses: s.losses,
        ongoing: ongoing |> Map.get(s.team.name),
        invited: Helper.checkmark(%{show: invited?}),
        lineup: lineup
      }
    end)
  end

  defp prepare_standings(_) do
    Logger.info("Skipping standings preparation because invalid parameters")
    []
  end

  defp create_tournament_dropdowns(params) do
    [get_ongoing_dropdown(params)]
    |> add_lineups_dropdown(params)
    |> add_earnings_dropdown(params)
    |> add_highlight_fantasy_dropdown(params)
  end

  defp team_name(name, participants_map) do
    case Map.get(participants_map, name) do
      %{players: [%{in_game_name: ign}]} -> ign
      _ -> name
    end
  end

  defp should_render_lineup(index, cutoff) when is_integer(cutoff), do: index < cutoff
  defp should_render_lineup(_index, show_lineups), do: show_lineups

  defp render_lineup(nil, _conn), do: nil

  defp render_lineup(lineup, conn),
    do: live_render(conn, BackendWeb.ExpandableLineupLive, session: %{"lineup_id" => lineup.id})

  @spec create_player_options(%{standings: [Battlefy.Standings.t()], highlight: [String.t()]}) ::
          list()
  defp create_player_options(%{standings: standings, highlight: highlight}) do
    standings
    |> Enum.map(fn s ->
      %{
        name: s.name,
        selected: s.name in highlight,
        display: s.name,
        value: s.name
      }
    end)
    |> Enum.sort_by(fn p -> p.name end)
  end

  def add_highlight_fantasy_dropdown(dds, %{
        conn: conn,
        highlight_fantasy: highlight_fantasy,
        tournament: tournament,
        fantasy_picks: [_ | _]
      }) do
    dds ++
      [
        {[
           %{
             display: "Yes",
             selected: highlight_fantasy,
             link:
               Routes.battlefy_path(
                 conn,
                 :tournament,
                 tournament.id,
                 Map.put(conn.query_params, "highlight_fantasy", "yes")
               )
           },
           %{
             display: "No",
             selected: !highlight_fantasy,
             link:
               Routes.battlefy_path(
                 conn,
                 :tournament,
                 tournament.id,
                 Map.put(conn.query_params, "highlight_fantasy", "no")
               )
           }
         ], "Highlight Fantasy Picks"}
      ]
  end

  def add_highlight_fantasy_dropdown(dds, _), do: dds

  def add_earnings_dropdown(dds, %{
        is_tour_stop: true,
        conn: conn,
        tournament: tournament,
        show_earnings: show_earnings
      }),
      do: dds ++ [get_earnings_dropdown(conn, tournament, show_earnings)]

  def add_earnings_dropdown(dds, _), do: dds

  def add_lineups_dropdown(dds, %{conn: conn, show_lineups: show_lineups, tournament: tournament}) do
    dds ++
      [
        {[
           %{
             display: Components.Helper.warning_triangle(%{after_warning: "Yes"}),
             selected: show_lineups == true,
             link:
               Routes.battlefy_path(
                 conn,
                 :tournament,
                 tournament.id,
                 Map.put(conn.query_params, "show_lineups", "yes")
               )
           },
           %{
             display: "Top 64",
             selected: show_lineups == 64,
             link:
               Routes.battlefy_path(
                 conn,
                 :tournament,
                 tournament.id,
                 Map.put(conn.query_params, "show_lineups", "top_64")
               )
           },
           %{
             display: "No",
             selected: !show_lineups,
             link:
               Routes.battlefy_path(
                 conn,
                 :tournament,
                 tournament.id,
                 Map.put(conn.query_params, "show_lineups", "no")
               )
           }
         ], "Show lineups"}
      ]
  end

  def get_ongoing_dropdown(%{conn: conn, tournament: tournament, show_ongoing: show_ongoing}) do
    {[
       %{
         display: "Yes",
         selected: show_ongoing,
         link:
           Routes.battlefy_path(
             conn,
             :tournament,
             tournament.id,
             Map.put(conn.query_params, "show_ongoing", "yes")
           )
       },
       %{
         display: "No",
         selected: !show_ongoing,
         link:
           Routes.battlefy_path(
             conn,
             :tournament,
             tournament.id,
             Map.put(conn.query_params, "show_ongoing", "no")
           )
       }
     ], "Show Ongoing"}
  end

  def get_earnings_dropdown(conn, tournament, show_earnings) do
    {[
       %{
         display: "Yes",
         selected: show_earnings,
         link:
           Routes.battlefy_path(
             conn,
             :tournament,
             tournament.id,
             Map.put(conn.query_params, "show_earnings", "yes")
           )
       },
       %{
         display: "No",
         selected: !show_earnings,
         link:
           Routes.battlefy_path(
             conn,
             :tournament,
             tournament.id,
             Map.put(conn.query_params, "show_earnings", "no")
           )
       }
     ], "Show Earnings"}
  end

  defp player_earnings(earnings, player) do
    earnings
    |> Enum.find_value(fn {name, total, _} ->
      MastersTour.same_player?(name, player) && total
    end)
  end

  @spec next_button(Plug.Conn.t(), integer(), String.t()) :: Phoenix.HTML.Safe.t()
  def next_button(conn, next_page, slug) do
    new_params = conn.query_params |> Map.put("page", next_page)
    assigns = %{link: Routes.battlefy_path(conn, :user_tournaments, slug, new_params)}

    ~H"""
    <a class="icon button is-link" href={@link}>
      <HeroIcons.chevron_right />
    </a>
    """
  end

  @spec prev_button(Plug.Conn.t(), integer(), String.t()) :: Phoenix.HTML.Safe.t()
  def prev_button(_, 0, _) do
    assigns = %{}

    ~H"""
      <span class="icon button is-link">
          <HeroIcons.chevron_left />
      </span>
    """
  end

  def prev_button(conn, prev_page, slug) do
    new_params = conn.query_params |> Map.put("page", prev_page)
    assigns = %{link: Routes.battlefy_path(conn, :user_tournaments, slug, new_params)}

    ~H"""
    <a class="icon button is-link" href={@link}>
      <HeroIcons.chevron_left />
    </a>
    """
  end

  def prepare_future_opponents([_ | _] = matches, params, tournament) do
    matches
    |> Enum.map(fn match = %{top: top, bottom: bottom, round_number: current_round} ->
      %{
        top: handle_opponent_team(top, params),
        bottom: handle_opponent_team(bottom, params),
        match_url:
          Routes.live_path(
            BackendWeb.Endpoint,
            BackendWeb.BattlefyMatchLive,
            tournament.id,
            match.id
          ),
        current_round: current_round,
        score: "#{top.score} - #{bottom.score}"
      }
    end)
    |> Enum.sort_by(fn o -> o.current_round end, :desc)
  end

  def prepare_future_opponents(_, _params, _tournament), do: []

  def render_future_opponents(future_matches, title \\ "Future Opponents")
  def render_future_opponents([], _), do: false

  def render_future_opponents(future_matches, title) do
    assigns = %{future_matches: future_matches, title: title}

    ~H"""
    <div class="title is-5"><%= @title %> </div>
    <table class="table is-striped is-fullwidth is-narrow">
        <thead>
            <tr>
                <th>Round</th>
                <th>Top</th>
                <th class="is-hidden-mobile">Top Decks</th>
                <th>Score</th>
                <th>Bottom</th>
                <th class="is-hidden-mobile">Bottom Decks</th>
            </tr>
        </thead>
        <tbody>
            <%= for %{top: top, bottom: bottom, match_url: match_url, score: score, current_round: current_round} <- @future_matches do %>
                <tr>
                    <td><%= current_round %></td>
                    <%= if top == nil do %>
                        <td></td><td></td>
                    <% else %>
                        <td><a href={"#{ top.link }"}> <%= render_player_name(top.name, true) %></a></td>
                        <td class="is-hidden-mobile"><%= top.decks %></td>
                    <% end %>
                    <td><a href={"#{ match_url }"}> <%= score %></a></td>
                    <%= if bottom == nil do %>
                        <td></td><td></td>
                    <% else %>
                        <td><a href={"#{ bottom.link }"}> <%= render_player_name(bottom.name, true) %></a></td>
                        <td class="is-hidden-mobile"><%= bottom.decks %></td>
                    <% end %>
                </tr>
            <% end %>
        </tbody>
    </table>
    """
  end
end
