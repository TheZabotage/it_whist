# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     ItWhist.Repo.insert!(%ItWhist.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias ItWhist.Accounts

accounts = [
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

Enum.each(accounts, fn attrs ->
  case Accounts.register_account(attrs) do
    {:ok, account} -> IO.puts("Created account: #{account.nickname}")
    {:error, changeset} -> IO.puts("Failed: #{inspect(changeset.errors)}")
  end
end)
