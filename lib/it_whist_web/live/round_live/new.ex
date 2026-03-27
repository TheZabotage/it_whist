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
     |> assign(:page_title, "Log Round")}
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
        y = base_points(sets_bid)
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
end
