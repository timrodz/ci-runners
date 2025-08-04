defmodule CiRunners.Github.WebhookHandler do
  @moduledoc """
  Handles GitHub webhook events for workflow runs and jobs.

  This module processes GitHub webhook payloads and delegates to the appropriate
  context modules for database operations.

  GitHub sends events in the following order: `check_run`, `workflow_job`, `workflow_run`.
  """

  alias CiRunners.{Repositories, WorkflowRuns, WorkflowJobs}

  @doc """
  Handles a workflow_job webhook event.

  This function:
  1. Upserts the repository information
  2. Gets or creates the associated workflow run (handles cases where job arrives before run)
  3. Upserts the workflow job information

  Returns :ok on success, {:error, reason} on failure.
  """
  def handle_workflow_job(payload) when is_map(payload) do
    with {:ok, repository} <- Repositories.upsert_from_webhook(payload["repository"]),
         {:ok, workflow_job_data} <- WorkflowJobs.extract_from_payload(payload),
         {:ok, workflow_run} <-
           WorkflowRuns.get_or_create_from_job_webhook(workflow_job_data, repository.id),
         {:ok, _workflow_job} <-
           WorkflowJobs.upsert_from_webhook(workflow_job_data, workflow_run.id) do
      :ok
    else
      error ->
        error
    end
  end

  def handle_workflow_job(_payload) do
    {:error, :invalid_payload}
  end

  @doc """
  Handles a workflow_run webhook event.

  This function:
  1. Upserts the repository information
  2. Upserts the workflow run information

  Returns :ok on success, {:error, reason} on failure.
  """
  def handle_workflow_run(payload) when is_map(payload) do
    with {:ok, repository} <- Repositories.upsert_from_webhook(payload["repository"]),
         {:ok, _workflow_run} <-
           WorkflowRuns.upsert_from_webhook(payload["workflow_run"], repository.id) do
      :ok
    else
      error ->
        error
    end
  end

  def handle_workflow_run(_payload) do
    {:error, :invalid_payload}
  end
end
