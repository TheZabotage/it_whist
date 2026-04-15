defmodule ItWhistWeb.GameLive.Form do
  use ItWhistWeb, :live_view

  alias ItWhist.{Accounts, Games}
  alias ItWhist.Games.Game

  @impl true
  def mount(_params, _session, socket) do
    creator_id = socket.assigns.current_scope.account.id

    {:ok,
     socket
     |> assign(:creator_id, creator_id)
     |> assign(:page_title, "New Game")
     |> assign(:game, %Game{created_by: creator_id})
     |> assign(:player_1_search, "")
     |> assign(:player_1_results, [])
     |> assign(:player_1_selected, nil)
     |> assign(:player_2_search, "")
     |> assign(:player_2_results, [])
     |> assign(:player_2_selected, nil)
     |> assign(:player_3_search, "")
     |> assign(:player_3_results, [])
     |> assign(:player_3_selected, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        New Game
        <:subtitle>Search for 3 players to join the game.</:subtitle>
      </.header>

      <form phx-submit="create_game" phx-change="search_player" class="space-y-6">
        <.player_slot
          slot={1}
          search={@player_1_search}
          results={@player_1_results}
          selected={@player_1_selected}
        />
        <.player_slot
          slot={2}
          search={@player_2_search}
          results={@player_2_results}
          selected={@player_2_selected}
        />
        <.player_slot
          slot={3}
          search={@player_3_search}
          results={@player_3_results}
          selected={@player_3_selected}
        />

        <footer>
          <.button variant="primary" phx-disable-with="Starting...">
            Start Game
          </.button>
          <.button navigate={~p"/games"}>Cancel</.button>
        </footer>
      </form>
    </Layouts.app>
    """
  end

  defp player_slot(assigns) do
    ~H"""
    <div class="space-y-1">
      <label class="font-medium">Player {@slot}</label>

      <%= if @selected do %>
        <div class="flex items-center gap-2 p-2 input input-bordered w-full">
          <span>{@selected.nickname} ({@selected.name})</span>
          <button
            type="button"
            phx-click={"clear_player_#{@slot}"}
            class="text-error ml-auto"
          >
            ✕
          </button>
        </div>
      <% else %>
        <div class="relative">
          <input
            type="text"
            placeholder="Search by name or nickname..."
            value={@search}
            name={"player_#{@slot}_search"}
            autocomplete="off"
            class="input input-bordered w-full"
          />
          <%= if length(@results) > 0 do %>
            <ul class="absolute z-10 w-full bg-base-100 border border-base-300 rounded-box shadow-md top-full mt-1">
              <%= for account <- @results do %>
                <li
                  phx-click={"select_player_#{@slot}"}
                  phx-value-id={account.id}
                  class="p-2 hover:bg-base-200 cursor-pointer"
                >
                  {account.nickname} ({account.name})
                </li>
              <% end %>
            </ul>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("search_player", %{"_target" => [target]} = params, socket) do
    slot = target |> String.replace("player_", "") |> String.replace("_search", "")
    query = Map.get(params, target, "")

    results =
      if String.length(query) > 0,
        do: Accounts.search_accounts(query, excluded_ids(socket)),
        else: []

    {:noreply,
     socket
     |> assign(:"player_#{slot}_results", results)
     |> assign(:"player_#{slot}_search", query)}
  end

  def handle_event("select_player_" <> slot, %{"id" => id}, socket) do
    with {slot_int, ""} <- Integer.parse(slot),
         {id_int, ""} <- Integer.parse(id),
         account when not is_nil(account) <- Accounts.get_account(id_int) do
      {:noreply,
       socket
       |> assign(:"player_#{slot_int}_selected", account)
       |> assign(:"player_#{slot_int}_results", [])
       |> assign(:"player_#{slot_int}_search", "")}
    else
      _ -> {:noreply, put_flash(socket, :error, "Something went wrong. Please try again.")}
    end
  end

  def handle_event("clear_player_" <> slot, _params, socket) do
    slot = String.to_integer(slot)

    {:noreply,
     socket
     |> assign(:"player_#{slot}_selected", nil)
     |> assign(:"player_#{slot}_search", "")}
  end

  def handle_event("create_game", _params, socket) do
    selected = [
      socket.assigns.player_1_selected,
      socket.assigns.player_2_selected,
      socket.assigns.player_3_selected
    ]

    if Enum.any?(selected, &is_nil/1) do
      {:noreply, put_flash(socket, :error, "Please select all 3 players.")}
    else
      player_ids = Enum.map(selected, & &1.id)

      case Games.create_game_with_players(socket.assigns.current_scope, player_ids) do
        {:ok, game} ->
          {:noreply,
           socket
           |> put_flash(:info, "Game started!")
           |> push_navigate(to: ~p"/games/#{game}")}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Could not create game.")}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp excluded_ids(socket) do
    [
      socket.assigns.creator_id,
      get_selected_id(socket.assigns.player_1_selected),
      get_selected_id(socket.assigns.player_2_selected),
      get_selected_id(socket.assigns.player_3_selected)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp get_selected_id(nil), do: nil
  defp get_selected_id(account), do: account.id
end
