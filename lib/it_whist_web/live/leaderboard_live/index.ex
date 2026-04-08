defmodule ItWhistWeb.LeaderboardLive.Index do
  use ItWhistWeb, :live_view

  alias ItWhist.Games

  @impl true
  @spec mount(any(), any(), Phoenix.LiveView.Socket.t()) :: {:ok, map()}
  def mount(_params, _session, socket) do
    if connected?(socket), do: Games.subscribe_games(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:page_title, "Leaderboard")
     |> assign(:entries, leaderboard_with_rank())}
  end

  @impl true
  def handle_info({event, _resource}, socket)
      when event in [:game_completed, :game_deleted] do
    {:noreply, assign(socket, :entries, leaderboard_with_rank())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>Leaderboard</.header>

      <.table id="leaderboard" rows={@entries}>
        <:col :let={entry} label="#">{entry.rank}</:col>
        <:col :let={entry} label="Player">{entry.account.nickname} ({entry.account.name})</:col>
        <:col :let={entry} label="Total Score">
          {entry.total_score || "—"}
        </:col>
        <:col :let={entry} label="Games Played">{entry.games_played}</:col>
      </.table>
    </Layouts.app>
    """
  end

  defp leaderboard_with_rank do
    Games.leaderboard()
    |> Enum.with_index(1)
    |> Enum.map(fn {entry, index} ->
      rank = if entry.games_played == 0, do: "—", else: index
      Map.put(entry, :rank, rank)
    end)
  end
end
