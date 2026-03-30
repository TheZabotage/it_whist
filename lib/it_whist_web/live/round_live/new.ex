defmodule ItWhistWeb.RoundLive.New do
  use ItWhistWeb, :live_view

  alias ItWhist.Games

  @game_types_with_trumf [
    "Alm",
    "Vip",
    "Halve",
    "Gode"
  ]
  @game_types_with_partners [
    "Alm",
    "Vip",
    "Halve",
    "Sans",
    "Gode"
  ]
  @game_solo [
    "Sol",
    "Ren Sol",
    "Bordlægger",
    "Super Bordlægger"
  ]

  @impl true
  def mount(%{"game_id" => game_id}, _session, socket) do
    game = Games.get_game!(game_id)

    {:ok,
     socket
     |> assign(:game, game)
     |> assign(:stage, :bet)
     |> assign(:game_type, "Alm")
     |> assign(:round, nil)
     |> assign(:bet, nil)
     |> assign(:page_title, "Log Round")
     |> assign(:selected_partner_ace, nil)
     |> assign(:selected_trumf, nil)
     |> assign(:selected_trumf, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>Log Round</.header>
      <%= if @stage == :bet do %>
        <.render_bet_stage {assigns} />
      <% else %>
        <.render_resolve_stage {assigns} />
      <% end %>
    </Layouts.app>
    """
  end

  defp render_bet_stage(assigns) do
    ~H"""
    <form phx-submit="place_bet" phx-change="update_form" class="space-y-6">
      <div>
        <label class="font-medium">Bidder</label>
        <select name="bet[game_player_id]" class="w-full border rounded p-2">
          <%= for r <- @game.game_players do %>
            <option value={r.id}>{r.player.nickname}</option>
          <% end %>
        </select>
      </div>

      <div>
        <label class="font-medium">Game Type</label>
        <select name="bet[game_type]" class="w-full border rounded p-2">
          <%= for type <- ["Alm", "Vip", "Halve", "Sans", "Gode", "Sol", "Ren Sol", "Bordlægger", "Super Bordlægger"] do %>
            <option value={type} selected={type == @game_type}>{type}</option>
          <% end %>
        </select>
      </div>

      <div>
        <%= if @game_type in ["Sol", "Bordlægger"] do %>
          <input
            type="hidden"
            name="bet[sets_bid]"
            value="1"
            readonly
            class="w-full border rounded p-2 bg-gray-100"
          />
        <% else %>
          <%= if @game_type in ["Ren Sol", "Super Bordlægger"] do %>
            <input
              type="hidden"
              name="bet[sets_bid]"
              value="0"
              readonly
              class="w-full border rounded p-2 bg-gray-100"
            />
          <% else %>
            <label class="font-medium">Sets Bid</label>

            <select name="bet[sets_bid]" class="w-full border rounded p-2">
              <option value="" disabled>
                How many tricks can you win?
              </option>
              <%= for valid_bets <- [7, 8, 9, 10,11,12,13] do %>
                <option value={valid_bets}>{valid_bets}</option>
              <% end %>
            </select>
          <% end %>
        <% end %>
      </div>

      <%= if partner_game?(@game_type) do %>
        <div>
          <label class="font-medium">Partner Ace</label>
          <select name="bet[partner_ace]" class="w-full border rounded p-2">
            <option value="" disabled selected={is_nil(@selected_partner_ace)}>
              Choose your ace
            </option>
            <%= for suit <- ["Spades", "Hearts", "Clubs", "Diamonds"],
          suit != @selected_trumf do %>
              <option value={suit} selected={suit == @selected_partner_ace}>{suit}</option>
            <% end %>
          </select>
        </div>
      <% end %>

      <%= if trumf_game?(@game_type) do %>
        <div>
          <label class="font-medium">Trumf</label>
          <%= if @game_type == "Gode" do %>
            <input
              type="text"
              value="Clubs"
              disabled
              class="w-full border rounded p-2 bg-gray-100"
            />
            <input type="hidden" name="bet[trumf_suit]" value="Clubs" />
          <% else %>
            <select name="bet[trumf_suit]" class="w-full border rounded p-2">
              <option value="" disabled selected={is_nil(@selected_trumf)}>
                Choose your trumf
              </option>
              <%= for suit <- ["Spades", "Hearts", "Clubs", "Diamonds"],
          suit != @selected_partner_ace do %>
                <option value={suit} selected={suit == @selected_trumf}>{suit}</option>
              <% end %>
            </select>
          <% end %>
        </div>
      <% end %>

      <%= if @game_type == "Sans" do %>
        <div>
          <label class="font-medium">Trumf</label>
          <input type="text" value="Trumfløs" disabled class="w-full border rounded p-2 bg-gray-100" />
        </div>
      <% end %>

      <footer>
        <.button variant="primary" phx-disable-with="Saving...">
          Log Bet
        </.button>
        <.button navigate={~p"/games/#{@game}"}>Cancel</.button>
      </footer>
    </form>
    """
  end

  defp render_resolve_stage(assigns) do
    ~H"""
    <div class="space-y-6">
      <% bidder = find_player(@game.game_players, @bet.game_player_id) %>

      <div class="p-4 border rounded bg-gray-50">
        <p>Round: {@round.round_number} — {@round.game_type}</p>
        <p>Bidder: {bidder.player.nickname}</p>
        <p>Sets bid: {@bet.sets_bid}</p>
        <p :if={@bet.partner_ace}>Partner ace: {@bet.partner_ace}</p>
        <p :if={@bet.trumf_suit}>Trumf: {@bet.trumf_suit}</p>
      </div>

      <form phx-submit="resolve_round" class="space-y-4">
        <div>
          <label class="font-medium">
            How many tricks did {bidder.player.nickname} win?
          </label>
          <select name="resolve[sets_won]" class="w-full border rounded p-2">
            <option value="" disabled selected>Choose tricks won</option>
            <%= for tricks <- 0..13 do %>
              <option value={tricks}>{tricks}</option>
            <% end %>
          </select>
        </div>

        <%= if partner_game?(@round.game_type) do %>
          <div>
            <label class="font-medium">Who was the partner?</label>
            <select name="resolve[partner_game_player_id]" class="w-full border rounded p-2">
              <option value="" disabled selected>Choose partner</option>
              <%= for gp <- @game.game_players, gp.id != @bet.game_player_id do %>
                <option value={gp.id}>{gp.player.nickname}</option>
              <% end %>
            </select>
          </div>

          <div class="flex items-center gap-2">
            <input
              type="checkbox"
              name="resolve[is_self_partner]"
              value="false"
              id="self_partner"
            />
            <label for="self_partner">Self partner</label>
          </div>
        <% end %>

        <footer>
          <.button variant="primary" phx-disable-with="Saving...">
            Resolve Round
          </.button>
          <.button navigate={~p"/games/#{@game}"}>Cancel</.button>
        </footer>
      </form>
    </div>
    """
  end

  # Form function
  @impl true
  def handle_event("update_form", %{"bet" => params}, socket) do
    new_game_type = Map.get(params, "game_type", socket.assigns.game_type)
    game_type_changed = new_game_type != socket.assigns.game_type

    partner_ace = if game_type_changed, do: nil, else: Map.get(params, "partner_ace")

    trumf_suit =
      cond do
        # ← always Clubs for Gode
        new_game_type == "Gode" -> "Clubs"
        game_type_changed -> nil
        true -> Map.get(params, "trumf_suit")
      end

    {:noreply,
     socket
     |> assign(:game_type, new_game_type)
     |> assign(:selected_partner_ace, partner_ace)
     |> assign(:selected_trumf, trumf_suit)}
  end

  def handle_event("place_bet", %{"bet" => params}, socket) do
    game = socket.assigns.game

    with {:ok, round} <- Games.add_round(game, %{"game_type" => params["game_type"]}),
         {:ok, bet} <- Games.place_bet(round, params) do
      {:noreply,
       socket
       |> assign(:stage, :resolve)
       |> assign(:round, round)
       |> assign(:bet, bet)}
    else
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not log bet: #{inspect(reason)}")}
    end
  end

  def handle_event("resolve_round", %{"resolve" => params}, socket) do
    bet = socket.assigns.bet
    round = socket.assigns.round
    game = socket.assigns.game

    sets_won = String.to_integer(params["sets_won"])
    is_self_partner = Map.get(params, "is_self_partner") == "true"

    partner_game_player_id =
      case Map.get(params, "partner_game_player_id") do
        nil -> nil
        "" -> nil
        id -> String.to_integer(id)
      end

    scores = calculate_scores(round.game_type, bet.sets_bid, sets_won, is_self_partner)

    bidder_id = bet.game_player_id

    with {:ok, _bet} <-
           Games.resolve_bet(bet, %{
             "sets_won" => sets_won,
             "is_self_partner" => is_self_partner,
             "partner_game_player_id" => partner_game_player_id
           }),
         :ok <-
           record_all_scores(
             round,
             game.game_players,
             bidder_id,
             partner_game_player_id,
             scores,
             is_self_partner
           ) do
      {:noreply,
       socket
       |> put_flash(:info, "Round resolved!")
       |> push_navigate(to: ~p"/games/#{game}")}
    else
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not resolve round: #{inspect(reason)}")}
    end
  end

  defp calculate_scores(game_type, sets_bid, sets_won, is_self_partner) do
    case game_type do
      "Sol" ->
        if sets_won >= 1,
          do: %{winner: 150, loser: -50},
          else: %{winner: -300, loser: 100}

      "Ren Sol" ->
        if sets_won == 0,
          do: %{winner: 300, loser: -100},
          else: %{winner: -600, loser: 200}

      "Bordlægger" ->
        if sets_won >= 1,
          do: %{winner: 450, loser: -150},
          else: %{winner: -900, loser: 300}

      "Super Bordlægger" ->
        if sets_won == 0,
          do: %{winner: 600, loser: -200},
          else: %{winner: -1200, loser: 400}

      _ ->
        y = base_points(sets_bid)
        high_game = game_type in ["Vip", "Halve", "Sans", "Gode"]
        effective_y = if high_game, do: y * 2, else: y
        diff = sets_won - sets_bid

        winner_points =
          cond do
            diff == 0 && is_self_partner -> effective_y * 3
            diff == 0 -> effective_y
            diff > 0 && is_self_partner -> effective_y * diff * 3
            diff > 0 -> effective_y * diff
            diff < 0 && is_self_partner -> -(effective_y * 2 * 3 * abs(diff))
            diff < 0 -> -(effective_y * 2 * abs(diff))
          end

        loser_points = -winner_points

        %{winner: winner_points, loser: loser_points}
    end
  end

  defp base_points(sets_bet) do
    case sets_bet do
      7 -> 5
      8 -> 10
      9 -> 20
      10 -> 40
      11 -> 80
      12 -> 160
      13 -> 320
      _ -> {:error, :invalid_bet}
    end
  end

  defp partner_game?(game_type) do
    game_type in @game_types_with_partners
  end

  defp trumf_game?(game_type) do
    game_type in @game_types_with_trumf
  end

  defp solo_game?(game_type) do
    game_type in @game_solo
  end

  defp find_player(game_players, game_player_id) do
    Enum.find(game_players, fn gp -> gp.id == game_player_id end)
  end

  defp record_all_scores(round, game_players, bidder_id, partner_id, scores, is_self_partner) do
    Enum.each(game_players, fn gp ->
      points =
        cond do
          # Solo game - bidder wins/loses alone
          is_nil(partner_id) && !is_self_partner && gp.id == bidder_id ->
            scores.winner

          is_nil(partner_id) && !is_self_partner ->
            scores.loser

          # Self partner - bidder gets winner points, rest split loser
          is_self_partner && gp.id == bidder_id ->
            scores.winner

          is_self_partner ->
            scores.loser

          # Partner game - bidder and partner win, others lose
          gp.id == bidder_id ->
            scores.winner

          gp.id == partner_id ->
            scores.winner

          true ->
            scores.loser
        end

      Games.record_score(round, gp, %{"score" => points})
      Games.update_player_score(gp, points)
    end)

    :ok
  end
end
