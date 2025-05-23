defmodule Components.Filter.RankDropdown do
  @moduledoc false
  use Surface.LiveComponent
  alias Components.LivePatchDropdown
  alias Hearthstone.DeckTracker
  prop(title, :string, default: "Rank")
  prop(param, :string, default: "rank")
  prop(url_params, :map, from_context: {Components.LivePatchDropdown, :url_params})
  prop(path_params, :map, from_context: {Components.LivePatchDropdown, :path_params})
  prop(selected_params, :map, from_context: {Components.LivePatchDropdown, :selected_params})
  prop(filter_context, :atom, default: :public)
  prop(live_view, :module, required: true)
  prop(aggregated_only, :boolean, default: false)
  prop(warning, :boolean, default: false)

  def render(assigns) do
    ~F"""
    <span>
      <LivePatchDropdown
        options={options(@filter_context, @aggregated_only)}
        title={@title}
        param={@param}
        warning={@warning}
        url_params={@url_params}
        path_params={@path_params}
        selected_params={@selected_params}
        live_view={@live_view} />
    </span>
    """
  end

  def options(context, aggregated_only \\ false) do
    aggregated = DeckTracker.aggregated_ranks()

    for %{slug: slug, display: d} <- DeckTracker.ranks_for_filters(context),
        !aggregated_only or slug in aggregated do
      display =
        if slug in aggregated or context == :personal,
          do: d,
          else: Components.Helper.warning_triangle(%{before: d})

      {slug, display}
    end
  end

  def default(context \\ :public) do
    DeckTracker.default_rank(context)
  end
end
