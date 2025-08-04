defmodule CiRunners.Github.WebhookHandlerTest do
  use CiRunners.DataCase, async: true

  alias CiRunners.Github.WebhookHandler
  alias CiRunners.Github.{Repository, WorkflowRun, WorkflowJob}
  alias CiRunners.Repo

  # Sample GitHub webhook payloads for testing
  @workflow_run_payload %{
    "action" => "completed",
    "workflow_run" => %{
      "id" => 1_234_567_890,
      "name" => "CI",
      "status" => "completed",
      "conclusion" => "success",
      "workflow_id" => 161_335,
      "head_branch" => "main",
      "head_sha" => "009b8a3a9ccbb128af87f9b1c0f4c62e8a304f6d",
      "run_number" => 42,
      "run_started_at" => "2021-01-01T00:00:00Z",
      "updated_at" => "2021-01-01T00:01:00Z"
    },
    "repository" => %{
      "id" => 35_129_377,
      "name" => "docs",
      "full_name" => "github/docs",
      "owner" => %{
        "login" => "github",
        "id" => 9_919_815
      }
    }
  }

  @workflow_job_payload %{
    "action" => "completed",
    "workflow_job" => %{
      "id" => 4_407_365_498,
      "run_id" => 1_234_567_890,
      "workflow_name" => "CI",
      "head_branch" => "main",
      "head_sha" => "009b8a3a9ccbb128af87f9b1c0f4c62e8a304f6d",
      "name" => "test",
      "status" => "completed",
      "conclusion" => "success",
      "started_at" => "2021-01-01T00:00:00Z",
      "completed_at" => "2021-01-01T00:01:00Z",
      "runner_name" => "GitHub Actions 1",
      "runner_group_name" => "GitHub Actions"
    },
    "repository" => %{
      "id" => 35_129_377,
      "name" => "docs",
      "full_name" => "github/docs",
      "owner" => %{
        "login" => "github",
        "id" => 9_919_815
      }
    }
  }

  describe "handle_workflow_run/1" do
    test "successfully processes workflow_run payload with new repository" do
      assert :ok = WebhookHandler.handle_workflow_run(@workflow_run_payload)

      # Verify repository was created
      repository = Repo.get_by(Repository, github_id: 35_129_377)
      assert repository.owner == "github"
      assert repository.name == "docs"

      # Verify workflow run was created
      workflow_run = Repo.get_by(WorkflowRun, github_id: 1_234_567_890)
      assert workflow_run.name == "CI"
      assert workflow_run.status == "completed"
      assert workflow_run.conclusion == "success"
      assert workflow_run.workflow_id == 161_335
      assert workflow_run.head_branch == "main"
      assert workflow_run.head_sha == "009b8a3a9ccbb128af87f9b1c0f4c62e8a304f6d"
      assert workflow_run.run_number == 42
      assert workflow_run.repository_id == repository.id
      assert workflow_run.started_at == ~U[2021-01-01 00:00:00Z]
      assert workflow_run.completed_at == ~U[2021-01-01 00:01:00Z]
    end

    test "successfully processes workflow_run payload with existing repository" do
      # Create repository first
      repository =
        %Repository{}
        |> Repository.changeset(%{
          github_id: 35_129_377,
          owner: "github",
          name: "docs"
        })
        |> Repo.insert!()

      assert :ok = WebhookHandler.handle_workflow_run(@workflow_run_payload)

      # Verify repository was updated, not duplicated
      repositories = Repo.all(Repository)
      assert length(repositories) == 1
      updated_repository = hd(repositories)
      assert updated_repository.id == repository.id
      assert updated_repository.owner == "github"
      assert updated_repository.name == "docs"

      # Verify workflow run was created
      workflow_run = Repo.get_by(WorkflowRun, github_id: 1_234_567_890)
      assert workflow_run.repository_id == repository.id
    end

    test "successfully updates existing workflow_run" do
      # Create repository and workflow run first
      repository =
        %Repository{}
        |> Repository.changeset(%{
          github_id: 35_129_377,
          owner: "github",
          name: "docs"
        })
        |> Repo.insert!()

      %WorkflowRun{}
      |> WorkflowRun.changeset(%{
        github_id: 1_234_567_890,
        name: "CI",
        status: "in_progress",
        workflow_id: 161_335,
        head_branch: "main",
        head_sha: "009b8a3a9ccbb128af87f9b1c0f4c62e8a304f6d",
        run_number: 42,
        started_at: ~U[2021-01-01 00:00:00Z],
        repository_id: repository.id
      })
      |> Repo.insert!()

      assert :ok = WebhookHandler.handle_workflow_run(@workflow_run_payload)

      # Verify workflow run was updated, not duplicated
      workflow_runs = Repo.all(WorkflowRun)
      assert length(workflow_runs) == 1
      updated_run = hd(workflow_runs)
      assert updated_run.status == "completed"
      assert updated_run.conclusion == "success"
      assert updated_run.completed_at == ~U[2021-01-01 00:01:00Z]
    end

    test "handles workflow_run without completed_at timestamp" do
      payload = put_in(@workflow_run_payload, ["workflow_run", "updated_at"], nil)

      assert :ok = WebhookHandler.handle_workflow_run(payload)

      workflow_run = Repo.get_by(WorkflowRun, github_id: 1_234_567_890)
      assert workflow_run.completed_at == nil
    end

    test "returns error for invalid payload structure" do
      assert {:error, :invalid_payload} = WebhookHandler.handle_workflow_run("invalid")
      assert {:error, :invalid_payload} = WebhookHandler.handle_workflow_run(nil)
    end

    test "returns error for missing repository data" do
      payload = Map.delete(@workflow_run_payload, "repository")
      assert {:error, :missing_repository_data} = WebhookHandler.handle_workflow_run(payload)
    end

    test "returns error for invalid repository data structure" do
      payload = put_in(@workflow_run_payload, ["repository"], %{"invalid" => "structure"})
      assert {:error, :invalid_repository_data} = WebhookHandler.handle_workflow_run(payload)
    end

    test "returns error for missing workflow_run data" do
      payload = Map.delete(@workflow_run_payload, "workflow_run")
      assert {:error, :missing_workflow_run_data} = WebhookHandler.handle_workflow_run(payload)
    end

    test "returns error for invalid datetime format" do
      payload = put_in(@workflow_run_payload, ["workflow_run", "run_started_at"], "invalid-date")
      assert {:error, {:invalid_datetime, _reason}} = WebhookHandler.handle_workflow_run(payload)
    end

    test "returns error for missing required datetime" do
      payload = put_in(@workflow_run_payload, ["workflow_run", "run_started_at"], nil)
      assert {:error, :missing_datetime} = WebhookHandler.handle_workflow_run(payload)
    end
  end

  describe "handle_workflow_job/1" do
    setup do
      # Create repository and workflow run for job tests
      repository =
        %Repository{}
        |> Repository.changeset(%{
          github_id: 35_129_377,
          owner: "github",
          name: "docs"
        })
        |> Repo.insert!()

      workflow_run =
        %WorkflowRun{}
        |> WorkflowRun.changeset(%{
          github_id: 1_234_567_890,
          name: "CI",
          status: "completed",
          workflow_id: 161_335,
          head_branch: "main",
          head_sha: "009b8a3a9ccbb128af87f9b1c0f4c62e8a304f6d",
          run_number: 42,
          started_at: ~U[2021-01-01 00:00:00Z],
          repository_id: repository.id
        })
        |> Repo.insert!()

      %{repository: repository, workflow_run: workflow_run}
    end

    test "successfully processes workflow_job payload", %{workflow_run: workflow_run} do
      assert :ok = WebhookHandler.handle_workflow_job(@workflow_job_payload)

      # Verify workflow job was created
      workflow_job = Repo.get_by(WorkflowJob, github_id: 4_407_365_498)
      assert workflow_job.name == "test"
      assert workflow_job.status == "completed"
      assert workflow_job.conclusion == "success"
      assert workflow_job.runner_name == "GitHub Actions 1"
      assert workflow_job.runner_group_name == "GitHub Actions"
      assert workflow_job.workflow_run_id == workflow_run.id
      assert workflow_job.started_at == ~U[2021-01-01 00:00:00Z]
      assert workflow_job.completed_at == ~U[2021-01-01 00:01:00Z]
    end

    test "successfully updates existing workflow_job", %{workflow_run: workflow_run} do
      # Create workflow job first
      %WorkflowJob{}
      |> WorkflowJob.changeset(%{
        github_id: 4_407_365_498,
        name: "test",
        status: "in_progress",
        runner_name: "GitHub Actions 1",
        runner_group_name: "GitHub Actions",
        started_at: ~U[2021-01-01 00:00:00Z],
        workflow_run_id: workflow_run.id
      })
      |> Repo.insert!()

      assert :ok = WebhookHandler.handle_workflow_job(@workflow_job_payload)

      # Verify workflow job was updated, not duplicated
      workflow_jobs = Repo.all(WorkflowJob)
      assert length(workflow_jobs) == 1
      updated_job = hd(workflow_jobs)
      assert updated_job.status == "completed"
      assert updated_job.conclusion == "success"
      assert updated_job.completed_at == ~U[2021-01-01 00:01:00Z]
    end

    test "handles workflow_job without completed_at timestamp", %{workflow_run: _workflow_run} do
      payload = put_in(@workflow_job_payload, ["workflow_job", "completed_at"], nil)

      assert :ok = WebhookHandler.handle_workflow_job(payload)

      workflow_job = Repo.get_by(WorkflowJob, github_id: 4_407_365_498)
      assert workflow_job.completed_at == nil
    end

    test "returns error for invalid payload structure" do
      assert {:error, :invalid_payload} = WebhookHandler.handle_workflow_job("invalid")
      assert {:error, :invalid_payload} = WebhookHandler.handle_workflow_job(nil)
    end

    test "returns error for missing repository data" do
      payload = Map.delete(@workflow_job_payload, "repository")
      assert {:error, :missing_repository_data} = WebhookHandler.handle_workflow_job(payload)
    end

    test "creates minimal workflow_run when not found" do
      payload = put_in(@workflow_job_payload, ["workflow_job", "run_id"], 999_999_999)
      assert :ok = WebhookHandler.handle_workflow_job(payload)

      # Verify that a minimal workflow run was created
      workflow_run = Repo.get_by(WorkflowRun, github_id: 999_999_999)
      # From workflow_name in payload
      assert workflow_run.name == "CI"
      assert workflow_run.status == "in_progress"
      assert workflow_run.head_branch == "main"
      assert workflow_run.head_sha == "009b8a3a9ccbb128af87f9b1c0f4c62e8a304f6d"

      # Verify that the workflow job was also created
      workflow_job = Repo.get_by(WorkflowJob, github_id: 4_407_365_498)
      assert workflow_job.workflow_run_id == workflow_run.id
    end

    test "returns error for invalid workflow_run_id type" do
      payload = put_in(@workflow_job_payload, ["workflow_job", "run_id"], "invalid")
      assert {:error, :invalid_workflow_run_id} = WebhookHandler.handle_workflow_job(payload)
    end

    test "returns error for missing workflow_job data" do
      payload = Map.delete(@workflow_job_payload, "workflow_job")
      assert {:error, :missing_workflow_job_data} = WebhookHandler.handle_workflow_job(payload)
    end

    test "returns error for invalid datetime format" do
      payload = put_in(@workflow_job_payload, ["workflow_job", "started_at"], "invalid-date")
      assert {:error, {:invalid_datetime, _reason}} = WebhookHandler.handle_workflow_job(payload)
    end

    test "returns error for missing required datetime" do
      payload = put_in(@workflow_job_payload, ["workflow_job", "started_at"], nil)
      assert {:error, :missing_datetime} = WebhookHandler.handle_workflow_job(payload)
    end
  end

  describe "edge cases and error handling" do
    test "handle_workflow_run with missing required workflow_run fields" do
      payload = put_in(@workflow_run_payload, ["workflow_run", "name"], nil)

      # This should fail at the changeset validation level
      assert {:error, %Ecto.Changeset{}} = WebhookHandler.handle_workflow_run(payload)
    end

    test "handle_workflow_job with missing required workflow_job fields" do
      # First create the workflow run dependency
      repository =
        %Repository{}
        |> Repository.changeset(%{
          github_id: 35_129_377,
          owner: "github",
          name: "docs"
        })
        |> Repo.insert!()

      %WorkflowRun{}
      |> WorkflowRun.changeset(%{
        github_id: 1_234_567_890,
        name: "CI",
        status: "completed",
        workflow_id: 161_335,
        head_branch: "main",
        head_sha: "009b8a3a9ccbb128af87f9b1c0f4c62e8a304f6d",
        run_number: 42,
        started_at: ~U[2021-01-01 00:00:00Z],
        repository_id: repository.id
      })
      |> Repo.insert!()

      payload = put_in(@workflow_job_payload, ["workflow_job", "name"], nil)

      # This should fail at the changeset validation level
      assert {:error, %Ecto.Changeset{}} = WebhookHandler.handle_workflow_job(payload)
    end

    test "handle_workflow_run processes different workflow status values" do
      statuses = ["queued", "in_progress", "completed", "cancelled", "failure"]

      Enum.each(statuses, fn status ->
        payload = put_in(@workflow_run_payload, ["workflow_run", "status"], status)
        payload = put_in(payload, ["workflow_run", "id"], System.unique_integer([:positive]))

        assert :ok = WebhookHandler.handle_workflow_run(payload)

        workflow_run = Repo.get_by(WorkflowRun, github_id: payload["workflow_run"]["id"])
        assert workflow_run.status == status
      end)
    end
  end
end
