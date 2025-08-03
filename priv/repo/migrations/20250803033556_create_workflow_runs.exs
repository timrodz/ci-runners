defmodule CiRunners.Repo.Migrations.CreateWorkflowRuns do
  use Ecto.Migration

  def change do
    create table(:workflow_runs) do
      add :github_id, :integer, null: false
      add :name, :string, null: false
      add :status, :string, null: false
      add :conclusion, :string
      add :workflow_id, :integer, null: false
      add :head_branch, :string, null: false
      add :head_sha, :string, null: false
      add :run_number, :integer, null: false
      add :started_at, :utc_datetime, null: false
      add :completed_at, :utc_datetime
      add :repository_id, references(:repositories, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:workflow_runs, [:github_id])
    create index(:workflow_runs, [:repository_id])
    create index(:workflow_runs, [:status])
    create index(:workflow_runs, [:started_at])
  end
end
