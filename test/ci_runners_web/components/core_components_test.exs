defmodule CiRunnersWeb.CoreComponentsTest do
  use CiRunnersWeb.ConnCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import CiRunnersWeb.CoreComponents

  describe "status_badge/1" do
    test "renders queued status" do
      assigns = %{status: "queued", conclusion: nil}

      html =
        rendered_to_string(~H"""
        <.status_badge status={@status} conclusion={@conclusion} />
        """)

      assert html =~ "Queued"
      assert html =~ "bg-warning/20 text-warning-content"
    end

    test "renders in_progress status" do
      assigns = %{status: "in_progress", conclusion: nil}

      html =
        rendered_to_string(~H"""
        <.status_badge status={@status} conclusion={@conclusion} />
        """)

      assert html =~ "In Progress"
      assert html =~ "bg-info/20 text-info-content"
    end

    test "renders completed success status" do
      assigns = %{status: "completed", conclusion: "success"}

      html =
        rendered_to_string(~H"""
        <.status_badge status={@status} conclusion={@conclusion} />
        """)

      assert html =~ "Success"
      assert html =~ "bg-success/20 text-success-content"
    end

    test "renders completed failure status" do
      assigns = %{status: "completed", conclusion: "failure"}

      html =
        rendered_to_string(~H"""
        <.status_badge status={@status} conclusion={@conclusion} />
        """)

      assert html =~ "Failed"
      assert html =~ "bg-error/20 text-error-content"
    end

    test "renders completed cancelled status" do
      assigns = %{status: "completed", conclusion: "cancelled"}

      html =
        rendered_to_string(~H"""
        <.status_badge status={@status} conclusion={@conclusion} />
        """)

      assert html =~ "Cancelled"
      assert html =~ "bg-neutral/20 text-neutral-content"
    end

    test "renders with additional CSS classes" do
      assigns = %{status: "queued", conclusion: nil, class: "custom-class"}

      html =
        rendered_to_string(~H"""
        <.status_badge status={@status} conclusion={@conclusion} class={@class} />
        """)

      assert html =~ "custom-class"
    end

    test "handles unknown status gracefully" do
      assigns = %{status: "unknown_status", conclusion: nil}

      html =
        rendered_to_string(~H"""
        <.status_badge status={@status} conclusion={@conclusion} />
        """)

      assert html =~ "Unknown_status"
      assert html =~ "bg-neutral/20 text-neutral-content"
    end
  end

  describe "workflow_run_card/1" do
    setup do
      repository = %CiRunners.Github.Repository{
        id: 1,
        owner: "testowner",
        name: "testrepo",
        github_id: 123
      }

      workflow_run = %CiRunners.Github.WorkflowRun{
        id: 1,
        github_id: 456,
        name: "Test Workflow",
        status: "completed",
        conclusion: "success",
        run_number: 42,
        head_branch: "main",
        head_sha: "abcdef1234567890",
        started_at: ~U[2023-01-01 12:00:00Z],
        repository: repository
      }

      jobs = [
        %CiRunners.Github.WorkflowJob{
          id: 1,
          github_id: 789,
          name: "Test Job",
          status: "completed",
          conclusion: "success",
          runner_name: "ubuntu-latest",
          started_at: ~U[2023-01-01 12:05:00Z],
          workflow_run_id: 1
        }
      ]

      %{workflow_run: workflow_run, jobs: jobs}
    end

    test "renders workflow run information", %{workflow_run: workflow_run, jobs: jobs} do
      assigns = %{workflow_run: workflow_run, jobs: jobs}

      html =
        rendered_to_string(~H"""
        <.workflow_run_card workflow_run={@workflow_run} jobs={@jobs} />
        """)

      assert html =~ "Test Workflow"
      assert html =~ "Success"
      assert html =~ "#42"
      assert html =~ "testowner/testrepo"
      assert html =~ "main"
      assert html =~ "abcdef1"
    end

    test "renders jobs section when jobs are present", %{workflow_run: workflow_run, jobs: jobs} do
      assigns = %{workflow_run: workflow_run, jobs: jobs}

      html =
        rendered_to_string(~H"""
        <.workflow_run_card workflow_run={@workflow_run} jobs={@jobs} />
        """)

      assert html =~ "Jobs"
      assert html =~ "Test Job"
    end

    test "does not render jobs section when no jobs", %{workflow_run: workflow_run} do
      assigns = %{workflow_run: workflow_run, jobs: []}

      html =
        rendered_to_string(~H"""
        <.workflow_run_card workflow_run={@workflow_run} jobs={@jobs} />
        """)

      refute html =~ "Jobs"
    end

    test "handles workflow run without repository", %{jobs: jobs} do
      workflow_run = %CiRunners.Github.WorkflowRun{
        id: 1,
        github_id: 456,
        name: "Test Workflow",
        status: "in_progress",
        conclusion: nil,
        run_number: 42,
        head_branch: "main",
        head_sha: "abcdef1234567890",
        started_at: ~U[2023-01-01 12:00:00Z],
        repository: %Ecto.Association.NotLoaded{}
      }

      assigns = %{workflow_run: workflow_run, jobs: jobs}

      html =
        rendered_to_string(~H"""
        <.workflow_run_card workflow_run={@workflow_run} jobs={@jobs} />
        """)

      assert html =~ "Test Workflow"
      refute html =~ "testowner/testrepo"
    end
  end

  describe "workflow_job_item/1" do
    setup do
      repository = %CiRunners.Github.Repository{
        id: 1,
        owner: "testowner",
        name: "testrepo",
        github_id: 123
      }

      workflow_run = %CiRunners.Github.WorkflowRun{
        id: 1,
        github_id: 456,
        name: "Test Workflow",
        status: "completed",
        conclusion: "success",
        run_number: 42,
        head_branch: "main",
        head_sha: "abcdef1234567890",
        started_at: ~U[2023-01-01 12:00:00Z],
        repository: repository
      }

      %{workflow_run: workflow_run}
    end

    test "renders job information with link", %{workflow_run: workflow_run} do
      job = %CiRunners.Github.WorkflowJob{
        id: 1,
        github_id: 789,
        name: "Test Job",
        status: "completed",
        conclusion: "success",
        runner_name: "ubuntu-latest",
        started_at: ~U[2023-01-01 12:05:00Z],
        workflow_run_id: 1
      }

      assigns = %{job: job, workflow_run: workflow_run}

      html =
        rendered_to_string(~H"""
        <.workflow_job_item job={@job} workflow_run={@workflow_run} />
        """)

      assert html =~ "Test Job"
      assert html =~ "Success"
      assert html =~ "ubuntu-latest"
      assert html =~ "https://github.com/testowner/testrepo/actions/runs/456/job/789"
      assert html =~ "hero-arrow-top-right-on-square"
    end

    test "renders job without runner name", %{workflow_run: workflow_run} do
      job = %CiRunners.Github.WorkflowJob{
        id: 1,
        github_id: 789,
        name: "Test Job",
        status: "in_progress",
        conclusion: nil,
        runner_name: nil,
        started_at: ~U[2023-01-01 12:05:00Z],
        workflow_run_id: 1
      }

      assigns = %{job: job, workflow_run: workflow_run}

      html =
        rendered_to_string(~H"""
        <.workflow_job_item job={@job} workflow_run={@workflow_run} />
        """)

      assert html =~ "Test Job"
      assert html =~ "In Progress"
      refute html =~ "ubuntu-latest"
      assert html =~ "https://github.com/testowner/testrepo/actions/runs/456/job/789"
    end

    test "renders job without repository link" do
      workflow_run_no_repo = %CiRunners.Github.WorkflowRun{
        id: 1,
        github_id: 456,
        name: "Test Workflow",
        status: "completed",
        conclusion: "success",
        run_number: 42,
        head_branch: "main",
        head_sha: "abcdef1234567890",
        started_at: ~U[2023-01-01 12:00:00Z],
        repository: %Ecto.Association.NotLoaded{}
      }

      job = %CiRunners.Github.WorkflowJob{
        id: 1,
        github_id: 789,
        name: "Test Job",
        status: "completed",
        conclusion: "success",
        runner_name: "ubuntu-latest",
        started_at: ~U[2023-01-01 12:05:00Z],
        workflow_run_id: 1
      }

      assigns = %{job: job, workflow_run: workflow_run_no_repo}

      html =
        rendered_to_string(~H"""
        <.workflow_job_item job={@job} workflow_run={@workflow_run} />
        """)

      assert html =~ "Test Job"
      assert html =~ "Success"
      refute html =~ "https://github.com"
    end
  end

  describe "loading_state/1" do
    test "renders default loading message" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.loading_state />
        """)

      assert html =~ "Loading..."
      assert html =~ "animate-spin"
    end

    test "renders custom loading message" do
      assigns = %{message: "Loading workflows..."}

      html =
        rendered_to_string(~H"""
        <.loading_state message={@message} />
        """)

      assert html =~ "Loading workflows..."
    end
  end

  describe "connection_status/1" do
    test "renders connected status" do
      assigns = %{connected: true}

      html =
        rendered_to_string(~H"""
        <.connection_status connected={@connected} />
        """)

      assert html =~ "Connected"
      assert html =~ "bg-success"
      assert html =~ "animate-pulse"
    end

    test "renders disconnected status" do
      assigns = %{connected: false}

      html =
        rendered_to_string(~H"""
        <.connection_status connected={@connected} />
        """)

      assert html =~ "Disconnected"
      assert html =~ "bg-error"
      refute html =~ "animate-pulse"
    end
  end
end
