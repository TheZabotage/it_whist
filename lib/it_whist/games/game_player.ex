defmodule ItWhist.Games.GamePlayer do
  use Ecto.Schema
  import Ecto.Changeset

  alias ItWhist.Accounts.Account
  alias ItWhist.Games.{Game, Bet, RoundScore}

  schema "game_players" do
    field :final_score, :integer, default: 0

    belongs_to :game, Game
    belongs_to :player, Account
    has_many :bets, Bet
    has_many :round_scores, RoundScore

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(game_player, attrs) do
    game_player
    |> cast(attrs, [:game_id, :player_id, :final_score])
    |> validate_required([:game_id, :player_id])
    |> foreign_key_constraint(:game_id)
    |> foreign_key_constraint(:player_id)
    |> unique_constraint([:game_id, :player_id])
  end
end
