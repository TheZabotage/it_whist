defmodule ItWhist.Repo.Migrations.AddAdminToAccounts do
  use Ecto.Migration

  def change do
    alter table(:accounts) do
      add :is_admin, :boolean, default: false, null: false
    end
  end
end
