defmodule BackendWeb.FeedLive do
  @moduledoc false
  alias Backend.Feed
  alias Components.Feed.DeckFeedItem
  alias Components.Feed.LatestHSArticles
  alias Components.Feed.TierList
  alias Components.OmniBar
  use BackendWeb, :surface_live_view

  data(user, :any)
  def mount(_params, session, socket), do: {:ok, socket |> assign_defaults(session)}

  def render(assigns) do
    base_items = Feed.get_current_items()

    items =
      if is_a_me?(assigns) do
        [%{type: "tier_list"} | base_items]
      else
        base_items
      end

    ~F"""
    <Context put={user: @user} >
      <div>
        <br>
        <div class="level is-mobile">
          <div :if={true} class="level-item">
            <OmniBar id="omni_bar_id"/>
          </div>
          <div class="level-item">
            <div id="nitropay-below-title-leaderboard"></div>
          </div>
          <div :if={false} class="level-item title is-2">Well Met!</div>
        </div>
        <div class="columns is-multiline is-mobile is-narrow is-centered">
          <div :for={item <- items} class="column is-narrow">
            <div :if={item.type == "deck"}>
              <DeckFeedItem item={item}/>
            </div>
            <div :if={item.type == "latest_hs_articles"}>
              <LatestHSArticles />
            </div>
            <div :if={item.type == "tier_list"}>
              <TierList />
            </div>
          </div>
        </div>
      </div>
    </Context>
    """
  end

  def handle_event("deck_copied", _, socket), do: {:noreply, socket}
  def is_a_me?(%{user: %{id: 1}}), do: true
  def is_a_me?(_), do: false

  def handle_info({:incoming_result, result}, socket) do
    OmniBar.incoming_result(result, "omni_bar_id")
    {:noreply, socket}
  end
end
