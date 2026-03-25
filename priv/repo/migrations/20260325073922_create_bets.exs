defmodule ItWhist.Repo.Migrations.CreateBets do
  use Ecto.Migration

  def change do
    create table(:bets) do
      add :sets_bid, :integer, null: false
      add :sets_won, :integer
      add :partner_ace, :string
      add :round_id, references(:rounds, on_delete: :delete_all), null: false
      add :game_player_id, references(:game_players, on_delete: :delete_all), null: false
      add :game_player_partner_id, references(:game_players, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:bets, [:round_id])
    create index(:bets, [:game_player_id])
  end
end
