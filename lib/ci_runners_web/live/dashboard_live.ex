defmodule CiRunnersWeb.DashboardLive do
  @moduledoc """
  LiveView module for the real-time GitHub Actions dashboard.

  Displays workflow runs and jobs with real-time updates via PubSub.
  """

  use CiRunnersWeb, :live_view

  import CiRunnersWeb.CoreComponents

  alias CiRunners.WorkflowRuns
  alias CiRunners.PubSub

  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to PubSub topics for real-time updates
    PubSub.subscribe_to_workflow_runs()
    PubSub.subscribe_to_workflow_jobs()

    # Load recent workflow runs without jobs
    workflow_runs = WorkflowRuns.list_recent_runs_only(20)

    # Get job data grouped by run ID
    run_ids = Enum.map(workflow_runs, & &1.id)
    jobs_by_run = WorkflowRuns.list_jobs_grouped_by_run(run_ids)

    socket =
      socket
      |> stream(:workflow_runs, workflow_runs,
        limit: 20,
        sort_by: & &1.started_at,
        sort_dir: :desc
      )
      |> assign(:page_title, "GitHub Actions Dashboard")
      |> assign(:jobs_by_run, jobs_by_run)

    {:ok, socket}
  end

  @impl true
  def handle_info(%{type: :workflow_run_updated, workflow_run: updated_run}, socket) do
    # Try to get the workflow run with repository preloaded for the UI
    # If found, merge the updated data with the repository preload
    # If not found (e.g., in tests), use the provided struct as-is
    workflow_run_to_use =
      case WorkflowRuns.get_by_github_id_with_repository(updated_run.github_id) do
        %CiRunners.Github.WorkflowRun{} = db_run ->
          # Merge updated fields with database run (which has repository preloaded)
          %{
            db_run
            | status: updated_run.status,
              conclusion: updated_run.conclusion,
              completed_at: updated_run.completed_at
          }

        nil ->
          updated_run
      end

    # Update the workflow run in the stream
    updated_socket = stream_insert(socket, :workflow_runs, workflow_run_to_use)

    # Update jobs for this run
    updated_socket_with_jobs = update_jobs_for_run(updated_socket, updated_run.id)

    {:noreply, updated_socket_with_jobs}
  end

  @impl true
  def handle_info(%{type: :workflow_job_updated, workflow_job: updated_job}, socket) do
    # Update jobs for the affected workflow run
    updated_socket = update_jobs_for_run(socket, updated_job.workflow_run_id)

    {:noreply, updated_socket}
  end

  @impl true
  def handle_info(_message, socket) do
    # Ignore unknown messages
    {:noreply, socket}
  end

  # Helper function for updating jobs in socket assigns
  defp update_jobs_for_run(socket, workflow_run_id) do
    jobs_for_run = WorkflowRuns.list_jobs_grouped_by_run([workflow_run_id])
    updated_jobs_by_run = Map.merge(socket.assigns.jobs_by_run, jobs_for_run)
    assign(socket, :jobs_by_run, updated_jobs_by_run)
  end

  # Helper function to check connection status
  defp socket_connected?(socket) do
    Phoenix.LiveView.connected?(socket)
  end
end
