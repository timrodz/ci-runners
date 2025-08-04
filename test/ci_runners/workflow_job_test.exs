defmodule CiRunners.Github.WorkflowJobTest do
  use CiRunners.DataCase

  alias CiRunners.Github.{Repository, WorkflowRun, WorkflowJob}

  setup do
    repository =
      Repo.insert!(%Repository{
        owner: "timrodz",
        name: "racing-leaderboards",
        github_id: 123_456
      })

    workflow_run =
      Repo.insert!(%WorkflowRun{
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
      })

    {:ok, workflow_run: workflow_run}
  end

  describe "changeset/2" do
    test "with valid attributes", %{workflow_run: workflow_run} do
      attrs = %{
        github_id: 555_666,
        name: "build",
        status: "completed",
        conclusion: "success",
        runner_name: "GitHub Actions 1",
        runner_group_name: "GitHub Actions",
        started_at: ~U[2023-01-01 12:01:00Z],
        completed_at: ~U[2023-01-01 12:05:00Z],
        workflow_run_id: workflow_run.id
      }

      changeset = WorkflowJob.changeset(%WorkflowJob{}, attrs)
      assert changeset.valid?
    end

    test "requires github_id" do
      attrs = %{
        name: "build",
        status: "completed",
        conclusion: "success",
        runner_name: "GitHub Actions 1",
        runner_group_name: "GitHub Actions",
        started_at: ~U[2023-01-01 12:01:00Z]
      }

      changeset = WorkflowJob.changeset(%WorkflowJob{}, attrs)
      assert "can't be blank" in errors_on(changeset).github_id
    end

    test "requires name" do
      attrs = %{
        github_id: 555_666,
        status: "completed",
        conclusion: "success",
        runner_name: "GitHub Actions 1",
        runner_group_name: "GitHub Actions",
        started_at: ~U[2023-01-01 12:01:00Z]
      }

      changeset = WorkflowJob.changeset(%WorkflowJob{}, attrs)
      assert "can't be blank" in errors_on(changeset).name
    end

    test "requires status" do
      attrs = %{
        github_id: 555_666,
        name: "build",
        conclusion: "success",
        runner_name: "GitHub Actions 1",
        runner_group_name: "GitHub Actions",
        started_at: ~U[2023-01-01 12:01:00Z]
      }

      changeset = WorkflowJob.changeset(%WorkflowJob{}, attrs)
      assert "can't be blank" in errors_on(changeset).status
    end

    test "requires started_at" do
      attrs = %{
        github_id: 555_666,
        name: "build",
        status: "completed",
        conclusion: "success",
        runner_name: "GitHub Actions 1",
        runner_group_name: "GitHub Actions"
      }

      changeset = WorkflowJob.changeset(%WorkflowJob{}, attrs)
      assert "can't be blank" in errors_on(changeset).started_at
    end

    test "conclusion is optional" do
      attrs = %{
        github_id: 555_666,
        name: "build",
        status: "in_progress",
        runner_name: "GitHub Actions 1",
        runner_group_name: "GitHub Actions",
        started_at: ~U[2023-01-01 12:01:00Z]
      }

      changeset = WorkflowJob.changeset(%WorkflowJob{}, attrs)
      assert changeset.valid?
    end

    test "completed_at is optional" do
      attrs = %{
        github_id: 555_666,
        name: "build",
        status: "in_progress",
        runner_name: "GitHub Actions 1",
        runner_group_name: "GitHub Actions",
        started_at: ~U[2023-01-01 12:01:00Z]
      }

      changeset = WorkflowJob.changeset(%WorkflowJob{}, attrs)
      assert changeset.valid?
    end

    test "github_id must be unique", %{workflow_run: workflow_run} do
      attrs = %{
        github_id: 555_666,
        name: "build",
        status: "completed",
        conclusion: "success",
        runner_name: "GitHub Actions 1",
        runner_group_name: "GitHub Actions",
        started_at: ~U[2023-01-01 12:01:00Z],
        completed_at: ~U[2023-01-01 12:05:00Z],
        workflow_run_id: workflow_run.id
      }

      # Insert first workflow job
      %WorkflowJob{}
      |> WorkflowJob.changeset(attrs)
      |> Repo.insert!()

      # Try to insert second workflow job with same github_id
      changeset = WorkflowJob.changeset(%WorkflowJob{}, attrs)
      {:error, changeset} = Repo.insert(changeset)
      assert "has already been taken" in errors_on(changeset).github_id
    end
  end

  describe "associations" do
    test "belongs to workflow_run" do
      workflow_job = %WorkflowJob{}
      association = workflow_job.__struct__.__schema__(:association, :workflow_run)
      assert association.relationship == :parent
      assert association.related == CiRunners.Github.WorkflowRun
    end
  end
end
