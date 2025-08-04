defmodule CiRunners.WorkflowJobs do
  @moduledoc """
  Context module for managing workflow jobs.

  Provides functions for creating, updating, and retrieving workflow job records
  based on GitHub webhook data.
  """

  alias CiRunners.Repo
  alias CiRunners.Github.WorkflowJob

  @doc """
  Creates or updates a workflow job based on GitHub webhook data.

  ## Parameters
  - workflow_job_data: Map containing GitHub workflow job information
  - workflow_run_id: ID of the associated workflow run

  ## Returns
  - {:ok, %WorkflowJob{}} on success
  - {:error, reason} on failure
  """
  def upsert_from_webhook(workflow_job_data, workflow_run_id) when is_map(workflow_job_data) do
    with {:ok, parsed_attrs} <- parse_webhook_attrs(workflow_job_data, workflow_run_id) do
      case get_by_github_id(parsed_attrs.github_id) do
        nil ->
          create_workflow_job(parsed_attrs)

        existing_job ->
          update_workflow_job(existing_job, parsed_attrs)
      end
    end
  end

  def upsert_from_webhook(workflow_job_data, _workflow_run_id)
      when not is_map(workflow_job_data) do
    {:error, :missing_workflow_job_data}
  end

  @doc """
  Gets a workflow job by its GitHub ID.

  ## Parameters
  - github_id: The GitHub ID of the workflow job

  ## Returns
  - %WorkflowJob{} if found
  - nil if not found
  """
  def get_by_github_id(github_id) do
    Repo.get_by(WorkflowJob, github_id: github_id)
  end

  @doc """
  Creates a new workflow job.

  ## Parameters
  - attrs: Map of workflow job attributes

  ## Returns
  - {:ok, %WorkflowJob{}} on success
  - {:error, %Ecto.Changeset{}} on failure
  """
  def create_workflow_job(attrs) do
    %WorkflowJob{}
    |> WorkflowJob.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing workflow job.

  ## Parameters
  - workflow_job: The workflow job struct to update
  - attrs: Map of updated attributes

  ## Returns
  - {:ok, %WorkflowJob{}} on success
  - {:error, %Ecto.Changeset{}} on failure
  """
  def update_workflow_job(%WorkflowJob{} = workflow_job, attrs) do
    workflow_job
    |> WorkflowJob.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Extracts workflow job data from webhook payload.

  ## Parameters
  - payload: The webhook payload map

  ## Returns
  - {:ok, workflow_job_data} if valid
  - {:error, :missing_workflow_job_data} if invalid
  """
  def extract_from_payload(%{"workflow_job" => workflow_job_data})
      when is_map(workflow_job_data) do
    {:ok, workflow_job_data}
  end

  def extract_from_payload(_payload) do
    {:error, :missing_workflow_job_data}
  end

  # Private functions

  defp parse_webhook_attrs(data, workflow_run_id) do
    with {:ok, started_at} <- parse_datetime(data["started_at"]),
         {:ok, completed_at} <- parse_optional_datetime(data["completed_at"]) do
      attrs = %{
        github_id: data["id"],
        name: data["name"],
        status: data["status"],
        conclusion: data["conclusion"],
        runner_name: data["runner_name"],
        runner_group_name: data["runner_group_name"],
        started_at: started_at,
        completed_at: completed_at,
        workflow_run_id: workflow_run_id
      }

      {:ok, attrs}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      {:error, reason} -> {:error, {:invalid_datetime, reason}}
    end
  end

  defp parse_datetime(nil) do
    {:error, :missing_datetime}
  end

  defp parse_optional_datetime(nil), do: {:ok, nil}
  defp parse_optional_datetime(datetime_string), do: parse_datetime(datetime_string)
end
