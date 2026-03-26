defmodule ItWhist.Repo.Migrations.AddPartnerFieldsToBets do
  use Ecto.Migration

  def change do
    alter table(:bets) do
      add :partner_game_player_id, references(:game_players, on_delete: :nothing)
      add :is_self_partner, :boolean, default: false, null: false
    end
  end
end
