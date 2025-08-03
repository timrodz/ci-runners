defmodule CiRunners.Github.WebhookVerifier do
  @moduledoc """
  Verifies GitHub webhook signatures using HMAC-SHA256.
  
  GitHub signs webhook payloads with a secret key and includes the signature
  in the X-Hub-Signature-256 header. This module provides secure verification
  of these signatures using constant-time comparison to prevent timing attacks.
  """

  import Bitwise

  @doc """
  Verifies a GitHub webhook signature against the payload.
  
  ## Parameters
  
    * `signature` - The signature from the X-Hub-Signature-256 header
    * `payload` - The raw request body as a string
    * `secret` - The webhook secret configured in GitHub
  
  ## Returns
  
    * `true` if the signature is valid
    * `false` if the signature is invalid or malformed
  
  ## Examples
  
      iex> CiRunners.Github.WebhookVerifier.verify_signature("sha256=abc123", "payload", "secret")
      false
      
      iex> valid_sig = "sha256=" <> Base.encode16(:crypto.mac(:hmac, :sha256, "secret", "payload"), case: :lower)
      iex> CiRunners.Github.WebhookVerifier.verify_signature(valid_sig, "payload", "secret")
      true
  """
  def verify_signature(signature, payload, secret) when is_binary(signature) and is_binary(payload) and is_binary(secret) do
    case parse_signature(signature) do
      {:ok, received_signature} ->
        expected_signature = compute_signature(payload, secret)
        secure_compare(received_signature, expected_signature)
      
      :error ->
        false
    end
  end

  def verify_signature(_, _, _), do: false

  @doc """
  Parses the X-Hub-Signature-256 header value.
  
  GitHub sends signatures in the format "sha256=<hex_signature>".
  
  ## Parameters
  
    * `signature_header` - The value from the X-Hub-Signature-256 header
  
  ## Returns
  
    * `{:ok, signature}` if the header is properly formatted
    * `:error` if the header is malformed
  """
  def parse_signature("sha256=" <> signature) when byte_size(signature) > 0 do
    case Base.decode16(signature, case: :mixed) do
      {:ok, decoded} -> {:ok, decoded}
      :error -> :error
    end
  end

  def parse_signature(_), do: :error

  @doc """
  Computes the HMAC-SHA256 signature for a payload using the given secret.
  
  ## Parameters
  
    * `payload` - The request body as a string
    * `secret` - The webhook secret
  
  ## Returns
  
    * The computed signature as binary
  """
  def compute_signature(payload, secret) do
    :crypto.mac(:hmac, :sha256, secret, payload)
  end

  @doc """
  Performs constant-time comparison of two binary values.
  
  This prevents timing attacks by ensuring the comparison takes the same
  amount of time regardless of where the first difference occurs.
  
  ## Parameters
  
    * `a` - First binary value
    * `b` - Second binary value
  
  ## Returns
  
    * `true` if the values are equal
    * `false` if the values are different or have different lengths
  """
  def secure_compare(a, b) when is_binary(a) and is_binary(b) do
    if byte_size(a) == byte_size(b) do
      secure_compare_bytes(a, b, 0, 0)
    else
      false
    end
  end

  def secure_compare(_, _), do: false

  # Private function for byte-by-byte comparison
  defp secure_compare_bytes(<<>>, <<>>, _index, result), do: result == 0

  defp secure_compare_bytes(<<a::binary-size(1), rest_a::binary>>, <<b::binary-size(1), rest_b::binary>>, index, result) do
    <<byte_a::integer>> = a
    <<byte_b::integer>> = b
    new_result = result ||| bxor(byte_a, byte_b)
    secure_compare_bytes(rest_a, rest_b, index + 1, new_result)
  end

  @doc """
  Gets the webhook secret from application configuration.
  
  The secret is expected to be configured via Application.get_env/2, which
  is typically set from the GH_REPO_SECRET environment variable in the config files.
  
  ## Returns
  
    * `{:ok, secret}` if the secret is configured
    * `:error` if the secret is not configured or empty
  """
  def get_webhook_secret do
    case Application.get_env(:ci_runners, :github_webhook_secret) do
      nil -> :error
      "" -> :error
      secret when is_binary(secret) -> {:ok, secret}
      _ -> :error
    end
  end
end