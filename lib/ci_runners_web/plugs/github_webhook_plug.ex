defmodule CiRunnersWeb.GhWebhookPlug do
  import Plug.Conn
  require Logger

  def init(options) do
    options
  end

  @doc """
  Verifies secret and calls a handler with the webhook payload
  """
  def call(conn, options) do
    path = get_config(options, :path)

    case conn.request_path do
      ^path ->
        with {:ok, secret} <- get_webhook_secret(options),
             {:ok, signature} <- get_signature_header(conn),
             {:ok, payload} <- get_cached_body(conn),
             {:ok, parsed_payload} <- parse_json_payload(conn),
             true <- verify_signature(payload, secret, signature) do
          
          {module, function} = get_config(options, :action)
          apply(module, function, [conn, parsed_payload])
          conn |> send_resp(200, "OK") |> halt()
        else
          {:error, :missing_signature} ->
            conn |> send_resp(400, Jason.encode!(%{error: "Missing X-Hub-Signature-256 header"})) |> halt()
          
          {:error, :missing_secret} ->
            conn |> send_resp(500, Jason.encode!(%{error: "Webhook secret not configured"})) |> halt()
          
          {:error, :missing_body} ->
            conn |> send_resp(400, Jason.encode!(%{error: "Missing request body"})) |> halt()
          
          {:error, :invalid_json} ->
            conn |> send_resp(400, Jason.encode!(%{error: "Invalid JSON payload"})) |> halt()
          
          false ->
            conn |> send_resp(401, Jason.encode!(%{error: "Invalid signature"})) |> halt()
          
          error ->
            Logger.error("Unexpected webhook error: #{inspect(error)}")
            conn |> send_resp(500, Jason.encode!(%{error: "Internal server error"})) |> halt()
        end

      _ ->
        conn
    end
  end

  defp get_webhook_secret(options) do
    case get_config(options, :secret) do
      nil -> {:error, :missing_secret}
      "" -> {:error, :missing_secret}
      secret -> {:ok, secret}
    end
  end

  defp get_signature_header(conn) do
    case get_req_header(conn, "x-hub-signature-256") do
      [signature] -> {:ok, signature}
      [] -> {:error, :missing_signature}
      _ -> {:error, :missing_signature}
    end
  end

  defp get_cached_body(conn) do
    case CiRunnersWeb.CacheBodyReader.read_cached_body(conn) do
      {:ok, payload, _conn} -> {:ok, payload}
      {:error, _, _conn} -> {:error, :missing_body}
    end
  end

  defp parse_json_payload(conn) do
    case conn.body_params do
      %Plug.Conn.Unfetched{} -> {:error, :invalid_json}
      params when is_map(params) -> {:ok, params}
    end
  end

  defp verify_signature(payload, secret, signature_in_header) do
    signature =
      "sha256=" <> (:crypto.mac(:hmac, :sha256, secret, payload) |> Base.encode16(case: :lower))

    Plug.Crypto.secure_compare(signature, signature_in_header)
  end

  defp get_config(options, key) do
    options[key] || get_config(key)
  end

  defp get_config(key) do
    case Application.get_env(:ci_runners, github_webhook_secret_key(key)) do
      nil ->
        Logger.warning("GhWebhookPlug config key #{inspect(key)} is not configured.")
        nil

      val ->
        val
    end
  end

  defp github_webhook_secret_key(:secret), do: :github_webhook_secret
  defp github_webhook_secret_key(key), do: key
end
