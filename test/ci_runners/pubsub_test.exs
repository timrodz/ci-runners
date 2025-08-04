defmodule CiRunners.PubSubTest do
  use CiRunners.DataCase, async: true

  alias CiRunners.PubSub
  alias CiRunners.Github.{Repository, WorkflowRun, WorkflowJob}
  alias CiRunners.Repo

  describe "workflow run broadcasting" do
    test "broadcast_workflow_run_update/2 broadcasts correct message format" do
      repository =
        %Repository{}
        |> Repository.changeset(%{
          github_id: 123_456,
          owner: "test",
          name: "repo"
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
          head_sha: "abc123",
          run_number: 42,
          started_at: ~U[2021-01-01 00:00:00Z],
          repository_id: repository.id
        })
        |> Repo.insert!()

      # Subscribe to workflow runs
      assert :ok = PubSub.subscribe_to_workflow_runs()

      # Broadcast update
      assert :ok = PubSub.broadcast_workflow_run_update(workflow_run, "completed")

      # Verify message received
      assert_receive %{
        type: :workflow_run_updated,
        event_type: "completed",
        workflow_run: ^workflow_run
      }
    end

    test "subscribe_to_workflow_runs/0 allows receiving messages" do
      repository =
        %Repository{}
        |> Repository.changeset(%{
          github_id: 123_456,
          owner: "test",
          name: "repo"
        })
        |> Repo.insert!()

      workflow_run =
        %WorkflowRun{}
        |> WorkflowRun.changeset(%{
          github_id: 1_234_567_890,
          name: "CI",
          status: "in_progress",
          workflow_id: 161_335,
          head_branch: "main",
          head_sha: "abc123",
          run_number: 42,
          started_at: ~U[2021-01-01 00:00:00Z],
          repository_id: repository.id
        })
        |> Repo.insert!()

      # Subscribe and broadcast
      assert :ok = PubSub.subscribe_to_workflow_runs()
      assert :ok = PubSub.broadcast_workflow_run_update(workflow_run, "in_progress")

      # Should receive message
      assert_receive %{type: :workflow_run_updated, event_type: "in_progress"}
    end

    test "unsubscribe_from_workflow_runs/0 stops receiving messages" do
      repository =
        %Repository{}
        |> Repository.changeset(%{
          github_id: 123_456,
          owner: "test",
          name: "repo"
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
          head_sha: "abc123",
          run_number: 42,
          started_at: ~U[2021-01-01 00:00:00Z],
          repository_id: repository.id
        })
        |> Repo.insert!()

      # Subscribe, unsubscribe, then broadcast
      assert :ok = PubSub.subscribe_to_workflow_runs()
      assert :ok = PubSub.unsubscribe_from_workflow_runs()
      assert :ok = PubSub.broadcast_workflow_run_update(workflow_run, "completed")

      # Should not receive message
      refute_receive %{type: :workflow_run_updated}, 100
    end
  end

  describe "workflow job broadcasting" do
    test "broadcast_workflow_job_update/2 broadcasts correct message format" do
      repository =
        %Repository{}
        |> Repository.changeset(%{
          github_id: 123_456,
          owner: "test",
          name: "repo"
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
          head_sha: "abc123",
          run_number: 42,
          started_at: ~U[2021-01-01 00:00:00Z],
          repository_id: repository.id
        })
        |> Repo.insert!()

      workflow_job =
        %WorkflowJob{}
        |> WorkflowJob.changeset(%{
          github_id: 4_407_365_498,
          name: "test",
          status: "completed",
          conclusion: "success",
          runner_name: "GitHub Actions 1",
          runner_group_name: "GitHub Actions",
          started_at: ~U[2021-01-01 00:00:00Z],
          completed_at: ~U[2021-01-01 00:01:00Z],
          workflow_run_id: workflow_run.id
        })
        |> Repo.insert!()

      # Subscribe to workflow jobs
      assert :ok = PubSub.subscribe_to_workflow_jobs()

      # Broadcast update
      assert :ok = PubSub.broadcast_workflow_job_update(workflow_job, "completed")

      # Verify message received
      assert_receive %{
        type: :workflow_job_updated,
        event_type: "completed",
        workflow_job: ^workflow_job
      }
    end

    test "subscribe_to_workflow_jobs/0 allows receiving messages" do
      repository =
        %Repository{}
        |> Repository.changeset(%{
          github_id: 123_456,
          owner: "test",
          name: "repo"
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
          head_sha: "abc123",
          run_number: 42,
          started_at: ~U[2021-01-01 00:00:00Z],
          repository_id: repository.id
        })
        |> Repo.insert!()

      workflow_job =
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

      # Subscribe and broadcast
      assert :ok = PubSub.subscribe_to_workflow_jobs()
      assert :ok = PubSub.broadcast_workflow_job_update(workflow_job, "in_progress")

      # Should receive message
      assert_receive %{type: :workflow_job_updated, event_type: "in_progress"}
    end

    test "unsubscribe_from_workflow_jobs/0 stops receiving messages" do
      repository =
        %Repository{}
        |> Repository.changeset(%{
          github_id: 123_456,
          owner: "test",
          name: "repo"
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
          head_sha: "abc123",
          run_number: 42,
          started_at: ~U[2021-01-01 00:00:00Z],
          repository_id: repository.id
        })
        |> Repo.insert!()

      workflow_job =
        %WorkflowJob{}
        |> WorkflowJob.changeset(%{
          github_id: 4_407_365_498,
          name: "test",
          status: "completed",
          conclusion: "success",
          runner_name: "GitHub Actions 1",
          runner_group_name: "GitHub Actions",
          started_at: ~U[2021-01-01 00:00:00Z],
          completed_at: ~U[2021-01-01 00:01:00Z],
          workflow_run_id: workflow_run.id
        })
        |> Repo.insert!()

      # Subscribe, unsubscribe, then broadcast
      assert :ok = PubSub.subscribe_to_workflow_jobs()
      assert :ok = PubSub.unsubscribe_from_workflow_jobs()
      assert :ok = PubSub.broadcast_workflow_job_update(workflow_job, "completed")

      # Should not receive message
      refute_receive %{type: :workflow_job_updated}, 100
    end
  end

  describe "integration with webhook handler" do
    test "workflow run webhook processing broadcasts message" do
      # Subscribe before operation
      assert :ok = PubSub.subscribe_to_workflow_runs()

      # Process workflow run through webhook handler
      payload = %{
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

      assert :ok = CiRunners.Github.WebhookHandler.handle_workflow_run(payload)

      # Should receive broadcast message
      assert_receive %{
        type: :workflow_run_updated,
        event_type: "completed"
      }
    end

    test "workflow job webhook processing broadcasts message" do
      # Subscribe before operation
      assert :ok = PubSub.subscribe_to_workflow_jobs()

      # Process workflow job through webhook handler
      payload = %{
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

      assert :ok = CiRunners.Github.WebhookHandler.handle_workflow_job(payload)

      # Should receive broadcast message
      assert_receive %{
        type: :workflow_job_updated,
        event_type: "completed"
      }
    end
  end
end
