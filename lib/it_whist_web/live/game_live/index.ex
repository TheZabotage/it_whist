defmodule ItWhistWeb.GameLive.Index do
  use ItWhistWeb, :live_view

  alias ItWhist.Games

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Listing Games
        <:actions>
          <.button variant="primary" navigate={~p"/games/new"}>
            <.icon name="hero-plus" /> New Game
          </.button>
        </:actions>
      </.header>

      <.table
        id="games"
        rows={@streams.games}
        row_click={fn {_id, game} -> JS.navigate(~p"/games/#{game}/view") end}
      >
        <:col :let={{_id, game}} label="Status">{game.status}</:col>
        <:col :let={{_id, game}} label="Played at">{game.played_at}</:col>
        <:action :let={{_id, game}}>
          <div class="sr-only">
            <.link navigate={~p"/games/#{game}"}>Show</.link>
          </div>
          <.link navigate={~p"/games/#{game}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, game}}>
          <.link
            phx-click={JS.push("delete", value: %{id: game.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
          >
            Delete
          </.link>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Games.subscribe_games(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Listing Games")
     |> stream(:games, list_games(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    game = Games.get_game!(id)
    {:ok, _} = Games.delete_game(game)

    {:noreply, stream_delete(socket, :games, game)}
  end

  @impl true
  def handle_info({type, %ItWhist.Games.Game{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, stream(socket, :games, list_games(socket.assigns.current_scope), reset: true)}
  end

  defp list_games(current_scope) do
    Games.list_games(current_scope)
  end
end
