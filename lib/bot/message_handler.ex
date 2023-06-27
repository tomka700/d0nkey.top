defmodule Bot.MessageHandler do
  @moduledoc """
  Handles incoming discord message
  """

  alias BackendWeb.Router.Helpers, as: Routes
  alias Nostrum.Api
  alias Backend.Blizzard
  alias Backend.Leaderboards
  alias Backend.HearthstoneJson
  alias Backend.Hearthstone.Card
  alias Backend.Hearthstone.CardBag
  alias Nostrum.Struct.Embed
  import Bot.MessageHandlerUtil

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def handle(msg) do
    case msg.content do
      "!ping" ->
        Api.create_message(msg.channel_id, "pong")

      <<"!create_highlight", _::binary>> ->
        handle_highlight(msg)

      <<"!c_h", _::binary>> ->
        handle_highlight(msg)

      <<"!ch", _::binary>> ->
        handle_highlight(msg)

      <<"!leaderboard", _::binary>> ->
        handle_leaderboard(msg)

      <<"!ldb", _::binary>> ->
        Bot.LdbMessageHandler.handle_battletags_leaderboard(msg)

      <<"!matchups_link", _::binary>> ->
        Bot.MatchupMessageHandler.handle_matchups_link(msg)

      <<"!matchup", _::binary>> ->
        Bot.MatchupMessageHandler.handle_matchup(msg)

      <<"!battlefy", _::binary>> ->
        Bot.BattlefyMessageHandler.handle_tournament_standings(msg)

      <<"!mtq", _::binary>> ->
        Bot.MTMessageHandler.handle_qualifier_standings(msg)

      <<"!mt", _::binary>> ->
        Bot.MTMessageHandler.handle_mt_standings(msg)

      <<"!patchnotes", _::binary>> ->
        content = Backend.LatestHSArticles.patch_notes_url()
        Api.create_message(msg.channel_id, content)

      <<"!orangeopen", _::binary>> ->
        Bot.BattlefyMessageHandler.handle_tournament_standings("625e7176b31e652df4f63a63", msg)

      <<"!oo", _::binary>> ->
        Bot.BattlefyMessageHandler.handle_tournament_standings("625e7176b31e652df4f63a63", msg)

      <<"!maxopen8", _::binary>> ->
        Bot.BattlefyMessageHandler.handle_tournament_standings("62017079b5a9a57b56cc25b8", msg)

      <<"!maxopen", _::binary>> ->
        Bot.BattlefyMessageHandler.handle_tournament_standings("6319a0dec4fa012b14cd0f4b", msg)

      <<"!maxopen9", _::binary>> ->
        Bot.BattlefyMessageHandler.handle_tournament_standings("6319a0dec4fa012b14cd0f4b", msg)

      <<"!bunnyopen", _::binary>> ->
        Bot.BattlefyMessageHandler.handle_tournament_standings("636ec2c1a2fbe70578c33023", msg)

      <<"!tch", _::binary>> ->
        Bot.BattlefyMessageHandler.handle_tournament_standings("6271bd62d44c844993e4e1a7", msg)

      <<"!thl", _::binary>> ->
        Bot.ThlMessageHandler.handle_thl(msg)

      <<"[[", _::binary>> ->
        handle_card(msg)

      _ ->
        [
          handle_deck(msg),
          handle_card(msg)
        ]
        |> Enum.find(:ignore, &(&1 != :ignore))
    end
  end

  def handle_card(msg) do
    case Regex.scan(~r/\[\[(.+?)\]\]/, msg.content, capture: :all_but_first) do
      matches = [_ | _] ->
        embeds =
          matches
          |> Enum.map(&create_card_embed/1)
          |> Enum.filter(& &1)

        Api.create_message(msg.channel_id, embeds: embeds)

      _ ->
        :ignore
    end
  end

  defp create_card_embed([match]), do: create_card_embed(match)

  defp create_card_embed(match) do
    with nil <- do_match_card(match, &CardBag.closest_collectible/1),
         nil <- do_match_card(match, &HearthstoneJson.closest_collectible/1),
         nil <- do_match_card(match, &HearthstoneJson.closest/1) do
      nil
    else
      {card, card_url} ->
        %Embed{}
        |> Embed.put_title(card.name)
        |> Embed.put_image(card_url)

      _ ->
        nil
    end
  end

  defp do_match_card(match, matcher) do
    with [{_, card} | _] <- matcher.(match),
         card_url when is_binary(card_url) <- Card.card_url(card) do
      {card, card_url}
    else
      _ -> nil
    end
  end

  def handle_deck(msg) do
    with {:ok, deck} <- Backend.Hearthstone.Deck.decode(msg.content),
         false <- msg.content =~ "#",
         {:ok, message} <- create_deck_message(deck) do
      Api.create_message(msg.channel_id, message)
    else
      _ -> :ignore
    end
  end

  def create_deck_message(deck) do
    with {:ok, from_db} <- Backend.Hearthstone.create_or_get_deck(deck) do
      {:ok,
       "```\n#{Backend.Hearthstone.DeckcodeEmbiggener.embiggen(from_db)}\n```\nhttps://www.hsguru.com/deck/#{from_db.id}"}
    end
  end

  def handle_highlight(%{content: content, channel_id: channel_id}) do
    rest = get_options(content)
    url = Routes.leaderboard_url(BackendWeb.Endpoint, :index, %{highlight: rest})
    Api.create_message(channel_id, url)
  end

  def handle_leaderboard(%{content: content, channel_id: channel_id}) do
    rest = get_options(content)

    ldb_params =
      %{season_id: season_id, leaderboard_id: leaderboard_id, region: region} =
      parse_leaderboard_options(rest)

    {leaderboard_entries, _} = Leaderboards.get_leaderboard(region, leaderboard_id, season_id)

    query_params =
      ldb_params
      |> Enum.map(fn {k, v} -> {Recase.to_camel(to_string(k)), v} end)

    url = Routes.leaderboard_url(BackendWeb.Endpoint, :index, query_params)

    table =
      leaderboard_entries
      |> Enum.take(10)
      |> Enum.map_join(
        "\n",
        fn le ->
          "#{String.pad_trailing(to_string(le.position), 3, [" "])} #{le.battletag}"
        end
      )

    message = "#{url}\n```#{table}\n```"
    Api.create_message(channel_id, message)
  end

  @doc """
  Extracts the season_id, leaderboard_id and region from the options passed to !leaderboard

  ## Example
  iex> Bot.MessageHandler.parse_leaderboard_options([" 100", "AP", "BG"])
  %{season_id: 100, leaderboard_id: :BG, region: AP}
  iex> Bot.MessageHandler.parse_leaderboard_options(" 69 adfsf ql5q THIS IS AWESOME BG"])
  %{season_id: 69, leaderboard_id: :BG, region: EU}
  """
  @spec parse_leaderboard_options([String.t()] | String.t()) :: %{
          leaderboard_id: Blizzard.leaderboard(),
          region: Blizzard.leaderboard(),
          season_id: integer()
        }
  def parse_leaderboard_options(options) do
    normalized =
      if is_binary(options) do
        String.splitter(options, " ")
      else
        options
      end

    parsed =
      normalized
      |> Stream.map(&String.upcase/1)
      |> Enum.reduce(
        %{},
        fn opt, acc ->
          case {Blizzard.to_region(opt), Blizzard.to_leaderboard(opt), Integer.parse(opt)} do
            {{:ok, region}, _, _} -> Map.put_new(acc, :region, region)
            {_, {:ok, leaderboard_id}, _} -> Map.put_new(acc, :leaderboard_id, leaderboard_id)
            {_, _, {season_id, _}} -> Map.put_new(acc, :season_id, season_id)
            _ -> acc
          end
        end
      )

    default = %{
      season_id: Blizzard.get_season_id(Date.utc_today(), :STD),
      leaderboard_id: :STD,
      region: :EU
    }

    Map.merge(default, parsed)
  end
end
