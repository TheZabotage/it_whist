defmodule ItWhist.Games.Bet do
  use Ecto.Schema
  import Ecto.Changeset

  alias ItWhist.Games.{Round, GamePlayer, Scoring}

  schema "bets" do
    field :sets_bid, :integer
    field :sets_won, :integer
    field :partner_ace, :string
    field :trumf_suit, :string
    field :game_type, :string, virtual: true
    field :is_self_partner, :boolean, default: false

    belongs_to :partner_game_player, GamePlayer, foreign_key: :partner_game_player_id
    belongs_to :round, Round
    belongs_to :game_player, GamePlayer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(bet, attrs) do
    bet
    |> cast(attrs, [
      :round_id,
      :game_player_id,
      :sets_bid,
      :sets_won,
      :partner_ace,
      :trumf_suit,
      :game_type,
      :partner_game_player_id,
      :is_self_partner
    ])
    |> validate_required([:round_id, :game_player_id, :sets_bid])
    |> validate_inclusion(:partner_ace, Scoring.all_suits())
    |> validate_inclusion(:trumf_suit, Scoring.all_suits())
    |> validate_partner_rules()
    |> foreign_key_constraint(:round_id)
    |> foreign_key_constraint(:game_player_id)
    |> foreign_key_constraint(:partner_game_player_id)
  end

  defp validate_partner_rules(changeset) do
    case get_field(changeset, :game_type) do
      t when t in ["Sol", "Ren Sol", "Bordlægger", "Super Bordlægger"] ->
        changeset
        |> delete_change(:partner_ace)
        |> delete_change(:trumf_suit)

      "Sans" ->
        changeset
        |> validate_required([:partner_ace])
        |> delete_change(:trumf_suit)

      "Gode" ->
        changeset
        |> validate_required([:partner_ace])
        |> put_change(:trumf_suit, "Clubs")

      t when t in ["Alm", "Vip", "Halve"] ->
        changeset
        |> validate_required([:partner_ace, :trumf_suit])
        |> validate_ace_not_trumf()

      _ ->
        changeset
    end
  end

  defp validate_ace_not_trumf(changeset) do
    partner_ace = get_field(changeset, :partner_ace)
    trumf_suit = get_field(changeset, :trumf_suit)

    if partner_ace && trumf_suit && partner_ace == trumf_suit do
      add_error(changeset, :partner_ace, "cannot be the same suit as trumf")
    else
      changeset
    end
  end
end
