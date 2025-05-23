defmodule BackendWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use BackendWeb, :controller
      use BackendWeb, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  def component do
    quote do
      use Phoenix.Component, global_prefixes: ~w(x-)

      unquote(view_helpers())
    end
  end

  def html do
    quote do
      unquote(component())
      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]
    end
  end

  def html_controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: BackendWeb.Layouts]

      import Plug.Conn
      import BackendWeb.Gettext

      unquote(verified_routes())
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, namespace: BackendWeb

      import Plug.Conn
      import BackendWeb.Gettext
      import Phoenix.LiveView.Controller
      alias BackendWeb.Router.Helpers, as: Routes

      action_fallback BackendWeb.FallbackController

      unquote(verified_routes())

      def multi_select_to_list(multi = %{}) do
        for {column, "true"} <- multi, do: column
      end

      def multi_select_to_list(list) when is_list(list), do: list
      def multi_select_to_list(_), do: []

      def multi_select_to_array(multi = %{}) do
        for {column, "true"} <- multi, do: column
      end

      def multi_select_to_array(_multi), do: []
      def parse_yes_no(yes_or_no, default \\ "no")
      def parse_yes_no("yes", _), do: "yes"
      def parse_yes_no("no", _), do: "no"
      def parse_yes_no(_, default), do: default

      def parse(val, options, default) do
        options
        |> Enum.find(&(&1 == val))
        |> case do
          nil -> default
          v -> v
        end
      end

      use PhoenixMetaTags.TagController
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def view do
    quote do
      use Phoenix.View,
        root: "lib/backend_web/templates",
        namespace: BackendWeb

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      # , only: [live_render: 3, form: 1]
      import Phoenix.Component

      unquote(view_helpers())
      use PhoenixMetaTags.TagView
    end
  end

  def surface_live_view do
    quote do
      use Surface.LiveView,
        layout: {BackendWeb.LayoutView, :live}

      unquote(surface())
    end
  end

  def surface_live_view_no_layout do
    quote do
      use Surface.LiveView

      unquote(surface())
    end
  end

  def surface_live_component do
    quote do
      use Surface.LiveComponent

      unquote(surface())
    end
  end

  def surface_component do
    quote do
      use Surface.Component

      unquote(surface())
    end
  end

  def surface() do
    quote do
      alias BackendWeb.Router.Helpers, as: Routes
      import BackendWeb.LiveHelpers
      import BackendWeb.LivePlug.AssignDefaults, only: [put_user_in_context: 1]

      unquote(view_helpers())

      def user_from_context(assigns) do
        Surface.Components.Context.get(assigns, :user)
      end

      def user_has_premium?(assigns) do
        case user_from_context(assigns) do
          %Backend.UserManager.User{} = user ->
            Backend.UserManager.User.premium?(user)

          _ ->
            false
        end
      end
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes, router: BackendWeb.Router, endpoint: BackendWeb.Endpoint
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {BackendWeb.LayoutView, :live}

      import BackendWeb.LiveHelpers
      unquote(view_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(view_helpers())
    end
  end

  def router do
    quote do
      use Phoenix.Router
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import BackendWeb.Gettext
    end
  end

  defp view_helpers do
    quote do
      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      # Import LiveView helpers (live_render, live_component, live_patch, etc)
      import Phoenix.LiveView.Helpers

      # Import basic rendering functionality (render, render_layout, etc)
      import Phoenix.View

      import BackendWeb.ErrorHelpers
      import BackendWeb.Gettext
      alias BackendWeb.Router.Helpers, as: Routes
      use BackendWeb.ViewHelpers
      unquote(verified_routes())

      def add_games_filters(base \\ %{}, params) do
        base
        |> add_rank(params)
        |> add_period(params)
        |> add_format(params)
      end

      def add_rank(other \\ %{}, params)

      def add_rank(other, %{rank: r}) do
        Map.put_new(other, :rank, r)
      end

      def add_rank(other, %{"rank" => r}) do
        Map.put_new(other, "rank", r)
      end

      def add_rank(other, _), do: other

      def add_period(other \\ %{}, params)

      def add_period(other, %{period: r}) do
        Map.put_new(other, :period, r)
      end

      def add_period(other, %{"period" => r}) do
        Map.put_new(other, "period", r)
      end

      def add_period(other, _), do: other

      # TODO: find a better home for this
      def add_format(other \\ %{}, params)

      def add_format(other, %{format: f}) when f not in [2, "2"],
        do: Map.put_new(other, :format, f)

      def add_format(other, %{"format" => f}) when f not in [2, "2"],
        do: Map.put_new(other, "format", f)

      def add_format(other, _), do: other
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
