defmodule CiRunners.Repo.Migrations.CreateRepositories do
  use Ecto.Migration

  def change do
    create table(:repositories) do
      add :owner, :string, null: false
      add :name, :string, null: false
      add :github_id, :bigint, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:repositories, [:github_id])
    create index(:repositories, [:owner, :name])
  end
end
