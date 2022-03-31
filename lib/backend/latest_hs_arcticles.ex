defmodule Backend.LatestHSArticles do
  use GenServer

  def start_link(default), do: GenServer.start_link(__MODULE__, default, name: __MODULE__)
  def init(_args) do
    {:ok, [], {:continue, :update_articles}}
  end

  def handle_continue(:update_articles, _) do
    {:ok, articles} = do_update()
    {:noreply, articles}
  end

  defp do_update() do
    with {:ok, %{body: body}} <- HTTPoison.get("https://playhearthstone.com/en-us/api/blog/articleList/?page=1&pageSize=100"),
         {:ok, decoded} <- Jason.decode(body),
         sorted <- Enum.sort_by(decoded, & &1["publish"], :desc) |> add_april_fools(),
         {:ok, _feed_item} <- update_feed_item(sorted) do
      {:ok, sorted}
    end
  end

  def add_april_fools(articles) do
    now = NaiveDateTime.utc_now()
    start_time = ~N[2022-04-01T17:00:00]
    end_time = ~N[2022-04-02T06:00:00]
    if Util.in_range?(now, {start_time, end_time}) do
      [
        %{
          "uid" => "april_fools_hahaha",
          "tags" => ["esports"],
          "blogId" => 23790401,
          "thumbnail" => %{
            "mimeType" => "imageblabla",
            "url" => "//bnetcmsus-a.akamaihd.net/cms/blog_header/s1/S1AU2IQCZ0VN1544570147263.jpg"
          },
          "title" => "Dive Deep in 2022’s Wild Open!"
        } | articles
      ]
    else
      articles
    end
  end

  def get(), do: GenServer.call(__MODULE__, :get)
  def update(), do: GenServer.cast(__MODULE__, :update)

  def patch_notes_url(), do:
    get()
    |> Enum.find_value(& "patch" in &1["tags"] && url(&1))

  def url(%{"defaultUrl" => url}), do: url
  def url(_), do: nil

  def handle_call(:get, _, articles), do: {:reply, articles, articles}
  def handle_cast(:update, old_state) do
    case do_update() do
      {:ok, articles} -> {:noreply, articles}
      _ -> {:noreply, old_state}
    end
  end

  defp update_feed_item([latest | _]) do
    params = get_feed_item_params(latest)

    Backend.Feed.handle_articles_item(latest["uid"], params)
  end

  defp get_feed_item_params(latest) do
    if "patch" in (latest["tags"] || []) do
      [decay: 0.97, head_start: 50]
    else
      [decay: 0.95, head_start: 10]
    end
  end

end
