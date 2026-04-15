alias ItWhist.Accounts
alias ItWhist.Repo
import Ecto.Changeset

regular_accounts = [
  %{
    email: "anders@itwhist.dk",
    name: "Anders Hansen",
    nickname: "Andes",
    password: "strongpassword123"
  },
  %{
    email: "sofia@itwhist.dk",
    name: "Sofia Nielsen",
    nickname: "Sofi",
    password: "strongpassword123"
  },
  %{
    email: "mikkel@itwhist.dk",
    name: "Mikkel Jensen",
    nickname: "Mikz",
    password: "strongpassword123"
  },
  %{
    email: "laura@itwhist.dk",
    name: "Laura Christensen",
    nickname: "Lau",
    password: "strongpassword123"
  }
]

Enum.each(regular_accounts, fn attrs ->
  case Accounts.register_account(attrs) do
    {:ok, account} -> IO.puts("Created account: #{account.nickname}")
    {:error, changeset} -> IO.puts("Failed: #{inspect(changeset.errors)}")
  end
end)

# Admin account — set is_admin directly after creation
case Accounts.register_account(%{
       email: "admin@itwhist.dk",
       name: "Admin Adminson",
       nickname: "Admin",
       password: "Strongpassword123"
     }) do
  {:ok, account} ->
    account
    |> change(is_admin: true)
    |> Repo.update!()

    IO.puts("Created admin account: #{account.nickname}")

  {:error, changeset} ->
    IO.puts("Failed to create admin: #{inspect(changeset.errors)}")
end
