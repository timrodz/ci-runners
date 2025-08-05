defmodule CiRunners.PubSub do
  @moduledoc """
  PubSub helper module for broadcasting workflow events.

  This module provides functions for broadcasting workflow run and job updates
  to subscribers, enabling real-time dashboard updates.
  """

  require Logger
  alias Phoenix.PubSub

  @pubsub_name CiRunners.PubSub

  @doc """
  Broadcasts a workflow run update to all subscribers.

  ## Parameters
  - workflow_run: The WorkflowRun struct that was updated
  - status: The workflow status ("queued", "in_progress", "completed", etc.)

  ## Examples
      iex> CiRunners.PubSub.broadcast_workflow_run_update(workflow_run, "completed")
      :ok
  """
  def broadcast_workflow_run_update(workflow_run, event_type) do
    message =
      %{
        type: :workflow_run_updated,
        event_type: event_type,
        workflow_run: workflow_run
      }

    Logger.info("Broadcasting workflow run update: #{inspect(workflow_run.id)} - #{event_type}")
    PubSub.broadcast(@pubsub_name, workflow_runs_topic(), message)
  end

  @doc """
  Broadcasts a workflow job update to all subscribers.

  ## Parameters
  - workflow_job: The WorkflowJob struct that was updated
  - status: The workflow job status ("queued", "in_progress", "completed", etc.)

  ## Examples
      iex> CiRunners.PubSub.broadcast_workflow_job_update(workflow_job, "completed")
      :ok
  """
  def broadcast_workflow_job_update(workflow_job, event_type) do
    message =
      %{
        type: :workflow_job_updated,
        event_type: event_type,
        workflow_job: workflow_job
      }

    Logger.info("Broadcasting workflow job update: #{inspect(workflow_job.id)} - #{event_type}")
    PubSub.broadcast(@pubsub_name, workflow_jobs_topic(), message)
  end

  @doc """
  Subscribes to workflow run updates.

  ## Examples
      iex> CiRunners.PubSub.subscribe_to_workflow_runs()
      :ok
  """
  def subscribe_to_workflow_runs do
    PubSub.subscribe(@pubsub_name, workflow_runs_topic())
  end

  @doc """
  Subscribes to workflow job updates.

  ## Examples
      iex> CiRunners.PubSub.subscribe_to_workflow_jobs()
      :ok
  """
  def subscribe_to_workflow_jobs do
    PubSub.subscribe(@pubsub_name, workflow_jobs_topic())
  end

  @doc """
  Unsubscribes from workflow run updates.

  ## Examples
      iex> CiRunners.PubSub.unsubscribe_from_workflow_runs()
      :ok
  """
  def unsubscribe_from_workflow_runs do
    PubSub.unsubscribe(@pubsub_name, workflow_runs_topic())
  end

  @doc """
  Unsubscribes from workflow job updates.

  ## Examples
      iex> CiRunners.PubSub.unsubscribe_from_workflow_jobs()
      :ok
  """
  def unsubscribe_from_workflow_jobs do
    PubSub.unsubscribe(@pubsub_name, workflow_jobs_topic())
  end

  # Private functions

  defp workflow_runs_topic, do: "workflow_runs"
  defp workflow_jobs_topic, do: "workflow_jobs"
end
