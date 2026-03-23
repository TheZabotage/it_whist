defmodule ItWhist.Repo do
  use Ecto.Repo,
    otp_app: :it_whist,
    adapter: Ecto.Adapters.Postgres
end
