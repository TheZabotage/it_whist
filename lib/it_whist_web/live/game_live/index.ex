defmodule ItWhistWeb.GameLive.Index do
  use ItWhistWeb, :live_view

  alias ItWhist.Games

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        All Games
        <:actions>
          <.button variant="primary" navigate={~p"/games/new"}>
            <.icon name="hero-plus" /> New Game
          </.button>
        </:actions>
      </.header>

      <.table
        id="games"
        rows={@streams.games}
        row_click={fn {_id, game} -> JS.navigate(~p"/games/#{game}") end}
      >
        <:col :let={{_id, game}} label="Status">{game.status}</:col>
        <:col :let={{_id, game}} label="Played at">
          {if game.played_at, do: Calendar.strftime(game.played_at, "%d. %b %Y"), else: "—"}
        </:col>
        <:col :let={{_id, game}} label="Players">
          | {Enum.map_join(game.game_players, " | ", fn gp -> gp.player.nickname end)} |
        </:col>
        <:action :let={{_id, game}}>
          <div class="sr-only">
            <.link navigate={~p"/games/#{game}"}>Show</.link>
          </div>
        </:action>
        <:action :let={{id, game}}>
          <%= if Games.game_owner?(game, @current_scope) do %>
            <.link
              phx-click={JS.push("delete", value: %{id: game.id}) |> hide("##{id}")}
              data-confirm="Are you sure?"
            >
              Delete
            </.link>
          <% end %>
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
     |> assign(:page_title, "All Games")
     |> stream(:games, Games.list_games(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    game = Games.get_game!(id)

    if Games.game_owner?(game, socket.assigns.current_scope) do
      case Games.delete_game(game) do
        {:ok, _} ->
          {:noreply, stream_delete(socket, :games, game)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not delete game. Please try again.")}
      end
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to do that.")}
    end
  end

  @impl true
  def handle_info({type, %ItWhist.Games.Game{}}, socket)
      when type in [:game_completed, :game_deleted] do
    {:noreply,
     stream(socket, :games, Games.list_games(socket.assigns.current_scope), reset: true)}
  end
end
