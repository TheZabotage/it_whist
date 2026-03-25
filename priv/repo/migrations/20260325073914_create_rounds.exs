defmodule ItWhist.Repo.Migrations.CreateRounds do
  use Ecto.Migration

  def change do
    create table(:rounds) do
      add :gametype, :string, null: false
      add :round_number, :integer, null: false
      add :game_id, references(:games, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:rounds, [:game_id])
    create unique_index(:rounds, [:game_id, :round_number])
  end
end
