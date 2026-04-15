defmodule ItWhist.Repo.Migrations.AddDeletedAtToAccounts do
  use Ecto.Migration

  def change do
    alter table(:accounts) do
      add :deleted_at, :utc_datetime
    end
  end
end
