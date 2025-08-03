defmodule CiRunnersWeb.WebhookController do
  use CiRunnersWeb, :controller
  require Logger

  @doc """
  Receives GitHub webhook events and processes them.
  
  Note: This function is called by GhWebhookPlug after signature verification,
  so we can assume the request is authenticated and the payload is valid JSON.
  """
  def receive(conn, payload) do
    case get_event_type_header(conn) do
      {:ok, event_type} ->
        case handle_event(event_type, payload) do
          :ok ->
            Logger.info("Successfully processed #{event_type} event")
            # Response is handled by the plug, just return the conn
            conn

          {:error, :unsupported_event} ->
            Logger.info("Ignored unsupported event: #{event_type}")
            # Response is handled by the plug, just return the conn
            conn
        end

      {:error, :missing_event_type} ->
        Logger.warning("Missing X-GitHub-Event header")
        # Response is handled by the plug, just return the conn
        conn
    end
  end

  defp get_event_type_header(conn) do
    case Plug.Conn.get_req_header(conn, "x-github-event") do
      [event_type] -> {:ok, event_type}
      [] -> {:error, :missing_event_type}
      _ -> {:error, :missing_event_type}
    end
  end

  defp handle_event("workflow_run", payload) do
    # TODO: Call WebhookHandler.handle_workflow_run/1 when implemented
    Logger.info("Received workflow_run event: #{inspect(payload["action"])}")
    :ok
  end

  defp handle_event("workflow_job", payload) do
    # TODO: Call WebhookHandler.handle_workflow_job/1 when implemented
    Logger.info("Received workflow_job event: #{inspect(payload["action"])}")
    :ok
  end

  defp handle_event(event_type, _payload) do
    Logger.info("Unsupported event type: #{event_type}")
    {:error, :unsupported_event}
  end
end
