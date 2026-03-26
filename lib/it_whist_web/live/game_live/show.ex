defmodule ItWhistWeb.GameLive.Show do
  use ItWhistWeb, :live_view

  alias ItWhist.Games

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Game #{@game.id}
        <:subtitle>
          Status: {@game.status}
        </:subtitle>
        <:actions>
          <.button navigate={~p"/games"}>
            <.icon name="hero-arrow-left" />
          </.button>
        </:actions>
      </.header>

      <div class="mt-6">
        <h2 class="text-lg font-semibold mb-2">Players</h2>
        <.table id="players" rows={@game.game_players}>
          <:col :let={gp} label="Nickname">{gp.player.nickname}</:col>
          <:col :let={gp} label="Name">{gp.player.name}</:col>
          <:col :let={gp} label="Score">{gp.final_score}</:col>
        </.table>
      </div>

      <div class="mt-6">
        <h2 class="text-lg font-semibold mb-2">Rounds</h2>
        <%= if Enum.empty?(@game.rounds) do %>
          <p class="text-gray-500">No rounds logged yet.</p>
        <% else %>
          <.table id="rounds" rows={@game.rounds}>
            <:col :let={round} label="Round">{round.round_number}</:col>
            <:col :let={round} label="Type">{round.game_type}</:col>
          </.table>
        <% end %>
      </div>

      <%= if @game.status == "in_progress" do %>
        <div class="mt-6">
          <.button variant="primary" navigate={~p"/games/#{@game}/rounds/new"}>
            Log Round
          </.button>
        </div>
      <% end %>

      <.list>
        <:item title="Status">{@game.status}</:item>
        <:item title="Played at">{@game.played_at}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Games.subscribe_games(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Show Game")
     |> assign(:game, Games.get_game!(id))}
  end

  @impl true
  def handle_info(
        {:updated, %ItWhist.Games.Game{id: id} = game},
        %{assigns: %{game: %{id: id}}} = socket
      ) do
    {:noreply, assign(socket, :game, game)}
  end

  def handle_info(
        {:deleted, %ItWhist.Games.Game{id: id}},
        %{assigns: %{game: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, "The current game was deleted.")
     |> push_navigate(to: ~p"/games")}
  end

  def handle_info({type, %ItWhist.Games.Game{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end
end
