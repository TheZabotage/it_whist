defmodule ItWhist.Repo.Migrations.CreatePlayers do
  use Ecto.Migration

  def change do
    create table(:game_players) do
      add :final_score, :integer, default: 0
      add :game_id, references(:games, on_delete: :delete_all), null: false
      add :player_id, references(:accounts, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:game_players, [:game_id, :player_id])
    create index(:game_players, [:player_id])
  end
end
