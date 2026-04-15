defmodule ItWhistWeb.RoundLive.New do
  use ItWhistWeb, :live_view

  alias ItWhist.Games
  alias ItWhist.Games.Scoring

  @impl true
  def mount(%{"game_id" => game_id}, _session, socket) do
    game = Games.get_game!(game_id)

    if Games.game_owner?(game, socket.assigns.current_scope) do
      {:ok,
       socket
       |> assign(:game, game)
       |> assign(:stage, :bet)
       |> assign(:page_title, "Log Round")
       |> assign(:game_type, "Alm")
       |> assign(:bet_params, nil)
       |> assign(:selected_bidder_id, nil)
       |> assign(:selected_sets_bid, nil)
       |> assign(:selected_partner_ace, nil)
       |> assign(:selected_trumf, nil)
       |> assign(:is_self_partner, false)
       |> assign(:selected_sets_won, nil)}
    else
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to log rounds for this game.")
       |> push_navigate(to: ~p"/games")}
    end
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
        <select name="bet[game_player_id]" class="select select-bordered w-full">
          <%= for gp <- @game.game_players do %>
            <option value={gp.id} selected={to_string(gp.id) == @selected_bidder_id}>
              {gp.player.nickname} ({gp.player.name})
            </option>
          <% end %>
        </select>
      </div>

      <div>
        <label class="font-medium">Game Type</label>
        <select name="bet[game_type]" class="select select-bordered w-full">
          <%= for type <- Scoring.all_game_types() do %>
            <option value={type} selected={type == @game_type}>{type}</option>
          <% end %>
        </select>
      </div>

      <div>
        <%= if @game_type in ["Sol", "Bordlægger"] do %>
          <input type="hidden" name="bet[sets_bid]" value="1" />
        <% else %>
          <%= if @game_type in ["Ren Sol", "Super Bordlægger"] do %>
            <input type="hidden" name="bet[sets_bid]" value="0" />
          <% else %>
            <label class="font-medium">Sets Bid</label>
            <select name="bet[sets_bid]" class="select select-bordered w-full">
              <option value="" disabled selected={is_nil(@selected_sets_bid)}>
                How many tricks can you win?
              </option>
              <%= for n <- 7..13 do %>
                <option value={n} selected={to_string(n) == @selected_sets_bid}>{n}</option>
              <% end %>
            </select>
          <% end %>
        <% end %>
      </div>

      <%= if Scoring.has_partner?(@game_type) do %>
        <div>
          <label class="font-medium">Partner Ace</label>
          <select name="bet[partner_ace]" class="select select-bordered w-full">
            <option value="" disabled selected={is_nil(@selected_partner_ace)}>
              Choose your ace
            </option>
            <%= for suit <- Scoring.all_suits(), suit != @selected_trumf do %>
              <option value={suit} selected={suit == @selected_partner_ace}>{suit}</option>
            <% end %>
          </select>
        </div>
      <% end %>

      <%= if Scoring.has_trumf?(@game_type) do %>
        <div>
          <label class="font-medium">Trumf</label>
          <%= if @game_type == "Gode" do %>
            <input type="text" value="Clubs" disabled class="w-full border rounded p-2 " />
            <input type="hidden" name="bet[trumf_suit]" value="Clubs" />
          <% else %>
            <select name="bet[trumf_suit]" class="select select-bordered w-full">
              <option value="" disabled selected={is_nil(@selected_trumf)}>
                Choose your trumf
              </option>
              <%= for suit <- Scoring.all_suits(), suit != @selected_partner_ace do %>
                <option value={suit} selected={suit == @selected_trumf}>{suit}</option>
              <% end %>
            </select>
          <% end %>
        </div>
      <% end %>

      <%= if @game_type == "Sans" do %>
        <div>
          <label class="font-medium">Trumf</label>
          <input type="text" value="Trumfløs" disabled class="w-full border rounded p-2" />
        </div>
      <% end %>

      <footer>
        <.button variant="primary" phx-disable-with="Saving...">Log Bet</.button>
        <.button navigate={~p"/games/#{@game}"}>Cancel</.button>
      </footer>
    </form>
    """
  end

  defp render_resolve_stage(assigns) do
    ~H"""
    <div class="space-y-6">
      <% bidder = find_player(@game.game_players, parse_optional_id(@bet_params["game_player_id"])) %>

      <div class="p-4 border rounded">
        <p>Round: {length(@game.rounds) + 1} — {@bet_params["game_type"]}</p>
        <p>Bidder: {bidder.player.nickname}</p>
        <p>Sets bid: {@bet_params["sets_bid"]}</p>
        <p :if={@bet_params["partner_ace"] not in [nil, ""]}>
          Partner ace: {@bet_params["partner_ace"]}
        </p>
        <p :if={@bet_params["trumf_suit"] not in [nil, ""]}>
          Trumf: {@bet_params["trumf_suit"]}
        </p>
      </div>

      <form phx-submit="resolve_round" phx-change="update_resolve_form" class="space-y-4">
        <div>
          <label class="font-medium">
            How many tricks did {bidder.player.nickname} win?
          </label>
          <select name="resolve[sets_won]" class="select select-bordered w-full">
            <option value="" disabled selected={is_nil(@selected_sets_won)}>
              Choose amount of tricks {bidder.player.nickname} won.
            </option>
            <%= for tricks <- 0..13 do %>
              <option value={tricks} selected={to_string(tricks) == @selected_sets_won}>
                {tricks}
              </option>
            <% end %>
          </select>
        </div>

        <%= if Scoring.has_partner?(@bet_params["game_type"]) do %>
          <div class="flex items-center gap-2">
            <input type="hidden" name="resolve[is_self_partner]" value="false" />
            <input
              type="checkbox"
              name="resolve[is_self_partner]"
              value="true"
              id="self_partner"
              checked={@is_self_partner}
            />
            <label for="self_partner">Self partner</label>
          </div>

          <%= if !@is_self_partner do %>
            <div>
              <label class="font-medium">Who was the partner?</label>
              <select name="resolve[partner_game_player_id]" class="select select-bordered w-full">
                <option value="" disabled selected>Choose partner</option>
                <%= for gp <- @game.game_players,
                    gp.id != parse_optional_id(@bet_params["game_player_id"]) do %>
                  <option value={gp.id}>{gp.player.nickname}</option>
                <% end %>
              </select>
            </div>
          <% end %>
        <% end %>

        <footer>
          <.button variant="primary" phx-disable-with="Saving...">Resolve Round</.button>
          <.button navigate={~p"/games/#{@game}"}>Cancel</.button>
        </footer>
      </form>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Event Handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("update_form", %{"bet" => params}, socket) do
    new_game_type = Map.get(params, "game_type", socket.assigns.game_type)
    game_type_changed = new_game_type != socket.assigns.game_type

    partner_ace = if game_type_changed, do: nil, else: Map.get(params, "partner_ace")

    trumf_suit =
      cond do
        new_game_type == "Gode" -> "Clubs"
        game_type_changed -> nil
        true -> Map.get(params, "trumf_suit")
      end

    sets_bid =
      if game_type_changed,
        do: nil,
        else: Map.get(params, "sets_bid", socket.assigns.selected_sets_bid)

    bidder_id = Map.get(params, "game_player_id", socket.assigns.selected_bidder_id)

    {:noreply,
     socket
     |> assign(:game_type, new_game_type)
     |> assign(:selected_bidder_id, bidder_id)
     |> assign(:selected_sets_bid, sets_bid)
     |> assign(:selected_partner_ace, partner_ace)
     |> assign(:selected_trumf, trumf_suit)}
  end

  def handle_event("place_bet", %{"bet" => params}, socket) do
    case validate_bet_params(params) do
      :ok ->
        {:noreply,
         socket
         |> assign(:stage, :resolve)
         |> assign(:bet_params, params)
         |> assign(:selected_sets_won, nil)
         |> assign(:is_self_partner, false)}

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  def handle_event("update_resolve_form", %{"resolve" => params}, socket) do
    is_self_partner = Map.get(params, "is_self_partner") == "true"
    sets_won = Map.get(params, "sets_won", socket.assigns.selected_sets_won)

    {:noreply,
     socket
     |> assign(:is_self_partner, is_self_partner)
     |> assign(:selected_sets_won, sets_won)}
  end

  def handle_event("resolve_round", %{"resolve" => params}, socket) do
    game_type = socket.assigns.bet_params["game_type"]
    is_self_partner = Map.get(params, "is_self_partner") == "true"

    case validate_resolve_params(params, game_type, is_self_partner) do
      {:ok, resolve_attrs} ->
        case Games.log_round(socket.assigns.game, socket.assigns.bet_params, resolve_attrs) do
          {:ok, _round} ->
            {:noreply,
             socket
             |> put_flash(:info, "Round resolved!")
             |> push_navigate(to: ~p"/games/#{socket.assigns.game}")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Could not save round: #{inspect(reason)}")}
        end

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  # ---------------------------------------------------------------------------
  # Validation
  # ---------------------------------------------------------------------------

  defp validate_bet_params(params) do
    game_type = params["game_type"]

    cond do
      nil_or_empty?(params["game_player_id"]) ->
        {:error, "Please select a bidder"}

      !Scoring.is_solo?(game_type) && nil_or_empty?(params["sets_bid"]) ->
        {:error, "Please select how many tricks you bid"}

      Scoring.has_partner?(game_type) && nil_or_empty?(params["partner_ace"]) ->
        {:error, "Please select your partner ace"}

      Scoring.has_trumf?(game_type) && nil_or_empty?(params["trumf_suit"]) ->
        {:error, "Please select your trumf suit"}

      true ->
        :ok
    end
  end

  defp validate_resolve_params(params, game_type, is_self_partner) do
    cond do
      nil_or_empty?(params["sets_won"]) ->
        {:error, "Please select how many tricks were won"}

      Scoring.has_partner?(game_type) && !is_self_partner &&
          nil_or_empty?(params["partner_game_player_id"]) ->
        {:error, "Please select the partner, or check self partner"}

      true ->
        {:ok,
         %{
           sets_won: String.to_integer(params["sets_won"]),
           is_self_partner: is_self_partner,
           partner_game_player_id: parse_optional_id(params["partner_game_player_id"])
         }}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp nil_or_empty?(nil), do: true
  defp nil_or_empty?(""), do: true
  defp nil_or_empty?(_), do: false

  defp find_player(game_players, game_player_id) do
    Enum.find(game_players, fn gp -> gp.id == game_player_id end)
  end

  defp parse_optional_id(nil), do: nil
  defp parse_optional_id(""), do: nil
  defp parse_optional_id(id), do: String.to_integer(id)
end
