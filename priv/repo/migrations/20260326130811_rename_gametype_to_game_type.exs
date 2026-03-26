defmodule ItWhist.Repo.Migrations.RenameGametypeToGameType do
  use Ecto.Migration

  def change do
    rename table(:rounds), :gametype, to: :game_type
  end
end
