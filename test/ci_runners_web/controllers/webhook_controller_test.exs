defmodule CiRunnersWeb.WebhookControllerTest do
  use CiRunnersWeb.ConnCase, async: true

  @workflow_run_payload %{
    "action" => "completed",
    "workflow_run" => %{
      "id" => 1_234_567_890,
      "name" => "CI",
      "status" => "completed",
      "conclusion" => "success",
      "workflow_id" => 161_335,
      "check_suite_id" => 4_207_861_019,
      "check_suite_node_id" => "CS_kwDOAI9QM88AAAAFdSadk",
      "url" => "https://api.github.com/repos/github/docs/actions/runs/1234567890",
      "html_url" => "https://github.com/github/docs/actions/runs/1234567890",
      "head_branch" => "main",
      "head_sha" => "009b8a3a9ccbb128af87f9b1c0f4c62e8a304f6d",
      "run_number" => 42,
      "event" => "push",
      "created_at" => "2021-01-01T00:00:00Z",
      "updated_at" => "2021-01-01T00:01:00Z",
      "run_started_at" => "2021-01-01T00:00:00Z"
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
      "run_url" => "https://api.github.com/repos/github/docs/actions/runs/1234567890",
      "run_attempt" => 1,
      "node_id" => "CR_kwDOAI9QM88AAAABBKqOmg",
      "head_sha" => "009b8a3a9ccbb128af87f9b1c0f4c62e8a304f6d",
      "url" => "https://api.github.com/repos/github/docs/actions/jobs/4407365498",
      "html_url" => "https://github.com/github/docs/actions/runs/1234567890/jobs/4407365498",
      "status" => "completed",
      "conclusion" => "success",
      "started_at" => "2021-01-01T00:00:00Z",
      "completed_at" => "2021-01-01T00:01:00Z",
      "name" => "test",
      "runner_id" => 1,
      "runner_name" => "GitHub Actions 1",
      "runner_group_id" => 2,
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

  setup do
    # Set up a test secret for webhook verification
    Application.put_env(:ci_runners, :github_webhook_secret, "test_secret")

    on_exit(fn ->
      Application.delete_env(:ci_runners, :github_webhook_secret)
    end)
  end

  describe "POST /webhooks/github" do
    test "processes valid workflow_run webhook", %{conn: conn} do
      signature = generate_signature(@workflow_run_payload, "test_secret")

      conn = webhook_request(conn, @workflow_run_payload, "workflow_run", signature)

      assert response(conn, 200) == "OK"
    end

    test "processes valid workflow_job webhook", %{conn: conn} do
      signature = generate_signature(@workflow_job_payload, "test_secret")

      conn = webhook_request(conn, @workflow_job_payload, "workflow_job", signature)

      assert response(conn, 200) == "OK"
    end

    test "ignores unsupported event types", %{conn: conn} do
      payload = %{"action" => "opened", "issue" => %{"id" => 1}}
      signature = generate_signature(payload, "test_secret")

      conn = webhook_request(conn, payload, "issues", signature)

      assert response(conn, 200) == "OK"
    end

    test "returns 401 for invalid signature", %{conn: conn} do
      invalid_signature = "sha256=invalid_signature_hash"

      conn = webhook_request(conn, @workflow_run_payload, "workflow_run", invalid_signature)

      assert response(conn, 401)
      response_body = Jason.decode!(response(conn, 401))
      assert response_body["error"] == "Invalid signature"
    end

    test "returns 400 for missing signature header", %{conn: conn} do
      payload_json = Jason.encode!(@workflow_run_payload)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-github-event", "workflow_run")
        |> post("/api/webhooks/github", payload_json)

      assert response(conn, 400)
      response_body = Jason.decode!(response(conn, 400))
      assert response_body["error"] == "Missing X-Hub-Signature-256 header"
    end

    test "returns 200 for missing event type header (handled gracefully)", %{conn: conn} do
      signature = generate_signature(@workflow_run_payload, "test_secret")
      payload_json = Jason.encode!(@workflow_run_payload)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-hub-signature-256", signature)
        |> post("/api/webhooks/github", payload_json)

      # The plug successfully verifies signature and calls controller,
      # controller logs warning but returns 200 via plug
      assert response(conn, 200) == "OK"
    end

    test "returns 400 for invalid JSON payload", %{conn: conn} do
      invalid_payload = "{ invalid json"
      signature = generate_signature(invalid_payload, "test_secret")

      # This test expects Phoenix's JSON parser to catch the error,
      # so we expect a Plug.Parsers.ParseError to be raised
      assert_raise Plug.Parsers.ParseError, fn ->
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-hub-signature-256", signature)
        |> put_req_header("x-github-event", "workflow_run")
        |> post("/api/webhooks/github", invalid_payload)
      end
    end

    test "returns 500 when webhook secret is not configured", %{conn: conn} do
      # Remove the secret configuration
      Application.delete_env(:ci_runners, :github_webhook_secret)

      signature = generate_signature(@workflow_run_payload, "test_secret")

      conn = webhook_request(conn, @workflow_run_payload, "workflow_run", signature)

      assert response(conn, 500)
      response_body = Jason.decode!(response(conn, 500))
      assert response_body["error"] == "Webhook secret not configured"

      # Restore secret for other tests
      Application.put_env(:ci_runners, :github_webhook_secret, "test_secret")
    end

    test "handles empty payload", %{conn: conn} do
      payload = "{}"
      signature = generate_signature(payload, "test_secret")

      # Empty JSON object should be handled gracefully
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-hub-signature-256", signature)
        |> put_req_header("x-github-event", "workflow_run")
        |> post("/api/webhooks/github", payload)

      # Empty object should be processed successfully
      assert response(conn, 200) == "OK"
    end

    test "verifies signature with different secret fails", %{conn: conn} do
      # Generate signature with wrong secret
      signature = generate_signature(@workflow_run_payload, "wrong_secret")

      conn = webhook_request(conn, @workflow_run_payload, "workflow_run", signature)

      assert response(conn, 401)
      response_body = Jason.decode!(response(conn, 401))
      assert response_body["error"] == "Invalid signature"
    end
  end

  defp generate_signature(payload, secret) do
    # Convert payload to string if it's an object, to match what WebhookVerifier does
    payload_string =
      case payload do
        payload when is_binary(payload) -> payload
        payload -> Jason.encode!(payload)
      end

    signature = :crypto.mac(:hmac, :sha256, secret, payload_string)
    "sha256=" <> Base.encode16(signature, case: :lower)
  end

  defp webhook_request(conn, payload, event_type, signature) do
    # Convert payload to JSON string for the request body
    payload_json =
      case payload do
        payload when is_binary(payload) -> payload
        payload -> Jason.encode!(payload)
      end

    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("x-hub-signature-256", signature)
    |> put_req_header("x-github-event", event_type)
    |> post("/api/webhooks/github", payload_json)
  end
end
