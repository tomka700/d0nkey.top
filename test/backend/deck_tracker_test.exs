defmodule Hearthstone.DeckTrackerTest do
  use Backend.DataCase
  alias Hearthstone.DeckTracker

  describe "games" do
    alias Hearthstone.DeckTracker.Game
    alias Hearthstone.DeckTracker.GameDto
    alias Hearthstone.DeckTracker.PlayerDto
    alias Hearthstone.DeckTracker.RawPlayerCardStats

    @valid_dto %GameDto{
      player: %PlayerDto{
        battletag: "D0nkey#2470",
        rank: 51,
        legend_rank: 512,
        deckcode:
          "AAECAa0GCJu6A8i+A5vYA/voA9TtA6bvA8jvA4WfBAuTugOvugPezAPXzgP+0QPi3gP44wOW6AOa6wOe6wOU7wMA"
      },
      opponent: %PlayerDto{
        battletag: "BlaBla#14314",
        rank: 50,
        legend_rank: nil
      },
      game_id: "first_game",
      game_type: 7,
      format: 2,
      region: "KR"
    }
    @minimal_dto %GameDto{
      player: %PlayerDto{
        battletag: "D0nkey#2470",
        rank: nil,
        legend_rank: nil,
        deckcode:
          "AAECAa0GCJu6A8i+A5vYA/voA9TtA6bvA8jvA4WfBAuTugOvugPezAPXzgP+0QPi3gP44wOW6AOa6wOe6wOU7wMA"
      },
      opponent: %PlayerDto{
        battletag: nil,
        rank: nil,
        legend_rank: nil
      },
      result: "WON",
      game_id: "bla bla car",
      game_type: 7,
      format: 2
    }

    @with_known_card_stats %GameDto{
      player: %PlayerDto{
        battletag: "D0nkey#2470",
        rank: nil,
        legend_rank: nil,
        cards_in_hand_after_mulligan: [%{card_dbf_id: 74097, kept: false}],
        cards_drawn_from_initial_deck: [%{card_dbf_id: 74097, turn: 3}],
        deckcode:
          "AAECAa0GCJu6A8i+A5vYA/voA9TtA6bvA8jvA4WfBAuTugOvugPezAPXzgP+0QPi3gP44wOW6AOa6wOe6wOU7wMA"
      },
      opponent: %PlayerDto{
        battletag: nil,
        rank: nil,
        legend_rank: nil
      },
      result: "WON",
      game_id: "bla bla car",
      game_type: 7,
      format: 2
    }
    @with_unknown_card_stats %GameDto{
      player: %PlayerDto{
        battletag: "D0nkey#2470",
        rank: nil,
        legend_rank: nil,
        cards_in_hand_after_mulligan: [%{card_id: "THIS DOEST NOT EXIST", kept: false}],
        cards_drawn_from_initial_deck: [%{card_id: "CORE_CFM_753", turn: 3}],
        deckcode:
          "AAECAa0GCJu6A8i+A5vYA/voA9TtA6bvA8jvA4WfBAuTugOvugPezAPXzgP+0QPi3gP44wOW6AOa6wOe6wOU7wMA"
      },
      opponent: %PlayerDto{
        battletag: nil,
        rank: nil,
        legend_rank: nil
      },
      result: "WON",
      game_id: "bla bla car",
      game_type: 7,
      format: 2
    }

    test "handle_game/1 returns new game and updates it" do
      assert {:ok, %Game{status: :in_progress, turns: nil, duration: nil}} =
               DeckTracker.handle_game(@valid_dto)

      update_dto = %{@valid_dto | result: "WON", turns: 7, duration: 480}
      assert {:ok, %{status: :win, turns: 7, duration: 480}} = DeckTracker.handle_game(update_dto)
    end

    test "handle_game/1 supports minimal info" do
      assert {:ok, %Game{status: :win, turns: nil, duration: nil, game_id: "bla bla car"}} =
               DeckTracker.handle_game(@minimal_dto)
    end

    test "handle_game/1 saves raw stats when card is not known" do
      assert {:ok, %Game{status: :win, turns: nil, duration: nil, game_id: "bla bla car"} = game} =
               DeckTracker.handle_game(@with_unknown_card_stats)

      preloaded = Backend.Repo.preload(game, :raw_player_card_stats)
      assert %{cards_in_hand_after_mulligan: _} = preloaded.raw_player_card_stats
    end

    test "handle_game/1 saves card_tallies when cards are known" do
      assert {:ok, %Game{status: :win, turns: nil, duration: nil, game_id: "bla bla car"} = game} =
               DeckTracker.handle_game(@with_known_card_stats)

      preloaded = Backend.Repo.preload(game, :card_tallies)
      assert %{card_tallies: [_ | _]} = preloaded
    end

    test "doesn't convert freshly inserted raw_stats" do
      assert {:ok, %Game{status: :win, turns: nil, duration: nil, game_id: "bla bla car"} = game} =
               DeckTracker.handle_game(@with_unknown_card_stats)

      assert %{cards_in_hand_after_mulligan: _} = DeckTracker.raw_stats_for_game(game)

      DeckTracker.convert_raw_stats_to_card_tallies()

      assert [] = DeckTracker.card_tallies_for_game(game)
      assert %{cards_drawn_from_initial_deck: _} = DeckTracker.raw_stats_for_game(game)
    end

    test "converts raw_stats_with_known_cards" do
      game_dto = @valid_dto |> Map.put("game_id", Ecto.UUID.generate())
      assert {:ok, %Game{id: id} = game} = DeckTracker.handle_game(game_dto)

      raw_attrs = %{
        "game_id" => id,
        "cards_drawn_from_initial_deck" => [
          %{
            "card_dbf_id" => 74097,
            "turn" => 5
          }
        ]
      }

      {:ok, %{id: raw_stats_id}} =
        %RawPlayerCardStats{}
        |> RawPlayerCardStats.changeset(raw_attrs)
        |> Repo.insert()

      assert %{cards_in_hand_after_mulligan: _} = DeckTracker.raw_stats_for_game(game)

      DeckTracker.convert_raw_stats_to_card_tallies(min_id: raw_stats_id - 1)

      assert is_nil(DeckTracker.raw_stats_for_game(game))
      assert [_ | _] = DeckTracker.card_tallies_for_game(game)
    end
  end

  alias Hearthstone.DeckTracker.Period

  @valid_attrs %{
    auto_aggregate: true,
    display: "some display",
    hours_ago: 42,
    include_in_deck_filters: true,
    include_in_personal_filters: true,
    period_end: ~N[2023-07-30 23:22:00],
    period_start: ~N[2023-07-30 23:22:00],
    slug: "some slug",
    type: "some type"
  }
  @update_attrs %{
    auto_aggregate: false,
    display: "some updated display",
    hours_ago: 43,
    include_in_deck_filters: false,
    include_in_personal_filters: false,
    period_end: ~N[2023-07-31 23:22:00],
    period_start: ~N[2023-07-31 23:22:00],
    slug: "some updated slug",
    type: "some updated type"
  }
  @invalid_attrs %{
    auto_aggregate: nil,
    display: nil,
    hours_ago: nil,
    include_in_deck_filters: nil,
    include_in_personal_filters: nil,
    period_end: nil,
    period_start: nil,
    slug: nil,
    type: nil
  }

  describe "#paginate_periods/1" do
    test "returns paginated list of periods" do
      for _ <- 1..20 do
        period_fixture()
      end

      {:ok, %{periods: periods} = page} = DeckTracker.paginate_periods(%{})

      assert length(periods) == 15
      assert page.page_number == 1
      assert page.page_size == 15
      assert page.total_pages == 2
      assert page.total_entries == 20
      assert page.distance == 5
      assert page.sort_field == "inserted_at"
      assert page.sort_direction == "desc"
    end
  end

  describe "#list_periods/0" do
    test "returns all periods" do
      period = period_fixture()
      assert DeckTracker.list_periods() == [period]
    end
  end

  describe "#get_period!/1" do
    test "returns the period with given id" do
      period = period_fixture()
      assert DeckTracker.get_period!(period.id) == period
    end
  end

  describe "#create_period/1" do
    test "with valid data creates a period" do
      assert {:ok, %Period{} = period} = DeckTracker.create_period(@valid_attrs)
      assert period.auto_aggregate == true
      assert period.display == "some display"
      assert period.hours_ago == 42
      assert period.include_in_deck_filters == true
      assert period.include_in_personal_filters == true
      assert period.period_end == ~N[2023-07-30 23:22:00]
      assert period.period_start == ~N[2023-07-30 23:22:00]
      assert period.slug == "some slug"
      assert period.type == "some type"
    end

    test "with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = DeckTracker.create_period(@invalid_attrs)
    end
  end

  describe "#update_period/2" do
    test "with valid data updates the period" do
      period = period_fixture()
      assert {:ok, period} = DeckTracker.update_period(period, @update_attrs)
      assert %Period{} = period
      assert period.auto_aggregate == false
      assert period.display == "some updated display"
      assert period.hours_ago == 43
      assert period.include_in_deck_filters == false
      assert period.include_in_personal_filters == false
      assert period.period_end == ~N[2023-07-31 23:22:00]
      assert period.period_start == ~N[2023-07-31 23:22:00]
      assert period.slug == "some updated slug"
      assert period.type == "some updated type"
    end

    test "with invalid data returns error changeset" do
      period = period_fixture()
      assert {:error, %Ecto.Changeset{}} = DeckTracker.update_period(period, @invalid_attrs)
      assert period == DeckTracker.get_period!(period.id)
    end
  end

  describe "#delete_period/1" do
    test "deletes the period" do
      period = period_fixture()
      assert {:ok, %Period{}} = DeckTracker.delete_period(period)
      assert_raise Ecto.NoResultsError, fn -> DeckTracker.get_period!(period.id) end
    end
  end

  describe "#change_period/1" do
    test "returns a period changeset" do
      period = period_fixture()
      assert %Ecto.Changeset{} = DeckTracker.change_period(period)
    end
  end

  def period_fixture(attrs \\ %{}) do
    {:ok, period} =
      attrs
      |> Enum.into(@valid_attrs)
      |> DeckTracker.create_period()

    period
  end
end
