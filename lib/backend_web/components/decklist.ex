defmodule Components.Decklist do
  @moduledoc false
  use Surface.Component
  alias Components.DecklistCard
  alias Components.DecklistHero
  alias Backend.Hearthstone
  alias Backend.Hearthstone.Deck
  alias Backend.HearthstoneJson.Card
  use BackendWeb.ViewHelpers
  prop(deck, :map, required: true)
  prop(name, :string, required: false)
  slot(right_button)

  @spec deck_name(String.t() | nil, Deck.t(), Card.t()) :: String.t()
  def deck_name(name, _, _) when is_binary(name) and bit_size(name) > 0, do: name
  def deck_name(_, %{class: c}, _) when is_binary(c), do: c |> Deck.class_name()
  def deck_name(_, _, %{card_class: c}) when is_binary(c), do: c |> Deck.class_name()
  def deck_name(_, _, _), do: ""

  @spec deck_class(Deck.t(), Card.t()) :: String.t()
  defp deck_class(%{class: c}, _) when is_binary(c), do: c
  defp deck_class(_, %{card_class: c}) when is_binary(c), do: c
  defp deck_class(_, _), do: "NEUTRAL"

  def render(assigns) do
    deck = assigns[:deck]

    cards =
      deck.cards
      |> Hearthstone.ordered_frequencies()

    hero = Backend.HearthstoneJson.get_hero(deck)
    deckcode = render_deckcode(deck.deckcode, false)

    class_class = deck_class(deck, hero) |> String.downcase()

    name = deck_name(assigns[:name], deck, hero)

    ~H"""
      <div>

          <div class=" decklist-hero {{ class_class }}" style="margin-bottom: 0px;"> 
              <div class="level is-mobile">
                  <div class="level-left"> 
                      {{ deckcode }}
                  </div>
                  <div class="level-item deck-text"> 
                    <span><span style="font-size:0;">### </span> {{ name }}
    <span style="font-size: 0; line-size:0; display:block">
    {{ @deck |> Deck.deckcode() }}</span></span>
                  </div> 
                  <div class="level-right"> 
                      <slot name="right_button"/>
                  </div>
              </div>
          </div>
          <div class="decklist_card_container" :for = {{ {card, count} <- cards }}>
              <DecklistCard card={{ card }} count={{ count }}/>
          </div>
          <span style="font-size: 0; line-size:0; display:block">
            # You really like to select a lot of stuff, don't ya you beautiful being! 🤎 D0nkey
          </span>
      </div>
    """
  end
end
