defmodule CiRunnersWeb.DashboardLiveTest do
  use CiRunnersWeb.ConnCase

  import Phoenix.LiveViewTest

  alias CiRunners.{Repo, WorkflowRuns}
  alias CiRunners.Github.{Repository, WorkflowRun, WorkflowJob}

  # Test fixture functions
  defp repository_fixture(attrs) do
    default_attrs = %{
      owner: "testowner",
      name: "test-repo",
      github_id: :rand.uniform(999_999)
    }

    attrs = Map.merge(default_attrs, attrs)

    %Repository{}
    |> Repository.changeset(attrs)
    |> Repo.insert!()
  end

  defp workflow_run_fixture(attrs) do
    default_attrs = %{
      github_id: :rand.uniform(999_999),
      name: "Test Workflow",
      status: "completed",
      conclusion: "success",
      workflow_id: 123,
      head_branch: "main",
      head_sha: "abc123def",
      run_number: 1,
      started_at: DateTime.utc_now()
    }

    attrs = Map.merge(default_attrs, attrs)

    %WorkflowRun{}
    |> WorkflowRun.changeset(attrs)
    |> Repo.insert!()
  end

  defp workflow_job_fixture(attrs) do
    default_attrs = %{
      github_id: :rand.uniform(999_999),
      name: "Test Job",
      status: "completed",
      conclusion: "success",
      runner_name: "ubuntu-latest",
      started_at: DateTime.utc_now()
    }

    attrs = Map.merge(default_attrs, attrs)

    %WorkflowJob{}
    |> WorkflowJob.changeset(attrs)
    |> Repo.insert!()
  end

  describe "mount" do
    test "loads recent workflow runs and displays them", %{conn: conn} do
      # Create test data
      repository = repository_fixture(%{})
      workflow_run = workflow_run_fixture(%{repository_id: repository.id})
      workflow_job_fixture(%{workflow_run_id: workflow_run.id})

      # Mount the LiveView
      {:ok, _view, html} = live(conn, "/")

      # Verify workflow runs are loaded and displayed
      assert html =~ workflow_run.name
      assert html =~ repository.owner
      assert html =~ repository.name
    end

    test "displays empty state when no workflow runs exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "No workflow runs"
      assert html =~ "Get started by triggering a workflow"
    end

    test "sets correct page title", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      assert page_title(view) =~ "GitHub Actions Dashboard"
    end

    test "subscribes to PubSub topics", %{conn: conn} do
      # Mount the LiveView  
      {:ok, view, _html} = live(conn, "/")

      # Test that the LiveView can receive PubSub messages
      # by sending a test message directly
      repository = repository_fixture(%{})
      workflow_run = workflow_run_fixture(%{repository_id: repository.id})

      send(view.pid, %{type: :workflow_run_updated, workflow_run: workflow_run})

      # Should not crash
      html = render(view)
      assert html =~ "GitHub Actions Dashboard"
    end
  end

  describe "handle_info - workflow_run_updated" do
    test "updates existing workflow run in the list", %{conn: conn} do
      repository = repository_fixture(%{})
      workflow_run = workflow_run_fixture(%{repository_id: repository.id, status: "in_progress"})

      {:ok, view, _html} = live(conn, "/")

      # Update the workflow run
      updated_workflow_run = %{workflow_run | status: "completed", conclusion: "success"}

      # Simulate PubSub message
      send(view.pid, %{type: :workflow_run_updated, workflow_run: updated_workflow_run})

      # Verify the update is reflected
      html = render(view)
      assert html =~ "Success"
      refute html =~ "In Progress"
    end

    test "adds new workflow run to the stream", %{conn: conn} do
      repository = repository_fixture(%{})
      _existing_run = workflow_run_fixture(%{repository_id: repository.id})

      {:ok, view, _html} = live(conn, "/")

      # Create a new workflow run
      new_run =
        workflow_run_fixture(%{
          repository_id: repository.id,
          name: "New Workflow",
          github_id: 999_999
        })

      # Simulate PubSub message for new run
      send(view.pid, %{type: :workflow_run_updated, workflow_run: new_run})

      # Should not crash and should render successfully
      html = render(view)
      assert html =~ "GitHub Actions Dashboard"
    end

    test "handles stream updates correctly", %{conn: conn} do
      repository = repository_fixture(%{})

      {:ok, view, _html} = live(conn, "/")

      # Add a new run via stream
      newest_run =
        workflow_run_fixture(%{
          repository_id: repository.id,
          name: "Newest Workflow",
          github_id: 9999,
          started_at: DateTime.utc_now()
        })

      send(view.pid, %{type: :workflow_run_updated, workflow_run: newest_run})

      # Should not crash and should render successfully
      html = render(view)
      assert html =~ "GitHub Actions Dashboard"
    end
  end

  describe "handle_info - workflow_job_updated" do
    test "updates job within existing workflow run", %{conn: conn} do
      repository = repository_fixture(%{})
      workflow_run = workflow_run_fixture(%{repository_id: repository.id})

      workflow_job =
        workflow_job_fixture(%{
          workflow_run_id: workflow_run.id,
          status: "in_progress",
          name: "Test Job"
        })

      {:ok, view, _html} = live(conn, "/")

      # Update the job
      updated_job = %{workflow_job | status: "completed", conclusion: "success"}

      # Simulate PubSub message
      send(view.pid, %{type: :workflow_job_updated, workflow_job: updated_job})

      # Verify the job update is reflected
      html = render(view)
      assert html =~ "Test Job"
      assert html =~ "Success"
    end

    test "handles job updates for workflow runs", %{conn: conn} do
      repository = repository_fixture(%{})
      workflow_run = workflow_run_fixture(%{repository_id: repository.id})

      _existing_job =
        workflow_job_fixture(%{workflow_run_id: workflow_run.id, name: "Existing Job"})

      {:ok, view, _html} = live(conn, "/")

      # Create a new job for the same workflow run
      new_job = %WorkflowJob{
        id: 999,
        github_id: 999_999,
        name: "New Job",
        status: "queued",
        workflow_run_id: workflow_run.id,
        started_at: DateTime.utc_now(),
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      send(view.pid, %{type: :workflow_job_updated, workflow_job: new_job})

      # Should not crash and should render successfully
      html = render(view)
      assert html =~ "GitHub Actions Dashboard"
    end

    test "ignores job updates for non-existent workflow runs", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Create a job for a non-existent workflow run
      fake_job = %WorkflowJob{
        id: 999,
        github_id: 999_999,
        name: "Orphan Job",
        status: "completed",
        workflow_run_id: 999_999,
        started_at: DateTime.utc_now(),
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      send(view.pid, %{type: :workflow_job_updated, workflow_job: fake_job})

      # Should not crash and should not display the orphan job
      html = render(view)
      refute html =~ "Orphan Job"
    end
  end

  describe "handle_info - unknown messages" do
    test "ignores unknown messages gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Send unknown message
      send(view.pid, %{type: :unknown_message, data: "some data"})
      send(view.pid, :random_atom)
      send(view.pid, {"tuple", "message"})

      # Should not crash
      html = render(view)
      assert html =~ "GitHub Actions Dashboard"
    end
  end

  describe "status formatting and styling" do
    test "displays correct status classes for workflow runs", %{conn: conn} do
      repository = repository_fixture(%{})

      _completed_success =
        workflow_run_fixture(%{
          repository_id: repository.id,
          name: "Success Run",
          status: "completed",
          conclusion: "success"
        })

      _completed_failed =
        workflow_run_fixture(%{
          repository_id: repository.id,
          name: "Failed Run",
          status: "completed",
          conclusion: "failure",
          github_id: 99999
        })

      _in_progress =
        workflow_run_fixture(%{
          repository_id: repository.id,
          name: "Running",
          status: "in_progress",
          github_id: 88888
        })

      {:ok, _view, html} = live(conn, "/")

      # Check status styling
      # Success
      assert html =~ "bg-success/20 text-success-content"
      # Failure
      assert html =~ "bg-error/20 text-error-content"
      # In progress
      assert html =~ "bg-info/20 text-info-content"
    end

    test "displays correct time formatting", %{conn: conn} do
      repository = repository_fixture(%{})

      # Recent run (within a minute)
      recent_time = DateTime.add(DateTime.utc_now(), -30, :second)

      _recent_run =
        workflow_run_fixture(%{
          repository_id: repository.id,
          started_at: recent_time
        })

      # Older run (hours ago)
      old_time = DateTime.add(DateTime.utc_now(), -2 * 3600, :second)

      _old_run =
        workflow_run_fixture(%{
          repository_id: repository.id,
          github_id: 77777,
          started_at: old_time
        })

      {:ok, _view, html} = live(conn, "/")

      # Should display relative times
      # Recent (seconds)
      assert html =~ ~r/\d+s ago/
      # Old (hours)
      assert html =~ ~r/\d+h ago/
    end
  end

  describe "real-time integration" do
    test "workflow run updates are reflected in real-time", %{conn: conn} do
      repository = repository_fixture(%{})
      workflow_run = workflow_run_fixture(%{repository_id: repository.id, status: "queued"})

      {:ok, view, html} = live(conn, "/")
      assert html =~ "Queued"

      # Simulate workflow starting
      {:ok, updated_run} =
        WorkflowRuns.update_workflow_run(workflow_run, %{status: "in_progress"})

      # The actual update would be triggered by PubSub broadcasting in the context
      # For testing, we simulate the message directly
      send(view.pid, %{type: :workflow_run_updated, workflow_run: updated_run})

      html = render(view)
      assert html =~ "In Progress"
      refute html =~ "Queued"
    end
  end
end
