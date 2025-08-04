defmodule CiRunners.Github.WorkflowRun do
  use Ecto.Schema
  import Ecto.Changeset

  schema "workflow_runs" do
    field :github_id, :integer
    field :name, :string
    field :status, :string
    field :conclusion, :string
    field :workflow_id, :integer
    field :head_branch, :string
    field :head_sha, :string
    field :run_number, :integer
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime

    belongs_to :repository, CiRunners.Github.Repository
    has_many :workflow_jobs, CiRunners.Github.WorkflowJob

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(workflow_run, attrs) do
    workflow_run
    |> cast(attrs, [
      :github_id,
      :name,
      :status,
      :conclusion,
      :workflow_id,
      :head_branch,
      :head_sha,
      :run_number,
      :started_at,
      :completed_at,
      :repository_id
    ])
    |> validate_required([
      :github_id,
      :name,
      :status,
      :workflow_id,
      :head_branch,
      :head_sha,
      :run_number,
      :started_at
    ])
    |> unique_constraint(:github_id)
    |> foreign_key_constraint(:repository_id)
  end
end
