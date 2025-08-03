defmodule CiRunners.Github.Repository do
  use Ecto.Schema
  import Ecto.Changeset

  schema "repositories" do
    field :owner, :string
    field :name, :string
    field :github_id, :integer

    has_many :workflow_runs, CiRunners.Github.WorkflowRun

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(repository, attrs) do
    repository
    |> cast(attrs, [:owner, :name, :github_id])
    |> validate_required([:owner, :name, :github_id])
    |> unique_constraint(:github_id)
  end
end
