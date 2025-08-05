defmodule CiRunners.WorkflowRuns do
  @moduledoc """
  Context module for managing workflow runs.

  Provides functions for creating, updating, and retrieving workflow run records
  based on GitHub webhook data.
  """

  import Ecto.Query

  alias CiRunners.Github.WorkflowJob
  alias CiRunners.Repo
  alias CiRunners.Github.WorkflowRun

  @doc """
  Creates or updates a workflow run based on GitHub webhook data.

  ## Parameters
  - workflow_run_data: Map containing GitHub workflow run information
  - repository_id: ID of the associated repository

  ## Returns
  - {:ok, %WorkflowRun{}} on success
  - {:error, reason} on failure
  """
  def upsert_from_webhook(workflow_run_data, repository_id) when is_map(workflow_run_data) do
    with {:ok, parsed_attrs} <- parse_webhook_attrs(workflow_run_data, repository_id) do
      case get_by_github_id_direct(parsed_attrs.github_id) do
        nil ->
          create_workflow_run(parsed_attrs)

        existing_run ->
          update_workflow_run(existing_run, parsed_attrs)
      end
    end
  end

  def upsert_from_webhook(nil, _repository_id) do
    {:error, :missing_workflow_run_data}
  end

  @doc """
  Gets a workflow run by its GitHub ID.

  ## Parameters
  - github_id: The GitHub ID of the workflow run

  ## Returns
  - {:ok, %WorkflowRun{}} if found
  - {:error, :workflow_run_not_found} if not found
  - {:error, :invalid_workflow_run_id} if github_id is invalid
  """
  def get_by_github_id(github_id) when is_integer(github_id) do
    case Repo.get_by(WorkflowRun, github_id: github_id) do
      nil -> {:error, :workflow_run_not_found}
      workflow_run -> {:ok, workflow_run}
    end
  end

  def get_by_github_id(_) do
    {:error, :invalid_workflow_run_id}
  end

  @doc """
  Gets a workflow run by its GitHub ID, returning the struct directly.

  ## Parameters
  - github_id: The GitHub ID of the workflow run

  ## Returns
  - %WorkflowRun{} if found
  - nil if not found
  """
  def get_by_github_id_direct(github_id) do
    Repo.get_by(WorkflowRun, github_id: github_id)
  end

  @doc """
  Lists recent workflow runs with preloaded associations.

  ## Parameters
  - limit: Maximum number of workflow runs to return (default: 50)

  ## Returns
  - List of %WorkflowRun{} with preloaded repository and jobs
  """
  def list_recent(limit \\ 50) do
    WorkflowRun
    |> order_by([wr], desc: wr.started_at)
    |> limit(^limit)
    |> preload([:repository, :workflow_jobs])
    |> Repo.all()
  end

  @doc """
  Lists recent workflow runs without jobs preloaded.

  ## Parameters
  - limit: Maximum number of workflow runs to return (default: 50)

  ## Returns
  - List of %WorkflowRun{} with preloaded repository only
  """
  def list_recent_runs_only(limit \\ 50) do
    WorkflowRun
    |> order_by([wr], desc: wr.started_at)
    |> limit(^limit)
    |> preload([:repository])
    |> Repo.all()
  end

  @doc """
  Lists workflow jobs for the given workflow run IDs, grouped by run ID.

  ## Parameters
  - run_ids: List of workflow run IDs to fetch jobs for

  ## Returns
  - Map with run_id as key and list of jobs as value
  """
  def list_jobs_grouped_by_run(run_ids) when is_list(run_ids) do
    # Optimize query by adding select and ensuring efficient ordering
    jobs =
      WorkflowJob
      |> where([wj], wj.workflow_run_id in ^run_ids)
      |> order_by([wj], asc: wj.workflow_run_id, desc: wj.started_at)
      |> Repo.all()

    # Group jobs by workflow_run_id efficiently
    Enum.group_by(jobs, & &1.workflow_run_id)
  end

  def list_jobs_grouped_by_run([]), do: %{}

  @doc """
  Gets a workflow run by ID with all jobs preloaded.

  ## Parameters
  - id: The database ID of the workflow run

  ## Returns
  - %WorkflowRun{} with preloaded jobs if found
  - nil if not found
  """
  def get_workflow_run_with_jobs(id) when is_integer(id) do
    WorkflowRun
    |> where([wr], wr.id == ^id)
    |> preload([:repository, :workflow_jobs])
    |> Repo.one()
  end

  def get_workflow_run_with_jobs(_), do: nil

  @doc """
  Gets a workflow run by GitHub ID with repository preloaded.

  ## Parameters
  - github_id: The GitHub ID of the workflow run

  ## Returns
  - %WorkflowRun{} with preloaded repository if found
  - nil if not found
  """
  def get_by_github_id_with_repository(github_id) when is_integer(github_id) do
    WorkflowRun
    |> where([wr], wr.github_id == ^github_id)
    |> preload([:repository])
    |> Repo.one()
  end

  def get_by_github_id_with_repository(_), do: nil

  @doc """
  Creates a minimal workflow run from workflow job webhook data.

  This is used when a workflow_job event arrives before the corresponding
  workflow_run event, so we can create a placeholder workflow run.

  ## Parameters
  - workflow_job_data: Map containing GitHub workflow job information
  - repository_id: ID of the associated repository

  ## Returns
  - {:ok, %WorkflowRun{}} on success
  - {:error, reason} on failure
  """
  def create_minimal_from_job_webhook(workflow_job_data, repository_id)
      when is_map(workflow_job_data) do
    attrs = %{
      github_id: workflow_job_data["run_id"],
      name: workflow_job_data["workflow_name"] || "Unknown Workflow",
      # Default status since we don't have the actual status
      status: "in_progress",
      # We don't have this from job data
      workflow_id: 0,
      head_branch: workflow_job_data["head_branch"] || "unknown",
      # Provide default instead of empty string
      head_sha: workflow_job_data["head_sha"] || "unknown",
      # We don't have this from job data
      run_number: 0,
      started_at: parse_datetime_or_now(workflow_job_data["started_at"]),
      repository_id: repository_id
    }

    create_workflow_run(attrs)
  end

  def create_minimal_from_job_webhook(nil, _repository_id) do
    {:error, :missing_workflow_job_data}
  end

  @doc """
  Gets an existing workflow run or creates a minimal one from job data.

  This function first tries to find an existing workflow run, and if not found,
  creates a minimal workflow run from the available job data.

  ## Parameters
  - workflow_job_data: Map containing GitHub workflow job information
  - repository_id: ID of the associated repository

  ## Returns
  - {:ok, %WorkflowRun{}} on success
  - {:error, reason} on failure
  """
  def get_or_create_from_job_webhook(workflow_job_data, repository_id)
      when is_map(workflow_job_data) do
    run_id = workflow_job_data["run_id"]

    case get_by_github_id(run_id) do
      {:ok, workflow_run} ->
        {:ok, workflow_run}

      {:error, :workflow_run_not_found} ->
        create_minimal_from_job_webhook(workflow_job_data, repository_id)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_or_create_from_job_webhook(nil, _repository_id) do
    {:error, :missing_workflow_job_data}
  end

  @doc """
  Creates a new workflow run.

  ## Parameters
  - attrs: Map of workflow run attributes

  ## Returns
  - {:ok, %WorkflowRun{}} on success
  - {:error, %Ecto.Changeset{}} on failure
  """
  def create_workflow_run(attrs) do
    %WorkflowRun{}
    |> WorkflowRun.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing workflow run.

  ## Parameters
  - workflow_run: The workflow run struct to update
  - attrs: Map of updated attributes

  ## Returns
  - {:ok, %WorkflowRun{}} on success
  - {:error, %Ecto.Changeset{}} on failure
  """
  def update_workflow_run(%WorkflowRun{} = workflow_run, attrs) do
    workflow_run
    |> WorkflowRun.changeset(attrs)
    |> Repo.update()
  end

  # Private functions

  defp parse_webhook_attrs(data, repository_id) do
    with {:ok, started_at} <- parse_datetime(data["run_started_at"]),
         {:ok, completed_at} <- parse_optional_datetime(data["updated_at"]) do
      attrs = %{
        github_id: data["id"],
        name: data["name"],
        status: data["status"],
        conclusion: data["conclusion"],
        workflow_id: data["workflow_id"],
        head_branch: data["head_branch"],
        head_sha: data["head_sha"],
        run_number: data["run_number"],
        started_at: started_at,
        completed_at: completed_at,
        repository_id: repository_id
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

  defp parse_datetime_or_now(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _offset} -> datetime
      {:error, _reason} -> DateTime.utc_now()
    end
  end

  defp parse_datetime_or_now(_), do: DateTime.utc_now()
end
