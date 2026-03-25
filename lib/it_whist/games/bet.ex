defmodule ItWhist.Games.Bet do
  use Ecto.Schema
  import Ecto.Changeset

  alias ItWhist.Games.{Round, GamePlayer}

  @valid_aces ["Spades", "Hearts", "Clubs", "Diamonds"]

  schema "bets" do
    field :sets_bid, :integer
    field :sets_won, :integer
    field :partner_ace, :string

    belongs_to :round, Round
    belongs_to :game_player, GamePlayer
    belongs_to :partner, GamePlayer, foreign_key: :game_player_partner_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(bet, attrs) do
    bet
    |> cast(attrs, [
      :round_id,
      :game_player_id,
      :game_player_partner_id,
      :sets_bid,
      :partner_ace
    ])
    |> validate_required([:round_id, :game_player_id, :sets_bid])
    |> validate_inclusion(:partner_ace, @valid_aces)
    |> foreign_key_constraint(:round_id)
    |> foreign_key_constraint(:game_player_id)
    |> foreign_key_constraint(:game_player_partner_id)
  end
end
