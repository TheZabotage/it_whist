defmodule ItWhist.Games.RoundScore do
  use Ecto.Schema
  import Ecto.Changeset

  alias ItWhist.Games.{Round, GamePlayer}

  @primary_key false

  schema "round_scores" do
    field :score, :integer

    belongs_to :round, Round, primary_key: true
    belongs_to :game_player, GamePlayer, primary_key: true

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(round_score, attrs) do
    round_score
    |> cast(attrs, [:round_id, :game_player_id, :score])
    |> validate_required([:round_id, :game_player_id, :score])
    |> foreign_key_constraint(:round_id)
    |> foreign_key_constraint(:game_player_id)
  end
end
