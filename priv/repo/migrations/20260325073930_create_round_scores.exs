defmodule ItWhist.Repo.Migrations.CreateRoundScores do
  use Ecto.Migration

  def change do
    create table(:round_scores, primary_key: false) do
      add :score, :integer, null: false

      add :game_player_id, references(:game_players, on_delete: :delete_all),
        null: false,
        primary_key: true

      add :round_id, references(:rounds, on_delete: :delete_all), null: false, primary_key: true

      timestamps(type: :utc_datetime)
    end

    create index(:round_scores, [:game_player_id])
  end
end
