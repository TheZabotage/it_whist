defmodule ItWhist.Games.Round do
  use Ecto.Schema
  import Ecto.Changeset

  alias ItWhist.Games.{Game, Bet, RoundScore, Scoring}

  schema "rounds" do
    field :game_type, :string, default: "Alm"
    field :round_number, :integer

    belongs_to :game, Game
    has_one :bet, Bet
    has_many :round_scores, RoundScore

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(round, attrs) do
    round
    |> cast(attrs, [:game_type, :round_number, :game_id])
    |> validate_required([:game_type, :round_number, :game_id])
    |> validate_inclusion(:game_type, Scoring.all_game_types())
    |> foreign_key_constraint(:game_id)
    |> unique_constraint([:game_id, :round_number],
      name: :rounds_game_id_round_number_index
    )
  end
end
