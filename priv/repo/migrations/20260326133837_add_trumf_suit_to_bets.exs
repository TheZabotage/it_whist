defmodule ItWhist.Repo.Migrations.AddTrumfSuitToBets do
  use Ecto.Migration

  def change do
    alter table(:bets) do
      add :trumf_suit, :string
    end
  end
end
