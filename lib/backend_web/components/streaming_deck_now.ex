defmodule Components.StreamingDeckNow do
  @moduledoc false
  use Surface.Component
  alias Backend.Streaming.StreamingNow
  alias BackendWeb.Router.Helpers, as: Routes
  alias BackendWeb.StreamingNowLive

  prop(deck, :map, required: true)
  data(link, :string)
  data(count, :integer)

  def render(assigns = %{count: _, link: _}) do
    ~F"""
      <a :if={@count > 0} href={"#{@link}"} class="tag column is-twitch" >
        # Live: {@count}
      </a>
    """
  end
  def render(assigns = %{deck: %{deckcode: deckcode}}) do
    count =
      StreamingNow.streaming_now()
      |> Enum.filter(&(&1.deckcode == deckcode))
      |> Enum.count()

    link = Routes.live_path(BackendWeb.Endpoint, StreamingNowLive, %{"deckcode" => deckcode})

    assigns |> assign(count: count, link: link) |> render()
  end

  def render(assigns),
    do: ~F"""
    """
end
