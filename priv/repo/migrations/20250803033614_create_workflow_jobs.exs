defmodule CiRunners.Repo.Migrations.CreateWorkflowJobs do
  use Ecto.Migration

  def change do
    create table(:workflow_jobs) do
      add :github_id, :bigint, null: false
      add :name, :string, null: false
      add :status, :string, null: false
      add :conclusion, :string
      add :runner_name, :string
      add :runner_group_name, :string
      add :started_at, :utc_datetime, null: false
      add :completed_at, :utc_datetime
      add :workflow_run_id, references(:workflow_runs, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:workflow_jobs, [:github_id])
    create index(:workflow_jobs, [:workflow_run_id])
    create index(:workflow_jobs, [:status])
    create index(:workflow_jobs, [:started_at])
  end
end
