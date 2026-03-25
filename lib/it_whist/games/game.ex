defmodule ItWhist.Games.Game do
  use Ecto.Schema
  import Ecto.Changeset

  alias ItWhist.Accounts.Account
  alias ItWhist.Games.{GamePlayer, Round}

  @valid_statuses ["in_progress", "completed"]

  schema "games" do
    field :status, :string, default: "in_progress"
    field :played_at, :utc_datetime

    belongs_to :creator, Account, foreign_key: :created_by
    has_many :game_players, GamePlayer
    has_many :rounds, Round

    timestamps(type: :utc_datetime)
  end

  def changeset(game, attrs) do
    game
    |> cast(attrs, [:status, :played_at, :created_by])
    |> validate_required([:created_by])
    |> validate_inclusion(:status, @valid_statuses)
    |> foreign_key_constraint(:created_by)
  end
end
