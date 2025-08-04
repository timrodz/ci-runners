defmodule CiRunners.Github.WorkflowJob do
  use Ecto.Schema
  import Ecto.Changeset

  schema "workflow_jobs" do
    field :github_id, :integer
    field :name, :string
    field :status, :string
    field :conclusion, :string
    field :runner_name, :string
    field :runner_group_name, :string
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime

    belongs_to :workflow_run, CiRunners.Github.WorkflowRun

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(workflow_job, attrs) do
    workflow_job
    |> cast(attrs, [
      :github_id,
      :name,
      :status,
      :conclusion,
      :runner_name,
      :runner_group_name,
      :started_at,
      :completed_at,
      :workflow_run_id
    ])
    |> validate_required([
      :github_id,
      :name,
      :status,
      :started_at
    ])
    |> unique_constraint(:github_id)
    |> foreign_key_constraint(:workflow_run_id)
  end
end
