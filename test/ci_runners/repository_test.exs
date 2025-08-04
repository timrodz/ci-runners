defmodule CiRunners.Github.RepositoryTest do
  use CiRunners.DataCase

  alias CiRunners.Github.Repository

  describe "changeset/2" do
    test "with valid attributes" do
      attrs = %{
        owner: "timrodz",
        name: "racing-leaderboards",
        github_id: 123_456
      }

      changeset = Repository.changeset(%Repository{}, attrs)
      assert changeset.valid?
    end

    test "requires owner" do
      attrs = %{name: "racing-leaderboards", github_id: 123_456}
      changeset = Repository.changeset(%Repository{}, attrs)
      assert "can't be blank" in errors_on(changeset).owner
    end

    test "requires name" do
      attrs = %{owner: "timrodz", github_id: 123_456}
      changeset = Repository.changeset(%Repository{}, attrs)
      assert "can't be blank" in errors_on(changeset).name
    end

    test "requires github_id" do
      attrs = %{owner: "timrodz", name: "racing-leaderboards"}
      changeset = Repository.changeset(%Repository{}, attrs)
      assert "can't be blank" in errors_on(changeset).github_id
    end

    test "github_id must be unique" do
      attrs = %{
        owner: "timrodz",
        name: "racing-leaderboards",
        github_id: 123_456
      }

      # Insert first repository
      %Repository{}
      |> Repository.changeset(attrs)
      |> Repo.insert!()

      # Try to insert second repository with same github_id
      changeset = Repository.changeset(%Repository{}, attrs)
      {:error, changeset} = Repo.insert(changeset)
      assert "has already been taken" in errors_on(changeset).github_id
    end
  end

  describe "associations" do
    test "has many workflow_runs" do
      repository = %Repository{}
      association = repository.__struct__.__schema__(:association, :workflow_runs)
      assert association.relationship == :child
      assert association.related == CiRunners.Github.WorkflowRun
    end
  end
end
