defmodule ItWhist.Games.Scoring do
  @moduledoc """
  Pure score calculation for esmakker whist game types.

  No database access — only game state in, points out.
  This is the single source of truth for all game-type and suit constants.
  """

  @partner_game_types ["Alm", "Vip", "Halve", "Sans", "Gode"]
  @trumf_game_types ["Alm", "Vip", "Halve", "Gode"]
  @solo_game_types ["Sol", "Ren Sol", "Bordlægger", "Super Bordlægger"]
  @high_game_types ["Vip", "Halve", "Sans", "Gode"]

  @valid_suits ["Spades", "Hearts", "Clubs", "Diamonds"]

  @doc "All valid game type strings."
  def all_game_types, do: @partner_game_types ++ @solo_game_types

  @doc "All valid suit strings."
  def all_suits, do: @valid_suits

  @doc "True if the game type involves a partner (declared via partner ace)."
  def has_partner?(game_type), do: game_type in @partner_game_types

  @doc "True if the game type has a trumf suit selection."
  def has_trumf?(game_type), do: game_type in @trumf_game_types

  @doc "True if the game type is a solo game (no partner)."
  def is_solo?(game_type), do: game_type in @solo_game_types

  @doc """
  Calculate winner/loser points for a completed round.

  Returns `%{winner: integer, loser: integer}`.

  The caller is responsible for distributing these points to the correct
  players — see `ItWhist.Games.resolve_round/3`.
  """
  def calculate(game_type, sets_bid, sets_won, is_self_partner \\ false)

  def calculate("Sol", _sets_bid, sets_won, _is_self_partner) do
    if sets_won >= 1,
      do: %{winner: 150, loser: -50},
      else: %{winner: -300, loser: 100}
  end

  def calculate("Ren Sol", _sets_bid, sets_won, _is_self_partner) do
    if sets_won == 0,
      do: %{winner: 300, loser: -100},
      else: %{winner: -600, loser: 200}
  end

  def calculate("Bordlægger", _sets_bid, sets_won, _is_self_partner) do
    if sets_won >= 1,
      do: %{winner: 450, loser: -150},
      else: %{winner: -900, loser: 300}
  end

  def calculate("Super Bordlægger", _sets_bid, sets_won, _is_self_partner) do
    if sets_won == 0,
      do: %{winner: 600, loser: -200},
      else: %{winner: -1200, loser: 400}
  end

  def calculate(game_type, sets_bid, sets_won, is_self_partner) do
    y = base_points(sets_bid)
    effective_y = if game_type in @high_game_types, do: y * 2, else: y
    diff = sets_won - sets_bid

    {winner_points, loser_points} =
      cond do
        diff == 0 and is_self_partner ->
          {effective_y * 3, -effective_y}

        diff == 0 ->
          {effective_y, -effective_y}

        diff > 0 and is_self_partner ->
          {effective_y * (diff + 1) * 3, -effective_y * (diff + 1)}

        diff > 0 ->
          {effective_y * (diff + 1), -effective_y * (diff + 1)}

        diff < 0 and is_self_partner ->
          {-(effective_y * 2 * 3 * abs(diff)), effective_y * 2 * abs(diff)}

        diff < 0 ->
          {-(effective_y * 2 * abs(diff)), effective_y * 2 * abs(diff)}
      end

    %{winner: winner_points, loser: loser_points}
  end

  # Maps sets bid to base point value per the scoring table.
  defp base_points(7), do: 5
  defp base_points(8), do: 10
  defp base_points(9), do: 20
  defp base_points(10), do: 40
  defp base_points(11), do: 80
  defp base_points(12), do: 160
  defp base_points(13), do: 320
end
