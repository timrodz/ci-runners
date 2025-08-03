defmodule CiRunners.Github.WorkflowRunTest do
  use CiRunners.DataCase

  alias CiRunners.Github.{Repository, WorkflowRun}

  setup do
    repository =
      Repo.insert!(%Repository{
        owner: "timrodz",
        name: "racing-leaderboards",
        github_id: 123_456
      })

    {:ok, repository: repository}
  end

  describe "changeset/2" do
    test "with valid attributes", %{repository: repository} do
      attrs = %{
        github_id: 987_654,
        name: "CI Workflow",
        status: "completed",
        conclusion: "success",
        workflow_id: 111,
        head_branch: "main",
        head_sha: "abc123",
        run_number: 42,
        started_at: ~U[2023-01-01 12:00:00Z],
        completed_at: ~U[2023-01-01 12:10:00Z],
        repository_id: repository.id
      }

      changeset = WorkflowRun.changeset(%WorkflowRun{}, attrs)
      assert changeset.valid?
    end

    test "requires github_id" do
      attrs = %{
        name: "CI Workflow",
        status: "completed",
        conclusion: "success",
        workflow_id: 111,
        head_branch: "main",
        head_sha: "abc123",
        run_number: 42,
        started_at: ~U[2023-01-01 12:00:00Z]
      }

      changeset = WorkflowRun.changeset(%WorkflowRun{}, attrs)
      assert "can't be blank" in errors_on(changeset).github_id
    end

    test "requires name" do
      attrs = %{
        github_id: 987_654,
        status: "completed",
        conclusion: "success",
        workflow_id: 111,
        head_branch: "main",
        head_sha: "abc123",
        run_number: 42,
        started_at: ~U[2023-01-01 12:00:00Z]
      }

      changeset = WorkflowRun.changeset(%WorkflowRun{}, attrs)
      assert "can't be blank" in errors_on(changeset).name
    end

    test "requires status" do
      attrs = %{
        github_id: 987_654,
        name: "CI Workflow",
        conclusion: "success",
        workflow_id: 111,
        head_branch: "main",
        head_sha: "abc123",
        run_number: 42,
        started_at: ~U[2023-01-01 12:00:00Z]
      }

      changeset = WorkflowRun.changeset(%WorkflowRun{}, attrs)
      assert "can't be blank" in errors_on(changeset).status
    end

    test "requires workflow_id" do
      attrs = %{
        github_id: 987_654,
        name: "CI Workflow",
        status: "completed",
        conclusion: "success",
        head_branch: "main",
        head_sha: "abc123",
        run_number: 42,
        started_at: ~U[2023-01-01 12:00:00Z]
      }

      changeset = WorkflowRun.changeset(%WorkflowRun{}, attrs)
      assert "can't be blank" in errors_on(changeset).workflow_id
    end

    test "requires head_branch" do
      attrs = %{
        github_id: 987_654,
        name: "CI Workflow",
        status: "completed",
        conclusion: "success",
        workflow_id: 111,
        head_sha: "abc123",
        run_number: 42,
        started_at: ~U[2023-01-01 12:00:00Z]
      }

      changeset = WorkflowRun.changeset(%WorkflowRun{}, attrs)
      assert "can't be blank" in errors_on(changeset).head_branch
    end

    test "requires head_sha" do
      attrs = %{
        github_id: 987_654,
        name: "CI Workflow",
        status: "completed",
        conclusion: "success",
        workflow_id: 111,
        head_branch: "main",
        run_number: 42,
        started_at: ~U[2023-01-01 12:00:00Z]
      }

      changeset = WorkflowRun.changeset(%WorkflowRun{}, attrs)
      assert "can't be blank" in errors_on(changeset).head_sha
    end

    test "requires run_number" do
      attrs = %{
        github_id: 987_654,
        name: "CI Workflow",
        status: "completed",
        conclusion: "success",
        workflow_id: 111,
        head_branch: "main",
        head_sha: "abc123",
        started_at: ~U[2023-01-01 12:00:00Z]
      }

      changeset = WorkflowRun.changeset(%WorkflowRun{}, attrs)
      assert "can't be blank" in errors_on(changeset).run_number
    end

    test "requires started_at" do
      attrs = %{
        github_id: 987_654,
        name: "CI Workflow",
        status: "completed",
        conclusion: "success",
        workflow_id: 111,
        head_branch: "main",
        head_sha: "abc123",
        run_number: 42
      }

      changeset = WorkflowRun.changeset(%WorkflowRun{}, attrs)
      assert "can't be blank" in errors_on(changeset).started_at
    end

    test "conclusion is optional" do
      attrs = %{
        github_id: 987_654,
        name: "CI Workflow",
        status: "in_progress",
        workflow_id: 111,
        head_branch: "main",
        head_sha: "abc123",
        run_number: 42,
        started_at: ~U[2023-01-01 12:00:00Z]
      }

      changeset = WorkflowRun.changeset(%WorkflowRun{}, attrs)
      assert changeset.valid?
    end

    test "completed_at is optional" do
      attrs = %{
        github_id: 987_654,
        name: "CI Workflow",
        status: "in_progress",
        workflow_id: 111,
        head_branch: "main",
        head_sha: "abc123",
        run_number: 42,
        started_at: ~U[2023-01-01 12:00:00Z]
      }

      changeset = WorkflowRun.changeset(%WorkflowRun{}, attrs)
      assert changeset.valid?
    end

    test "github_id must be unique", %{repository: repository} do
      attrs = %{
        github_id: 987_654,
        name: "CI Workflow",
        status: "completed",
        conclusion: "success",
        workflow_id: 111,
        head_branch: "main",
        head_sha: "abc123",
        run_number: 42,
        started_at: ~U[2023-01-01 12:00:00Z],
        repository_id: repository.id
      }

      # Insert first workflow run
      %WorkflowRun{}
      |> WorkflowRun.changeset(attrs)
      |> Repo.insert!()

      # Try to insert second workflow run with same github_id
      changeset = WorkflowRun.changeset(%WorkflowRun{}, attrs)
      {:error, changeset} = Repo.insert(changeset)
      assert "has already been taken" in errors_on(changeset).github_id
    end
  end

  describe "associations" do
    test "belongs to repository" do
      workflow_run = %WorkflowRun{}
      association = workflow_run.__struct__.__schema__(:association, :repository)
      assert association.relationship == :parent
      assert association.related == CiRunners.Github.Repository
    end

    test "has many workflow_jobs" do
      workflow_run = %WorkflowRun{}
      association = workflow_run.__struct__.__schema__(:association, :workflow_jobs)
      assert association.relationship == :child
      assert association.related == CiRunners.Github.WorkflowJob
    end
  end
end
