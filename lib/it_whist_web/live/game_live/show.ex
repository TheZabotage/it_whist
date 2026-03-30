defmodule ItWhistWeb.GameLive.Show do
  use ItWhistWeb, :live_view

  alias ItWhist.Games

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Game #{@game.id}
        <:subtitle>Status: {@game.status}</:subtitle>
        <:actions>
          <.button navigate={~p"/games"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <%= if Games.game_owner?(@game, @current_scope) do %>
            <.button variant="primary" navigate={~p"/games/#{@game}/edit"}>
              <.icon name="hero-pencil-square" /> Edit
            </.button>
          <% end %>
        </:actions>
      </.header>

      <div class="mt-6">
        <h2 class="text-lg font-semibold mb-2">Players</h2>
        <.table id="players" rows={Enum.sort_by(@game.game_players, & &1.final_score, :desc)}>
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
            <:col :let={round} label="Bidder">
              {if round.bet, do: round.bet.game_player.player.nickname, else: "—"}
            </:col>
            <:col :let={round} label="Sets Bid">
              {if round.bet, do: round.bet.sets_bid, else: "—"}
            </:col>
            <:col :let={round} label="Sets Won">
              {if round.bet, do: round.bet.sets_won || "pending", else: "—"}
            </:col>
            <:col :let={round} label="Partner Ace">
              {if round.bet, do: round.bet.partner_ace || "—", else: "—"}
            </:col>
            <:col :let={round} label="Partner">
              {if round.bet && round.bet.partner_game_player,
                do: round.bet.partner_game_player.player.nickname,
                else: "—"}
            </:col>
            <:col :let={round} label="Trumf">
              {if round.bet, do: round.bet.trumf_suit || "Trumfløs", else: "—"}
            </:col>
            <:action :let={round}>
              <%= if Games.game_owner?(@game, @current_scope) do %>
                <.link
                  phx-click={JS.push("delete_round", value: %{id: round.id})}
                  data-confirm="Are you sure?"
                  class="text-red-500"
                >
                  Delete
                </.link>
              <% end %>
            </:action>
          </.table>
        <% end %>
      </div>

      <%= if @game.status == "in_progress" && Games.game_owner?(@game, @current_scope) do %>
        <div class="mt-6 flex gap-4">
          <%= if length(@game.rounds) < 4 do %>
            <.button variant="primary" navigate={~p"/games/#{@game}/rounds/new"}>
              Log Round
            </.button>
          <% end %>
          <%= if game_completable?(@game) do %>
            <.button
              variant="primary"
              phx-click="complete_game"
              data-confirm="Are you sure you want to complete this game?"
            >
              Complete Game
            </.button>
          <% end %>
        </div>
      <% end %>
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
  def handle_event("delete_round", %{"id" => id}, socket) do
    if Games.game_owner?(socket.assigns.game, socket.assigns.current_scope) do
      round = Games.get_round!(id)
      {:ok, _} = Games.delete_round(round)
      {:noreply, assign(socket, :game, Games.get_game!(socket.assigns.game.id))}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to do that.")}
    end
  end

  @impl true
  def handle_event("complete_game", _params, socket) do
    if Games.game_owner?(socket.assigns.game, socket.assigns.current_scope) do
      {:ok, _} = Games.complete_game(socket.assigns.game, DateTime.utc_now())
      {:noreply, assign(socket, :game, Games.get_game!(socket.assigns.game.id))}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to do that.")}
    end
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

  defp game_completable?(game) do
    round_count = length(game.rounds)
    all_resolved = Enum.all?(game.rounds, fn r -> r.bet && r.bet.sets_won != nil end)
    round_count == 4 && all_resolved
  end
end
