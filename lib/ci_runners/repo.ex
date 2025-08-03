defmodule CiRunners.Repo do
  use Ecto.Repo,
    otp_app: :ci_runners,
    adapter: Ecto.Adapters.Postgres
end
