defmodule ItWhist.Repo.Migrations.CreateGames do
  use Ecto.Migration

  def change do
    create table(:games) do
      add :status, :string, null: false, default: "in_progess"
      add :played_at, :utc_datetime
      add :created_by, references(:accounts, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:games, [:created_by])
  end
end
