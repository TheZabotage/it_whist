defmodule ItWhist.Repo.Migrations.RemoveGamePlayerPartnerIdFromBets do
  use Ecto.Migration

  def change do
    alter table(:bets) do
      remove :game_player_partner_id
    end
  end
end
