defmodule Backend.Hearthstone do
  @moduledoc false
  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Backend.Repo
  alias Backend.Hearthstone.CardBag
  alias Backend.Hearthstone.Deck
  alias Backend.DeckArchetyper
  alias Backend.Hearthstone.Deck.Sideboard
  alias Backend.Hearthstone.Lineup
  alias Backend.Hearthstone.LineupDeck
  alias Backend.Hearthstone.CardBackCategory
  alias Backend.Hearthstone.Class
  alias Backend.Hearthstone.Faction
  alias Backend.Hearthstone.GameMode
  alias Backend.Hearthstone.Keyword, as: HSKeyword
  alias Backend.Hearthstone.MercenaryRole
  alias Backend.Hearthstone.MinionType
  alias Backend.Hearthstone.Rarity
  alias Backend.Hearthstone.SetGroup
  alias Backend.Hearthstone.Set
  alias Backend.Hearthstone.SpellSchool
  alias Backend.Hearthstone.Type
  alias Backend.Hearthstone.Card
  alias Backend.HearthstoneJson
  alias Hearthstone.Api
  alias Hearthstone.Card, as: ApiCard
  require Logger
  require Card

  @type insertable_card :: ApiCard
  @type card :: Card.t() | Backend.HearthstoneJson.Card.t()

  def set_groups() do
    Repo.all(SetGroup)
  end

  def standard_card_sets() do
    query =
      from(sg in SetGroup,
        where: sg.slug == "standard",
        select: sg.card_sets
      )

    Repo.one(query) || []
  end

  @spec card_sets() :: [Set.t()]
  def card_sets() do
    Repo.all(Set)
  end

  def latest_sets_with_release_dates(group_slug \\ nil) do
    base_query =
      from s in Set,
        as: :card_set,
        where: not is_nil(s.release_date),
        order_by: [desc: :release_date]

    # filter by group_slug if present
    query =
      if is_binary(group_slug) do
        subquery = set_group_sets_query(group_slug)

        base_query
        |> where([s], s.slug in subquery(subquery))
      else
        base_query
      end

    Repo.all(query)
  end

  def latest_set() do
    query =
      from s in Set,
        order_by: [desc: :inserted_at],
        limit: 1

    Repo.one(query)
  end

  def card_back_categories() do
    Repo.all(CardBackCategory)
  end

  def classes() do
    Repo.all(Class)
  end

  def class_by_slug(slug) do
    query = from c in Class, where: ilike(c.slug, ^slug)
    Repo.one(query)
  end

  def game_modes() do
    Repo.all(GameMode)
  end

  def factions() do
    Repo.all(Faction)
  end

  def keywords() do
    Repo.all(HSKeyword)
  end

  def mercenary_roles() do
    Repo.all(MercenaryRole)
  end

  def minion_types() do
    Repo.all(MinionType)
  end

  def spell_schools() do
    Repo.all(SpellSchool)
  end

  def rarities() do
    Repo.all(Rarity)
  end

  def card_types() do
    Repo.all(Type)
  end

  def update_metadata() do
    with {:ok,
          %{
            card_back_categories: card_back_categories,
            classes: classes,
            factions: factions,
            game_modes: game_modes,
            keywords: keywords,
            mercenary_roles: mercenary_roles,
            minion_types: minion_types,
            rarities: rarities,
            set_groups: set_groups,
            sets: sets,
            spell_schools: spell_schools,
            types: types
          }} <- Api.get_metadata() do
      [
        {CardBackCategory, card_back_categories},
        {Class, classes},
        {Faction, factions},
        {GameMode, game_modes},
        {HSKeyword, keywords},
        {MercenaryRole, mercenary_roles},
        {MinionType, minion_types},
        {Rarity, rarities},
        {SetGroup, set_groups},
        {Set, sets},
        {SpellSchool, spell_schools},
        {Type, types}
      ]
      |> Enum.reduce(Multi.new(), &metadata_multi_insert/2)
      |> Repo.transaction()
    end
  end

  @spec metadata_multi_insert({atom(), Map.t()}, Multi.t()) :: Multi.t()
  defp metadata_multi_insert({struct_module, values}, multi) do
    values
    |> Enum.reduce(multi, fn val, m ->
      base_struct = struct(struct_module)
      cs = apply(struct_module, :changeset, [base_struct, val])

      {uniq_val, conflict_target} =
        case Map.get(val, :id) do
          nil -> {Map.get(val, :slug), :slug}
          val -> {val, :id}
        end

      Multi.insert(m, "#{struct_module}__insert__#{uniq_val}", cs,
        on_conflict: {:replace_all_except, [:inserted_at, :release_date]},
        conflict_target: conflict_target
      )
    end)
  end

  @spec check_archetype(any) :: any
  def check_archetype({:ok, deck}) do
    {:ok, check_archetype(deck)}
  end

  def check_archetype(deck) do
    Task.start(fn ->
      if needs_archetype_update?(deck) do
        recalculate_decks_archetypes([deck])
      end
    end)

    deck
  end

  defp needs_archetype_update?(%{archetype: archetype} = deck)
       when is_binary(archetype) or is_atom(archetype) do
    to_string(archetype) != to_string(DeckArchetyper.archetype(deck))
  end

  defp needs_archetype_update?(_), do: true

  @doc """
  Gets all decks with the same parts, including the submitted deck
  """
  @spec get_same(Deck.t()) :: [Deck.t()]
  def get_same(%Deck{format: format, hero: hero, cards: cards, sideboards: sideboards}) do
    [{"format", format}, {"hero", hero}, {"cards", cards}, {"sideboards", sideboards}]
    |> decks()
  end

  @spec create_or_get_deck(String.t() | Deck.t()) :: {:ok, Deck.t()} | {:error, any()}
  def create_or_get_deck(deckcode) when is_binary(deckcode) do
    with {:ok, deck} <- Deck.decode(deckcode) do
      create_or_get_deck(deck)
    end
  end

  def create_or_get_deck(%Deck{cards: cards, hero: hero, format: format, sideboards: sideboards}),
    do: create_or_get_deck(cards, hero, format, sideboards)

  @spec create_or_get_deck([integer()], integer(), integer(), integer()) ::
          {:ok, Deck.t()} | {:error, any()}
  def create_or_get_deck(cards, hero, format, sideboards) do
    deck(cards, hero, format, sideboards)
    |> case do
      nil -> create_deck(cards, hero, format, sideboards)
      deck -> {:ok, deck}
    end
  end

  def change_format(%Deck{} = deck, format) do
    deck
    |> Deck.change_format(format)
    |> Repo.update()
  end

  def all_cards() do
    query = from(c in Card)

    query
    |> preload_cards()
    |> Repo.all()
  end

  def preload_cards(query),
    do:
      query
      |> preload([
        :card_set,
        :card_type,
        :copy_of_card,
        :keywords,
        :factions,
        :classes,
        :minion_type,
        :rarity,
        :spell_school
      ])

  @spec upsert_cards([insertable_card()]) :: {:ok, [Card.t()]} | {:error, any()}
  def upsert_cards(cards_raw) do
    known_sets_ids = card_sets() |> MapSet.new(& &1.id)

    cards =
      cards_raw
      |> Enum.filter(fn %{card_set_id: set_id} -> MapSet.member?(known_sets_ids, set_id) end)
      |> Enum.uniq_by(& &1.id)

    cards_map = Map.new(cards, fn c -> {c.id, c} end)
    # using ecto on_conflict upsert support causes issues with the many_to_many relationships
    # they want to get inserted again
    # so we fetch first instead
    ids = Enum.map(cards, & &1.id)

    existing_query =
      from(c in Card, preload: [:classes, :keywords, :factions], where: c.id in ^ids)

    existing = Repo.all(existing_query)
    existing_ids = MapSet.new(existing, & &1.id)
    new = Enum.reject(cards, &MapSet.member?(existing_ids, &1.id))
    multi = Enum.reduce(new, Multi.new(), &card_multi_insert/2)

    Enum.reduce(existing, multi, fn old, m ->
      new_card = Map.get(cards_map, old.id)
      changeset = card_changeset(new_card, old)
      Multi.update(m, "update_card_#{old.id}", changeset)
    end)
    |> Repo.transaction()
  end

  @spec card_multi_insert(insertable_card(), Multi.t()) :: Multi.t()
  defp card_multi_insert(card, multi) do
    changeset = card_changeset(card)

    Multi.insert(
      multi,
      "card_insert_#{card.id}",
      changeset,
      on_conflict: {:replace_all_except, [:id, :keywords, :classes]},
      conflict_target: :id
    )
  end

  @spec card_changeset(insertable_card(), Card.t()) :: Ecto.Changeset.t()
  def card_changeset(upstream_card, card \\ %Card{}) do
    card
    |> Card.changeset(upstream_card)
    |> add_card_assocs(upstream_card)
  end

  @spec add_card_assocs(Ecto.Changeset.t(), insertable_card()) :: Ecto.Changeset.t()
  defp add_card_assocs(changeset, %ApiCard{} = api_card) do
    keyword_ids = api_card.keyword_ids
    class_ids = ApiCard.class_ids(api_card)
    faction_ids = api_card.faction_ids
    keyword_query = from(k in HSKeyword, where: k.id in ^keyword_ids)
    class_query = from(c in Class, where: c.id in ^class_ids)
    faction_query = from(f in Faction, where: f.id in ^faction_ids)
    keywords = Repo.all(keyword_query)
    classes = Repo.all(class_query)
    factions = Repo.all(faction_query)

    changeset
    |> Card.put_keywords(keywords)
    |> Card.put_classes(classes)
    |> Card.put_factions(factions)
  end

  def get_deck(id) do
    Repo.get(Deck, id)
  end

  def deck(%{id: id}) when is_integer(id), do: deck(id)

  def deck(%{cards: cards, hero: hero, format: format, sideboards: sideboards}),
    do: deck(cards, hero, format, sideboards)

  def deck(id) when is_integer(id), do: get_deck(id)

  def deck(id_or_deckcode) when is_binary(id_or_deckcode) do
    id_or_deckcode
    |> Integer.parse()
    |> case do
      {id, _} ->
        deck(id)

      _ ->
        query =
          from(d in Deck,
            where: d.deckcode == ^id_or_deckcode,
            limit: 1
          )

        Repo.one(query)
    end
  end

  def deck(cards, hero, format, sideboards) do
    with nil <- Deck.deckcode(cards, hero, format, sideboards) |> deck(),
         [] <- decks_from_parts(cards, hero, format, sideboards) do
      nil
    else
      %Deck{} = deck -> deck
      [%Deck{} = deck | _] -> deck
      _ -> nil
    end
  end

  def decks_from_parts(cards, hero, format, sideboards) do
    decks([
      {"cards", cards},
      {"hero", hero},
      {"format", format},
      {"sideboards", sideboards}
    ])
  end

  def create_deck(cards, hero, format, sideboards) do
    class = class(hero)

    temp_attrs = %{
      cards: cards,
      hero: hero,
      format: format,
      class: class,
      archetype: DeckArchetyper.archetype(format, cards, class),
      sideboards: sideboards
    }

    attrs = Map.put(temp_attrs, :hsreplay_archetype, nil)

    %Deck{}
    |> Deck.changeset(attrs)
    |> Repo.insert(
      on_conflict: :nothing,
      conflict_target: :deckcode
    )
  end

  def class(%{hero: hero}), do: class(hero)
  # TODO: remove, this is temp before hearthstonejson gets it.
  def class(78_065), do: "DEATHKNIGHT"
  def class(dbf_id), do: HearthstoneJson.get_class(dbf_id)

  def deduplicate_decks(limit \\ 100) do
    get_duplicated_deck_ids(limit)
    |> Enum.map(&deduplicate_ids/1)
  end

  def get_duplicated_deck_ids(limit \\ 30, timeout \\ 69_000) do
    query =
      from d in Backend.Hearthstone.Deck,
        select: %{ids: fragment("array_agg(?)", d.id)},
        group_by: [d.cards, d.format, d.hero, d.sideboards],
        having: count(d.id) > 1,
        order_by: [desc: fragment("MAX(?)", d.inserted_at)],
        limit: ^limit

    Repo.all(query, timeout: timeout)
  end

  def deduplicate_ids(%{ids: ids}), do: deduplicate_ids(ids)

  def deduplicate_ids(ids) do
    Enum.map(ids, &get_deck/1)
    |> Command.DeduplicateDecks.deduplicate_group(&deduplication_sorter/1, :desc)
  end

  # want the one with the correct code first, then secondary ordered by latest
  defp deduplication_sorter(deck) do
    same_code? = deck.deckcode == Deck.deckcode(deck)
    canonical_cards? = Enum.map(deck.cards, &canonical_id/1) == deck.cards

    prepend =
      cond do
        same_code? and canonical_cards? -> "ZZZ"
        canonical_cards? -> "TTT"
        same_code? -> "HHH"
        true -> "AAA"
      end

    date_part = NaiveDateTime.to_iso8601(deck.inserted_at)
    "#{prepend}#{date_part}"
  end

  @spec recalculate_archetypes(Integer.t() | String.t()) :: {:ok, any()} | {:error, any()}
  def recalculate_archetypes(<<"min_ago_"::binary, min_ago::bitstring>>),
    do: recalculate_archetypes(min_ago)

  def recalculate_archetypes(minutes_ago) when is_binary(minutes_ago) do
    case Integer.parse(minutes_ago) do
      {num, _} -> recalculate_archetypes(num)
      _ -> {:error, "Couldn't parse integer"}
    end
  end

  def recalculate_archetypes(minutes_ago, min_id \\ 0) when is_integer(minutes_ago) do
    cutoff = NaiveDateTime.utc_now() |> NaiveDateTime.add(-1 * 60 * minutes_ago)
    do_recalculate_archetypes(cutoff, min_id)
  end

  defp do_recalculate_archetypes(cutoff, min_id) do
    query =
      from(d in Deck,
        distinct: d.id,
        left_join: dtg in Hearthstone.DeckTracker.Game,
        on: dtg.player_deck_id == d.id,
        order_by: [asc: :id],
        limit: 100,
        where: d.id > ^min_id and (d.inserted_at >= ^cutoff or dtg.inserted_at >= ^cutoff)
      )

    case Repo.all(query) do
      [] ->
        {:ok, "done"}

      decks ->
        recalculate_decks_archetypes(decks)
        %{id: new_min} = Enum.max_by(decks, & &1.id)
        do_recalculate_archetypes(cutoff, new_min)
    end
  end

  def recalculate_decks_archetypes(decks) do
    decks
    |> Enum.chunk_every(100)
    |> Enum.each(fn chunk ->
      id_ints = for %{id: id} <- chunk, do: id
      ids = id_ints |> Enum.join(" ")
      {min, max} = Enum.min_max(id_ints)
      Logger.info("Recalculating archetypes from #{min} to #{max}")
      Logger.debug("Recalculating ids: #{ids}")

      chunk
      |> Enum.reduce(Multi.new(), fn d, multi ->
        new_archetype = Backend.DeckArchetyper.archetype(d)
        updated = Deck.update_archetype_changeset(d, new_archetype)
        Multi.update(multi, to_string(d.id), updated)
      end)
      |> Repo.transaction(timeout: 60_000)
    end)
  end

  def recalculate_decks_archetypes_for_period(period, additional_criteria \\ []) do
    criteria = [{"period", period} | additional_criteria]
    deck_stats = Hearthstone.DeckTracker.deck_stats(criteria)
    decks = Enum.map(deck_stats, &get_deck(&1.deck_id))

    needs_archetypeing =
      Enum.filter(decks, fn d ->
        to_string(d.archetype) != to_string(DeckArchetyper.archetype(d))
      end)

    recalculate_decks_archetypes(needs_archetypeing)
  end

  @spec recalculate_hsreplay_archetypes(Integer.t() | String.t()) ::
          {:ok, any()} | {:error, any()}
  def recalculate_hsreplay_archetypes(<<"min_ago_"::binary, min_ago::bitstring>>),
    do: recalculate_hsreplay_archetypes(min_ago)

  def recalculate_hsreplay_archetypes(minutes_ago) when is_binary(minutes_ago) do
    case Integer.parse(minutes_ago) do
      {num, _} -> recalculate_hsreplay_archetypes(num)
      _ -> {:error, "Couldn't parse integer"}
    end
  end

  def recalculate_hsreplay_archetypes(minutes_ago) when is_integer(minutes_ago) do
    decks = decks([{"latest", minutes_ago}])
    Logger.info("Recalculating archetypes for #{decks |> Enum.count()} decks")

    decks
    |> Enum.chunk_every(100)
    |> Enum.each(fn chunk ->
      Logger.info("Recalculating archetypes...")

      chunk
      |> Enum.reduce(Multi.new(), fn d, multi ->
        new_archetype = Backend.HSReplay.guess_archetype(d)
        updated = d |> Deck.changeset(%{hsreplay_archetype: new_archetype, deckcode: d.deckcode})
        Multi.update(multi, to_string(d.id), updated)
      end)
      |> Repo.transaction(timeout: 60_000)
    end)

    {:ok, "Done"}
  end

  def init_deck_costs() do
    case init_deck_costs(1000) do
      :done -> :ok
      _ -> init_deck_costs()
    end
  end

  def init_deck_costs(num) do
    query = from d in Deck, where: is_nil(d.cost), order_by: [desc: :inserted_at], limit: ^num
    decks = Repo.all(query)

    case decks do
      [_ | _] ->
        recalculate_decks_cost(decks)

      [] ->
        :done
    end
  end

  def recalculate_decks_cost(decks) do
    Enum.reduce(decks, Multi.new(), fn deck, multi ->
      cs = Deck.set_cost_changeset(deck)
      Multi.update(multi, to_string(deck.id), cs)
    end)
    |> Repo.transaction(timeout: 240_000)
  end

  @spec decks(list()) :: [Deck.t()]
  def decks(criteria) do
    base_decks_query()
    |> build_decks_query(criteria)
    |> Repo.all()
  end

  @spec archetypes(list()) :: [atom()]
  def archetypes(criteria) do
    base_archetypes_query()
    |> build_decks_query(criteria)
    |> Repo.all()
  end

  defp base_decks_query(), do: from(d in Deck, as: :deck)

  defp base_archetypes_query(),
    do:
      from(d in Deck, as: :deck)
      |> select([deck: d], d.archetype)
      |> distinct([deck: d], d.archetype)
      |> where([deck: d], not is_nil(d.archetype))

  defp build_decks_query(query, criteria),
    do: Enum.reduce(criteria, query, &compose_decks_query/2)

  def add_deck_criteria(query, criteria, joiner) do
    deck_criteria = for {"deck_" <> new_key, val} <- criteria, do: {new_key, val}

    if Enum.any?(deck_criteria) do
      query
      |> joiner.()
      |> build_decks_query(deck_criteria)
    else
      query
    end
  end

  defp compose_decks_query({"hero", hero}, query), do: query |> where([deck: d], d.hero == ^hero)

  defp compose_decks_query({"format", format}, query),
    do: query |> where([deck: d], d.format == ^format)

  defp compose_decks_query({"cards", cards}, query),
    do: query |> where([deck: d], fragment("sort_asc(?)", d.cards) == ^Deck.sort_card_ids(cards))

  defp compose_decks_query({"sideboards", empty}, query) when empty in [nil, []],
    do: query |> where([deck: d], is_nil(d.sideboards) or d.sideboards == fragment("'{}'"))

  defp compose_decks_query({"sideboards", sideboards}, query),
    do: query |> where([deck: d], d.sideboards == ^Enum.map(sideboards, &Sideboard.init/1))

  defp compose_decks_query({"limit", limit}, query),
    do: query |> limit(^limit)

  defp compose_decks_query({"class", nil}, query), do: query |> where([deck: d], is_nil(d.class))

  defp compose_decks_query({"class", class}, query),
    do: query |> where([deck: d], d.class == ^class)

  defp compose_decks_query({"deckcode", deckcode}, query),
    do: query |> where([deck: d], d.deckcode == ^deckcode)

  defp compose_decks_query(
         {"latest", <<"min_ago_"::binary, min_ago::bitstring>>},
         query
       ) do
    min_ago
    |> Integer.parse()
    |> case do
      {num, _} -> compose_decks_query({"last_played", num}, query)
      _ -> query
    end
  end

  defp compose_decks_query({"latest", min_ago}, query) when is_integer(min_ago),
    do: query |> where([deck: d], d.inserted_at >= ago(^min_ago, "minute"))

  defp compose_decks_query(
         {"recently_played", <<"min_ago_"::binary, min_ago::bitstring>>},
         query
       ) do
    min_ago
    |> Integer.parse()
    |> case do
      {num, _} -> compose_decks_query({"recently_played", num}, query)
      _ -> query
    end
  end

  defp compose_decks_query({"recently_played", min_ago}, query) when is_integer(min_ago),
    do:
      query
      |> join(:inner, [deck: d], dtg in Hearthstone.DeckTracker.Game,
        on: dtg.player_deck_id == d.id,
        as: :game
      )
      |> where([game: g], g.inserted_at >= ago(^min_ago, "minute"))

  defp compose_decks_query({"include_cards", cards = [_ | _]}, query) do
    query
    |> include_cards(cards, :deck)
  end

  defp compose_decks_query({"include_cards", []}, query), do: query

  defp compose_decks_query({"exclude_cards", cards = [_ | _]}, query) do
    query
    |> exclude_cards(cards, :deck)
  end

  defp compose_decks_query({"exclude_cards", []}, query), do: query

  defp compose_decks_query(unrecognized, query) do
    Logger.warning("Couldn't compose #{__MODULE__} query: #{inspect(unrecognized)}")
    query
  end

  def include_cards(query, cards, binding) do
    dynamic =
      cards
      |> Enum.reduce(dynamic(true), fn card_id, dynamic ->
        same_cards_subquery = same_card_ids_query(card_id)

        dynamic(
          [{^binding, d}],
          ^dynamic and fragment("? && ?", d.cards, subquery(same_cards_subquery))
        )
      end)

    query |> where(^dynamic)
  end

  def exclude_cards(query, cards, binding) do
    dynamic =
      cards
      |> Enum.reduce(dynamic(true), fn card_id, dynamic ->
        same_cards_subquery = same_card_ids_query(card_id)

        dynamic(
          [{^binding, d}],
          ^dynamic and not fragment("? && ?", d.cards, subquery(same_cards_subquery))
        )
      end)

    query |> where(^dynamic)
  end

  def same_card_ids_query(card_id) do
    canonical = canonical_id(card_id)
    list = [card_id, canonical]

    from c in Card,
      select: fragment("array_agg(?::integer)", c.id),
      where: c.id in ^list or c.canonical_id in ^list
  end

  def darkmoon_faire_out?() do
    now = NaiveDateTime.utc_now()
    release = ~N[2020-11-17 18:00:00]
    NaiveDateTime.compare(now, release) == :gt
  end

  # @type extract_card_fun :: (any() -> Card.card())
  # @type card_cost_fun :: (Card.card() -> integer())
  # @type card_name_fun :: Card.card() -> String.t()
  # @type card_sort_opt :: {:extract_card, extract_card_fun()} | {:cost, card_cost_fun()} | {:direction, :asc | :desc } | {:name, card_name_fun}
  @type card_sort_opt ::
          {:extract_card, (any() -> Card.card())}
          | {:cost, (Card.card() -> integer())}
          | {:direction, :asc | :desc}
          | {:name, (Card.card() -> String.t())}
  @type card_sort_opts :: [card_sort_opt]
  @spec ordered_frequencies(integer(), card_sort_opts()) :: {Card.card(), integer()}
  def ordered_frequencies(cards, card_sort_opts \\ [])

  def ordered_frequencies(cards = [a | _], card_sort_opts) when is_integer(a) do
    cards
    |> Enum.frequencies()
    |> Enum.map(fn {c, freq} ->
      {get_card(c), freq}
    end)
    |> Enum.filter(&(&1 |> elem(0)))
    |> sort_cards(card_sort_opts)
  end

  def ordered_frequencies(_, _), do: []

  defp name_for_sort({%{name: name}, _}), do: name
  defp name_for_sort({_, %{name: name}}), do: name
  defp name_for_sort(%{name: name}), do: name
  defp name_for_sort(_), do: nil

  def cost_for_sort({%{mana_cost: cost}, _}), do: cost
  def cost_for_sort({_, %{mana_cost: cost}}), do: cost
  def cost_for_sort(%{mana_cost: cost}), do: cost
  def cost_for_sort({%{cost: cost}, _}), do: cost
  def cost_for_sort({_, %{cost: cost}}), do: cost
  def cost_for_sort(%{cost: cost}), do: cost
  def cost_for_sort(_), do: nil

  def sort_cards(cards, opts \\ []) do
    extract_card = Keyword.get(opts, :extract_card, &extract_card/1)
    direction = Keyword.get(opts, :direction, :asc)
    name = Keyword.get(opts, :name, &name_for_sort/1)
    cost = Keyword.get(opts, :cost, &cost_for_sort/1)

    cards
    |> Enum.sort_by(&(extract_card.(&1) |> name.()), direction)
    |> Enum.sort_by(&(extract_card.(&1) |> cost.()), direction)
  end

  defp extract_card(card_id) when is_integer(card_id), do: get_card(card_id)
  defp extract_card(%{card_id: card_id}) when is_integer(card_id), do: get_card(card_id)
  defp extract_card(%{card: card}) when Card.is_card(card), do: card
  defp extract_card({card, _}) when Card.is_card(card), do: card
  defp extract_card({_, card}) when Card.is_card(card), do: card
  defp extract_card(card) when Card.is_card(card), do: card
  defp extract_card(_), do: nil

  @doc """
  Gets a card with the dbfId `dbf_id` from the official api cache.
  Fallbacks to HSJson card
  """
  @spec get_card(integer) :: card() | nil
  def get_card(dbf_id) do
    with nil <- CardBag.card(dbf_id) do
      Backend.HearthstoneJson.get_card(dbf_id)
    end
  end

  @spec get_deckcode_card(integer) :: card() | nil
  def get_deckcode_card(dbf_id) do
    CardBag.deckcode_copy_id(dbf_id) |> get_card()
  end

  @spec get_fuzzy_card(String.t()) :: card() | nil
  def get_fuzzy_card(fuzzy) do
    common_criteria = [
      {"order_by", "latest"},
      Backend.Hearthstone.not_classic_card_criteria(),
      {"limit", 1}
    ]

    exact_criteria = [{"name", fuzzy}, {"order_by", {:desc, :collectible}} | common_criteria]

    fuzzy_criteria = [
      {"order_by", "name_similarity_#{fuzzy}"},
      {"collectible", "yes"} | common_criteria
    ]

    with [] <- Backend.Hearthstone.cards(exact_criteria),
         [] <- Backend.Hearthstone.cards(fuzzy_criteria) do
      nil
    else
      [card | _] ->
        card
    end
  end

  @spec get_or_create_lineup(String.t() | integer(), String.t(), String.t(), [String.t()]) ::
          {:ok, Lineup.t()} | {:error, any()}
  def get_or_create_lineup(id, s, n, d) when is_integer(id),
    do: get_or_create_lineup(to_string(id), s, n, d)

  def get_or_create_lineup(tournament_id, tournament_source, name, deckstrings) do
    attrs = %{tournament_id: tournament_id, tournament_source: tournament_source, name: name}

    case lineup(attrs) do
      ln = %{id: _} ->
        {:ok, ln}

      nil ->
        insert_lineup(attrs, deckstrings)
    end
  end

  def lineup(%{tournament_id: tournament_id, tournament_source: tournament_source, name: name}) do
    query =
      from(l in Lineup,
        where:
          l.tournament_id == ^tournament_id and l.tournament_source == ^tournament_source and
            l.name == ^name,
        preload: [:decks],
        select: l
      )

    Repo.one(query)
  end

  def lineup(id) do
    query =
      from(l in Lineup,
        select: l,
        preload: [:decks],
        where: l.id == ^id
      )

    Repo.one(query)
  end

  def create_lineup(attrs, deckstrings) do
    decks =
      deckstrings
      |> Enum.uniq()
      |> Enum.filter(&Deck.valid?/1)
      |> Enum.map(&(&1 |> create_or_get_deck() |> Util.nilify()))
      |> Enum.filter(& &1)

    %Lineup{}
    |> Lineup.changeset(attrs, decks)
  end

  def insert_lineup(attrs, deckstrings) do
    create_lineup(attrs, deckstrings)
    |> Repo.insert()
  end

  def has_lineups?(tournament_id, tournament_source) do
    query =
      from(l in Lineup,
        where: l.tournament_id == ^tournament_id and l.tournament_source == ^tournament_source,
        select: 1,
        limit: 1
      )

    !!Repo.one(query)
  end

  def get_lineups(tournament_id, tournament_source) do
    lineups([{"tournament_id", tournament_id}, {"tournament_source", tournament_source}])
  end

  def parse_gm_season("2020_2"), do: {:ok, {2020, 2}}
  def parse_gm_season("2021_1"), do: {:ok, {2021, 1}}
  def parse_gm_season("2021_2"), do: {:ok, {2021, 2}}
  def parse_gm_season("2022_1"), do: {:ok, {2022, 1}}
  def parse_gm_season("2022_2"), do: {:ok, {2022, 2}}
  def parse_gm_season(_), do: :error

  def parse_gm_season!(s), do: s |> parse_gm_season() |> Util.bangify()

  def similar_cards(search) do
    query =
      from(c in Card,
        order_by: [desc: fragment("similarity(?, ?)", c.name, ^search)],
        limit: 7
      )

    query
    |> preload_cards()
    |> Repo.all()
  end

  @doc """
  Gets a the card with the dbfId `card_id` from the database (ie official api)
  """
  @spec card(integer() | String.t()) :: Card.t() | nil
  def card(card_id) do
    query = from(c in Card, where: c.id == ^card_id)

    query
    |> preload_cards()
    |> Repo.one()
  end

  @spec child_cards(Card.t()) :: [Card.t()]
  def child_cards(%{child_ids: no_children}) when no_children in [[], nil], do: []

  def child_cards(%{child_ids: ids}) do
    query = from(c in Card, where: c.id in ^ids)

    query
    |> preload_cards()
    |> Repo.all()
  end

  def cards(criteria) do
    # {post_processer, criteria} = use_fake_limit(criteria_raw)

    base_cards_query()
    |> build_cards_query(criteria)
    # |> tap(fn q ->
    #   sql = Repo.to_sql(:all, q)
    #   elem(sql, 0) |> IO.puts
    # end)
    |> Repo.all()

    # |> post_processer.()
  end

  def not_classic_card_criteria(), do: {"card_set_id_not_in", [1646]}

  # defp use_fake_limit(old_filters) do
  #   old_filters
  #   |> Enum.to_list()
  #   |> List.keytake("limit", 0)
  #   |> case do
  #     nil ->
  #       {& &1, old_filters}

  #     {{"limit", old_limit}, temp_filters} ->
  #       limit = Util.to_int!(old_limit, 10)

  #       {
  #         &Enum.take(&1, limit),
  #         [{"fake_limit", Util.to_int_or_orig(limit) * 5} | temp_filters]
  #       }
  #   end
  # end

  defp build_cards_query(query, criteria),
    do: Enum.reduce(criteria, query, &compose_cards_query/2)

  defp compose_cards_query(:actual_card_set, query) do
    query
    |> where([card: c], c.card_set_id > 0)
  end

  defp compose_cards_query(:dust_free, query) do
    query
    |> where([card: c], c.dust_free)
  end

  defp compose_cards_query(:canonical, query) do
    query
    |> where([card: c], c.id == c.canonical_id)
  end

  defp compose_cards_query({"order_by", "latest"}, query) do
    query
    |> order_by([card: c], desc: c.inserted_at)
  end

  defp compose_cards_query({"order_by", "mana_in_class"}, query) do
    query
    |> order_by([classes: cl, card: c],
      asc: like(cl.slug, "neutral"),
      asc: cl.slug,
      asc: c.mana_cost,
      asc: c.name
    )
  end

  defp compose_cards_query({"order_by", "mana"}, query) do
    query
    |> order_by([classes: cl, card: c], asc: c.mana_cost, asc: c.name)
  end

  defp compose_cards_query({"id_not_in", ids}, query) when is_list(ids) do
    query
    |> where([card: c], c.id not in ^ids)
  end

  defp compose_cards_query({"order_by", "name_similarity_" <> search_target}, query) do
    inner_query =
      from c in Card,
        select: %{name: fragment("UNNEST(array_prepend(?, ?))", c.name, c.nicknames), id: c.id}

    subquery =
      from c in subquery(inner_query),
        select: %{
          id: c.id,
          similarity: fragment("MAX(SIMILARITY(?, ?))", c.name, ^search_target)
        },
        group_by: c.id

    query
    |> join(:left, [card: c], simil in subquery(subquery), as: :similarity, on: simil.id == c.id)
    |> order_by([similarity: s], desc: s.similarity)
  end

  defp compose_cards_query({"order_by", {direction, field}}, query) do
    query
    |> order_by([card: c], [{^direction, field(c, ^field)}])
  end

  defp compose_cards_query({"offset", offset}, query), do: offset(query, ^offset)
  defp compose_cards_query({"limit", limit}, query), do: limit(query, ^limit)

  # Emerald dream malorne and naralex were marked as not collectible prior to 32.0
  defp compose_cards_query({"collectible", collectible}, query)
       when collectible in [true, "yes", "true"],
       do: query |> where([card: c], c.collectible or c.id in [114_849, 115_186])

  defp compose_cards_query({"collectible", collectible}, query) when is_boolean(collectible),
    do: query |> where([card: c], c.collectible == ^collectible)

  defp compose_cards_query({"collectible", col}, query) when col in ["no", "false"],
    do: compose_cards_query({"collectible", false}, query)

  defp compose_cards_query({"collectible", _}, query),
    do: compose_cards_query({"collectible", true}, query)

  defp compose_cards_query({"search", search_term}, query) do
    search = "%#{search_term}%"

    query
    |> where(
      [card: c, minion_type: mt, factions: f, spell_school: ss, rarity: r],
      ilike(c.name, ^search) or ilike(c.text, ^search) or ilike(mt.name, ^search) or
        ilike(f.name, ^search) or ilike(ss.name, ^search) or ilike(r.name, ^search) or
        ilike(fragment("array_to_string(?,'|||||')", c.nicknames), ^search)
    )
  end

  defp compose_cards_query({"name", name}, query),
    do: query |> where([card: c], ilike(c.name, ^name))

  defp compose_cards_query({"mana_cost", "<" <> mana_cost}, query),
    do: query |> where([card: c], c.mana_cost < ^mana_cost)

  defp compose_cards_query({"mana_cost", ">" <> mana_cost}, query),
    do: query |> where([card: c], c.mana_cost > ^mana_cost)

  defp compose_cards_query({"mana_cost", mana_cost}, query),
    do: query |> where([card: c], c.mana_cost == ^mana_cost)

  defp compose_cards_query({"health", "<" <> health}, query),
    do: query |> where([card: c], c.health < ^health)

  defp compose_cards_query({"health", ">" <> health}, query),
    do: query |> where([card: c], c.health > ^health)

  defp compose_cards_query({"health", health}, query),
    do: query |> where([card: c], c.health == ^health)

  defp compose_cards_query({"attack", "<" <> attack}, query),
    do: query |> where([card: c], c.attack < ^attack)

  defp compose_cards_query({"attack", ">" <> attack}, query),
    do: query |> where([card: c], c.attack > ^attack)

  defp compose_cards_query({"attack", attack}, query),
    do: query |> where([card: c], c.attack == ^attack)

  defp compose_cards_query({"card_set_id", card_sets}, query) when is_list(card_sets) do
    dynamic =
      Enum.reduce(card_sets, dynamic(false), fn id_raw, dynamic ->
        id = Util.to_int_or_orig(id_raw)
        dynamic(^dynamic or ^card_set_id_dynamic(id))
      end)

    query |> where(^dynamic)
  end

  defp compose_cards_query({"card_set_id", nil}, query), do: query

  defp compose_cards_query({"card_set_id", id}, query) do
    compose_cards_query({"card_set_id", [id]}, query)
  end

  defp compose_cards_query({"card_set_id_not_in", ids}, query) when is_list(ids) do
    query
    |> where([card: c], c.card_set_id not in ^ids)
  end

  defp compose_cards_query({"card_set_group_slug", group_slug}, query) do
    set_ids = sets_in_group(group_slug) |> Enum.map(& &1.id)
    compose_cards_query({"card_set_id", set_ids}, query)
  end

  @ilike_name_or_slug_fields [
    {["set", "sets", "card_set", "card_sets"], :card_set},
    {["type", "types", "card_type", "card_types"], :card_type},
    {["class", "classes"], :classes},
    {["keywords", "keyword"], :keywords},
    {["factions", "faction"], :factions},
    {["rarity", "rarities"], :rarity},
    {["school", "schools", "spell_school", "spell_schools"], :spell_school}
  ]
  for {search_fields, join_field} <- @ilike_name_or_slug_fields, search <- search_fields do
    defp compose_cards_query({unquote(search), value}, query),
      do: ilike_name_or_slug(value, query, unquote(join_field))
  end

  @default_splitter "|"
  defp compose_cards_query({"minion_type", value}, query),
    do: ilike_name_or_slug([value, "all"], query, :minion_type)

  defp compose_cards_query({"format", format}, query) when format in [1, "1"],
    do: compose_cards_query({"format", "wild"}, query)

  defp compose_cards_query({"format", format}, query) when format in [2, "2"],
    do: compose_cards_query({"format", "standard"}, query)

  defp compose_cards_query({"format", format}, query) when format in [4, "4"],
    do: compose_cards_query({"format", "twist"}, query)

  defp compose_cards_query({"format", format}, query)
       when format in [
              "standard",
              "wild",
              "twist",
              "arena",
              "standard_2025",
              "standard_2024",
              "ed_prerelease_brawl"
            ] do
    compose_cards_query({"card_set_group_slug", format}, query)
  end

  defp compose_cards_query({"format", _}, query), do: query

  defp compose_cards_query({:card_pool, true}, query), do: query

  defp compose_cards_query({:card_pool, pool_filters}, query) do
    dynamic =
      Enum.reduce(pool_filters, dynamic(false), fn
        %{card_set_id: id, class: class, not_tourist: true}, dynamic ->
          dynamic(
            [classes: cl, card: c],
            ^dynamic or
              (ilike(cl.slug, ^class) and c.card_set_id == ^id and
                 not ilike(c.text, "% Tourist</b>%"))
          )

        %{class: class}, dynamic ->
          dynamic([classes: cl], ^dynamic or ilike(cl.slug, ^class))
      end)

    query |> where(^dynamic)
  end

  defp card_set_id_dynamic(id) do
    dynamic(
      [card_set: s, card: c],
      s.id == ^id or
        fragment(
          "EXISTS(SELECT card_id FROM public.hs_extra_card_set WHERE card_set_id = ? AND card_id = ?)",
          ^id,
          c.id
        )
    )
  end

  defp ilike_name_or_slug(searches, query, on_thing) when is_list(searches) do
    conditions =
      Enum.reduce(searches, false, fn s, prev ->
        dynamic([{^on_thing, t}], ilike(t.name, ^s) or ilike(t.slug, ^s) or ^prev)
      end)

    query
    |> where(^conditions)
  end

  defp ilike_name_or_slug(search, query, on_thing, splitter \\ @default_splitter) do
    String.split(search, splitter)
    |> ilike_name_or_slug(query, on_thing)
  end

  defp set_group_sets_query(slug) do
    from(sg in SetGroup,
      where: sg.slug == ^slug,
      select: fragment("UNNEST(?)", sg.card_sets)
    )
  end

  @spec sets_in_group(group_slug :: Binary.t()) :: [Set.t()]
  def sets_in_group(group_slug) do
    subquery = set_group_sets_query(group_slug)
    query = from s in Set, where: s.slug in subquery(subquery)
    Repo.all(query)
  end

  defp base_cards_query() do
    from(c in Card,
      as: :card,
      left_join: cs in assoc(c, :card_set),
      as: :card_set,
      left_join: ct in assoc(c, :card_type),
      as: :card_type,
      left_join: k in assoc(c, :keywords),
      as: :keywords,
      left_join: f in assoc(c, :factions),
      as: :factions,
      left_join: cl in assoc(c, :classes),
      as: :classes,
      left_join: mt in assoc(c, :minion_type),
      as: :minion_type,
      left_join: r in assoc(c, :rarity),
      as: :rarity,
      left_join: ss in assoc(c, :spell_school),
      as: :spell_school,
      # preload like this to avoid an extra query and also so that ecto deduplicates many_to_many caused duplication
      preload: [
        card_set: cs,
        card_type: ct,
        keywords: k,
        factions: f,
        rarity: r,
        classes: cl,
        minion_type: mt,
        spell_school: ss
      ]
    )
  end

  # @spec lineup_stats([Lineup.t()]) :: %{lineup_count: integer(), frequencies: frequencies}
  # def lineups_stats(lineups) do
  #   # IO.inspect(Enum.count(lineups))
  #   lineup_count = Enum.count(lineups)
  #   archetypes = Enum.flat_map(lineups, & Deck.archetype(&1.decks))
  #   Enum.frequencies(archetypes)
  #   |> Enum.group_by(& elem(&1, 0) |> Deck.extract_class())
  # end
  def lineups(criteria) do
    base_lineups_query()
    |> build_lineups_query(criteria)
    |> Repo.all()
  end

  defp base_lineups_query() do
    from(l in Lineup,
      as: :lineup,
      join: ld in assoc(l, :decks),
      preload: [decks: ld]
    )
  end

  defp build_lineups_query(query, criteria),
    do: Enum.reduce(criteria, query, &compose_lineups_query/2)

  # should return no results
  defp compose_lineups_query({"tournament_id", nil}, query) do
    query
    |> where([lineup: l], 1 == 2)
  end

  defp compose_lineups_query({"tournament_id", tournament_id}, query) do
    query
    |> where([lineup: l], l.tournament_id == ^tournament_id)
  end

  defp compose_lineups_query({"tournament_source", tournament_source}, query) do
    query
    |> where([lineup: l], l.tournament_source == ^tournament_source)
  end

  defp compose_lineups_query({"decks", decks}, query) do
    decks
    |> Enum.reduce(query, &lineup_deck_subquery/2)
  end

  defp compose_lineups_query({"name", name}, query) do
    query
    |> where([lineup: l], l.name == ^name)
  end

  defp compose_lineups_query({"order_by", {direction, "display_or_name"}}, query) do
    partial_criteria = for field <- [:display_name, :name], do: {"order_by", {direction, field}}
    build_lineups_query(query, partial_criteria)
  end

  defp compose_lineups_query({"order_by", {direction, field}}, query) do
    query
    |> order_by([{^direction, ^field}])
  end

  defp lineup_deck_subquery(criteria, query) do
    base_query =
      from(ld in LineupDeck,
        as: :lineup_deck,
        join: d in assoc(ld, :deck),
        as: :deck,
        select: ld.lineup_id
      )

    sub_query = criteria |> Enum.reduce(base_query, &compose_decks_query/2)
    query |> where([lineup: l], l.id in subquery(sub_query))
  end

  def tournament_standings_url("battlefy", id), do: "/battlefy/tournament/#{id}"
  def tournament_standings_url(_, _), do: nil

  def get_tournament_ids_for_source(source) do
    query =
      from(l in Lineup,
        select: l.tournament_id,
        where: l.tournament_source == ^source,
        group_by: l.tournament_id
      )

    Repo.all(query)
  end

  def get_latest_tournament_id_for_source(source) do
    query =
      from(l in Lineup,
        where: l.tournament_source == ^source,
        order_by: [desc: l.inserted_at],
        select: l.tournament_id,
        limit: 1
      )

    Repo.one(query)
  end

  def lineup_history(source, name) do
    [{"tournament_source", source}, {"name", name}, {"order_by", {:desc, :inserted_at}}]
    |> lineups()
  end

  @doc """
  If the hero isn't available then it defaults to the basic hero for the class
  """
  @spec hero(Deck.t()) :: card()
  def hero(%{hero: hero} = deck) do
    with nil <- get_card(hero) do
      deck.class
      |> Deck.get_basic_hero()
      |> get_card()
    end
  end

  @spec update_card(card()) :: any()
  def update_card(card) do
    do_update_cards(%{"card" => Card.dbf_id(card)})
  end

  @spec update_collectible_cards(Map.t()) :: any()
  def update_collectible_cards(additional_args \\ %{}) do
    args = Map.merge(%{collectible: "1", locale: "en_US", pageSize: 420_069}, additional_args)
    do_update_cards(args)
  end

  @spec update_all_cards(Map.t()) :: any()
  def update_all_cards(additional_args \\ %{}) do
    args = Map.merge(%{collectible: "0,1", locale: "en_US", pageSize: 420_069}, additional_args)
    do_update_cards(args)
  end

  defp do_update_cards(args, attempt \\ 1)

  defp do_update_cards(args, attempt) when attempt > 4,
    do: Logger.error("Too many retries, giving up on updating #{inspect(args)}")

  defp do_update_cards(args, attempt) do
    case Api.get_all_cards(args) do
      {:ok, cards} ->
        Logger.info("Fetched cards for updating")
        upsert_cards(cards)
        CardBag.refresh_table()

      {:error, error} ->
        Logger.error("Error updating cards (retry: #{attempt}) #{inspect(error)} ")
        Process.sleep(25_000)
        Logger.info("Retrying")
        do_update_cards(args, attempt + 1)
    end
  end

  @type deck_info :: %{archetype: String.t(), deckcode: String.t(), name: String.t()}
  @spec deck_info(Deck.t()) :: deck_info()
  def deck_info(deck) do
    %{
      archetype: Deck.archetype(deck),
      deckcode: Deck.deckcode(deck),
      name: Deck.name(deck)
    }
  end

  # def canonical_id(id, prev \\ [])

  def canonical_id(id) when Card.is_zilliax_art(id) do
    Card.pink_zilly()
  end

  def canonical_id(id) do
    with nil <- CardBag.card(id),
         nil <- get_card(id) do
      id
    else
      %{canonical_id: canonical_id} when is_integer(canonical_id) -> canonical_id
      _ -> id
    end
  end

  @initial_release_date_info [
    {"Perils in Paradise", "July 23, 2024", ~N[2024-07-23 00:00:00]},
    {"Whizbang's Workshop", "March 19, 2024", ~N[2024-03-19 00:00:00]},
    {"Event", "February 13, 2024", ~N[2024-02-13 00:00:00]},
    {"Showdown in the Badlands", "November 14, 2023", ~N[2023-11-14 00:00:00]},
    {"TITANS", "August 1, 2023", ~N[2023-08-01 00:00:00]},
    {"Festival of Legends", "April 11, 2023", ~N[2023-04-11 00:00:00]},
    {"Core", "March 30, 2021", ~N[2021-03-30 00:00:00]},
    {"Caverns of Time", "August 31, 2023", ~N[2023-08-31 00:00:00]},
    {"March of the Lich King", "December 6, 2022", ~N[2022-12-06 00:00:00]},
    {"Path of Arthas", "December 6, 2022", ~N[2022-12-06 00:00:00]},
    {"Murder at Castle Nathria", "August 2, 2022", ~N[2022-08-02 00:00:00]},
    {"Voyage to the Sunken City", "April 12, 2022", ~N[2022-04-12 00:00:00]},
    {"Fractured in Alterac Valley", "December 7, 2021", ~N[2021-12-07 00:00:00]},
    {"United in Stormwind", "August 3, 2021", ~N[2021-08-03 00:00:00]},
    {"Legacy", "March 30, 2021", ~N[2021-03-30 00:00:00]},
    {"Forged in the Barrens", "March 30, 2021", ~N[2021-03-30 00:00:00]},
    {"Madness at the Darkmoon Faire", "November 17, 2020", ~N[2020-11-17 00:00:00]},
    {"Scholomance Academy", "August 6, 2020", ~N[2020-08-06 00:00:00]},
    {"Demon Hunter Initiate", "April 7, 2020", ~N[2020-04-07 00:00:00]},
    {"Ashes of Outland", "April 7, 2020", ~N[2020-04-07 00:00:00]},
    {"Galakrond’s Awakening", "January 21, 2020", ~N[2020-01-21 00:00:00]},
    {"Descent of Dragons", "December 10, 2019", ~N[2019-12-10 00:00:00]},
    {"Saviors of Uldum", "August 6, 2019", ~N[2019-08-06 00:00:00]},
    {"Rise of Shadows", "April 9, 2019", ~N[2019-04-09 00:00:00]},
    {"Rastakhan’s Rumble", "December 4, 2018", ~N[2018-12-04 00:00:00]},
    {"The Boomsday Project", "August 7, 2018", ~N[2018-08-07 00:00:00]},
    {"The Witchwood", "April 12, 2018", ~N[2018-04-12 00:00:00]},
    {"Kobolds and Catacombs", "December 7, 2017", ~N[2017-12-07 00:00:00]},
    {"Knights of the Frozen Throne", "August 10, 2017", ~N[2017-08-10 00:00:00]},
    {"Journey to Un’Goro", "April 6, 2017", ~N[2017-04-06 00:00:00]},
    {"Mean Streets of Gadgetzan", "December 1, 2016", ~N[2016-12-01 00:00:00]},
    {"One Night in Karazhan", "August 11, 2016", ~N[2016-08-11 00:00:00]},
    {"Whispers of the Old Gods", "April 26, 2016", ~N[2016-04-26 00:00:00]},
    {"League of Explorers", "November 12, 2015", ~N[2015-11-12 00:00:00]},
    {"The Grand Tournament", "August 24, 2015", ~N[2015-08-24 00:00:00]},
    {"Blackrock Mountain", "April 2, 2015", ~N[2015-04-02 00:00:00]},
    {"Goblins vs Gnomes", "December 8, 2014", ~N[2014-12-08 00:00:00]},
    {"Curse of Naxxramas", "July 22, 2014", ~N[2014-07-22 00:00:00]},
    {"Legacy", "March 14, 2014", ~N[2014-03-14 00:00:00]}
  ]
  def init_card_set_release_date(release_date_info \\ @initial_release_date_info) do
    sets = card_sets()

    Enum.reduce(sets, Multi.new(), fn set, multi ->
      case List.keyfind(release_date_info, set.name, 0) do
        {_set_name, _, release_date} ->
          changeset = Set.set_release_date(set, release_date)
          Multi.update(multi, "card_set_#{set.id}_#{set.name}", changeset)

        _ ->
          multi
      end
    end)
    |> Repo.transaction()

    CardBag.refresh_table()
  end

  def set_referent_card_ids() do
    collectible = cards([{"collectible", true}, :actual_card_set, not_classic_card_criteria()])
    grouped = Enum.group_by(collectible, &Card.same_card_grouper/1)

    Enum.reduce(grouped, Multi.new(), &do_handle_card_ids_group/2)
    |> Repo.transaction()

    CardBag.refresh_table()
  end

  # single card with ids already set to itself
  defp do_handle_card_ids_group(
         {_, [%{id: same_id, canonical_id: same_id, deckcode_copy_id: same_id}]},
         multi
       )
       when is_integer(same_id),
       do: multi

  # single card without ids set to itself
  defp do_handle_card_ids_group({group, [card]}, multi) do
    changeset = Card.set_referent_card_ids(card, card.id, card.id)
    Multi.update(multi, "#{group}_#{card.id}", changeset)
  end

  defp do_handle_card_ids_group({group, cards}, multi) do
    {oldest, newest} =
      cards
      |> with_usable_sets()
      |> Enum.min_max_by(&(&1.card_set.release_date |> to_string))

    deckcode_copy_id = newest.id

    canonical_id =
      Enum.map(cards, & &1.canonical_id)
      |> Enum.uniq()
      |> Enum.filter(& &1)
      |> case do
        [existing_canonical_id] ->
          existing_canonical_id

        [] ->
          oldest.id

        _ ->
          raise "Multiple canonical ids found for group [#{Enum.map_join(cards, ", ", & &1.id)}]"
      end

    Enum.reduce(cards, multi, fn card, multi ->
      if card.deckcode_copy_id != deckcode_copy_id or card.canonical_id != canonical_id do
        changeset = Card.set_referent_card_ids(card, canonical_id, deckcode_copy_id)
        Multi.update(multi, "#{group}_#{card.id}", changeset)
      else
        multi
      end
    end)
  end

  defp with_usable_sets(cards) do
    Enum.filter(cards, & &1.card_set.release_date)
  end

  @spec fix_cards_and_deckcode(NaiveDateTime.t() | DateTime.t() | String.t()) :: any()
  def fix_cards_and_deckcode(cutoff_date) do
    needs_fixing = needs_cards_and_deckcode_fixing(cutoff_date)
    IO.puts("Number needs fixing #{Enum.count(needs_fixing)}")

    Enum.reduce(needs_fixing, Multi.new(), fn val, m ->
      changeset = Deck.cards_and_deckcode_changeset(val)
      Multi.update(m, "deck_#{val.id}_#{val.deckcode}", changeset, on_conflict: :nothing)
    end)
    |> Repo.transaction(timeout: :infinity)
  end

  @spec needs_cards_and_deckcode_fixing(NaiveDateTime.t() | DateTime.t() | String.t()) :: [
          Deck.t()
        ]
  def needs_cards_and_deckcode_fixing(cutoff_date) do
    query = from d in Deck, where: d.inserted_at >= ^cutoff_date
    decks = Repo.all(query, timeout: :infinity)

    Enum.filter(decks, fn %{cards: cards, deckcode: deckcode, sideboards: sideboards} = deck ->
      cards != Deck.canonicalize_cards(cards) or
        deckcode != Deck.deckcode(deck) or
        sideboards != Deck.canonicalize_sideboards(sideboards)
    end)
  end

  def deduplicate_decks_after_date(cutoff_date) do
    query = from d in Deck, where: d.inserted_at >= ^cutoff_date
    decks = Repo.all(query, timeout: :infinity)
    grouped = Enum.group_by(decks, &Backend.Hearthstone.Deck.deckcode/1)
    dupl = Enum.filter(grouped, fn {_, d} -> Enum.count(d) > 1 end)
    IO.puts("Number of duplicated #{Enum.count(dupl)}")

    for {_, decks} <- dupl do
      ids = Enum.map(decks, & &1.id)

      try do
        deduplicate_ids(ids)
      rescue
        _ -> IO.puts("Error fixing #{inspect(ids)}")
      end
    end
  end

  @spec minion_type_options(mode :: integer() | String.t() | atom()) :: [
          {slug :: String.t(), name :: String.t()}
        ]
  def minion_type_options(mode) when is_integer(mode) do
    Repo.all(from mt in MinionType, where: ^mode in mt.game_modes)
    |> to_slug_name_options()
  end

  def minion_type_options(mode) when is_atom(mode),
    do: mode |> to_string() |> minion_type_options()

  def minion_type_options(mode) when is_binary(mode) do
    %{id: id} =
      Repo.one(from gm in GameMode, where: ilike(gm.slug, ^mode) or ilike(gm.name, ^mode))

    minion_type_options(id)
  end

  @spec spell_school_options() :: [{slug :: String.t(), name :: String.t()}]
  def spell_school_options() do
    spell_schools()
    |> to_slug_name_options()
  end

  @spec rarity_options() :: [{slug :: String.t(), name :: String.t()}]
  def rarity_options() do
    rarities()
    |> to_slug_name_options()
  end

  @spec faction_options() :: [{slug :: String.t(), name :: String.t()}]
  def faction_options() do
    factions()
    |> to_slug_name_options()
  end

  defp to_slug_name_options(thing) do
    Enum.map(thing, fn
      %{slug: slug, name: name} -> {slug, name}
    end)
  end
end
