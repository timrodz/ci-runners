defmodule CiRunners.Github.WebhookVerifierTest do
  use ExUnit.Case, async: true

  alias CiRunners.Github.WebhookVerifier

  describe "verify_signature/3" do
    test "returns true for valid signature" do
      payload = ~s({"action":"opened","number":1})
      secret = "my_secret_key"
      
      # Compute expected signature
      expected_signature = :crypto.mac(:hmac, :sha256, secret, payload)
      signature_header = "sha256=" <> Base.encode16(expected_signature, case: :lower)
      
      assert WebhookVerifier.verify_signature(signature_header, payload, secret)
    end

    test "returns false for invalid signature" do
      payload = ~s({"action":"opened","number":1})
      secret = "my_secret_key"
      invalid_signature = "sha256=invalid_signature_hash"
      
      refute WebhookVerifier.verify_signature(invalid_signature, payload, secret)
    end

    test "returns false for wrong secret" do
      payload = ~s({"action":"opened","number":1})
      secret = "my_secret_key"
      wrong_secret = "wrong_secret"
      
      # Generate signature with correct secret
      expected_signature = :crypto.mac(:hmac, :sha256, secret, payload)
      signature_header = "sha256=" <> Base.encode16(expected_signature, case: :lower)
      
      # Verify with wrong secret
      refute WebhookVerifier.verify_signature(signature_header, payload, wrong_secret)
    end

    test "returns false for malformed signature header" do
      payload = ~s({"action":"opened","number":1})
      secret = "my_secret_key"
      
      refute WebhookVerifier.verify_signature("invalid_format", payload, secret)
      refute WebhookVerifier.verify_signature("sha256=", payload, secret)
      refute WebhookVerifier.verify_signature("sha1=abc123", payload, secret)
      refute WebhookVerifier.verify_signature("", payload, secret)
    end

    test "returns false for non-string arguments" do
      refute WebhookVerifier.verify_signature(nil, "payload", "secret")
      refute WebhookVerifier.verify_signature("signature", nil, "secret")
      refute WebhookVerifier.verify_signature("signature", "payload", nil)
      refute WebhookVerifier.verify_signature(123, "payload", "secret")
    end

    test "handles empty payload" do
      payload = ""
      secret = "my_secret_key"
      
      expected_signature = :crypto.mac(:hmac, :sha256, secret, payload)
      signature_header = "sha256=" <> Base.encode16(expected_signature, case: :lower)
      
      assert WebhookVerifier.verify_signature(signature_header, payload, secret)
    end

    test "handles unicode characters in payload" do
      payload = ~s({"message":"Hello 世界! 🌍"})
      secret = "my_secret_key"
      
      expected_signature = :crypto.mac(:hmac, :sha256, secret, payload)
      signature_header = "sha256=" <> Base.encode16(expected_signature, case: :lower)
      
      assert WebhookVerifier.verify_signature(signature_header, payload, secret)
    end

    test "handles case sensitivity in signature" do
      payload = ~s({"action":"opened","number":1})
      secret = "my_secret_key"
      
      expected_signature = :crypto.mac(:hmac, :sha256, secret, payload)
      
      # Test lowercase
      signature_lower = "sha256=" <> Base.encode16(expected_signature, case: :lower)
      assert WebhookVerifier.verify_signature(signature_lower, payload, secret)
      
      # Test uppercase
      signature_upper = "sha256=" <> Base.encode16(expected_signature, case: :upper)
      assert WebhookVerifier.verify_signature(signature_upper, payload, secret)
    end
  end

  describe "parse_signature/1" do
    test "parses valid sha256 signature" do
      signature = "sha256=abc123def456"
      expected = Base.decode16!("abc123def456", case: :mixed)
      
      assert {:ok, expected} == WebhookVerifier.parse_signature(signature)
    end

    test "parses signature with mixed case hex" do
      signature = "sha256=AbC123DeF456"
      expected = Base.decode16!("AbC123DeF456", case: :mixed)
      
      assert {:ok, expected} == WebhookVerifier.parse_signature(signature)
    end

    test "returns error for invalid format" do
      assert :error == WebhookVerifier.parse_signature("invalid")
      assert :error == WebhookVerifier.parse_signature("sha1=abc123")
      assert :error == WebhookVerifier.parse_signature("sha256=")
      assert :error == WebhookVerifier.parse_signature("")
      assert :error == WebhookVerifier.parse_signature("sha256")
    end

    test "returns error for invalid hex characters" do
      assert :error == WebhookVerifier.parse_signature("sha256=xyz123")
      assert :error == WebhookVerifier.parse_signature("sha256=abc!@#")
    end
  end

  describe "compute_signature/2" do
    test "computes correct HMAC-SHA256 signature" do
      payload = "test payload"
      secret = "test secret"
      
      expected = :crypto.mac(:hmac, :sha256, secret, payload)
      result = WebhookVerifier.compute_signature(payload, secret)
      
      assert expected == result
    end

    test "produces different signatures for different payloads" do
      secret = "test secret"
      payload1 = "payload one"
      payload2 = "payload two"
      
      sig1 = WebhookVerifier.compute_signature(payload1, secret)
      sig2 = WebhookVerifier.compute_signature(payload2, secret)
      
      refute sig1 == sig2
    end

    test "produces different signatures for different secrets" do
      payload = "test payload"
      secret1 = "secret one"
      secret2 = "secret two"
      
      sig1 = WebhookVerifier.compute_signature(payload, secret1)
      sig2 = WebhookVerifier.compute_signature(payload, secret2)
      
      refute sig1 == sig2
    end
  end

  describe "secure_compare/2" do
    test "returns true for identical binaries" do
      a = "hello world"
      b = "hello world"
      
      assert WebhookVerifier.secure_compare(a, b)
    end

    test "returns false for different binaries" do
      a = "hello world"
      b = "hello universe"
      
      refute WebhookVerifier.secure_compare(a, b)
    end

    test "returns false for different lengths" do
      a = "short"
      b = "much longer string"
      
      refute WebhookVerifier.secure_compare(a, b)
    end

    test "returns false for one character difference" do
      a = "hello world"
      b = "hello worlx"
      
      refute WebhookVerifier.secure_compare(a, b)
    end

    test "returns true for empty binaries" do
      assert WebhookVerifier.secure_compare("", "")
    end

    test "returns false for non-binary arguments" do
      refute WebhookVerifier.secure_compare(nil, "string")
      refute WebhookVerifier.secure_compare("string", nil)
      refute WebhookVerifier.secure_compare(123, "string")
      refute WebhookVerifier.secure_compare("string", 456)
    end

    test "handles binary data correctly" do
      # Test with actual binary data (not just strings)
      a = <<1, 2, 3, 4, 5>>
      b = <<1, 2, 3, 4, 5>>
      c = <<1, 2, 3, 4, 6>>
      
      assert WebhookVerifier.secure_compare(a, b)
      refute WebhookVerifier.secure_compare(a, c)
    end
  end

  describe "get_webhook_secret/0" do
    test "returns secret from application config" do
      # Set application config
      Application.put_env(:ci_runners, :github_webhook_secret, "test_secret_from_config")
      
      assert {:ok, "test_secret_from_config"} == WebhookVerifier.get_webhook_secret()
      
      # Clean up
      Application.delete_env(:ci_runners, :github_webhook_secret)
    end

    test "returns error when no secret is configured" do
      # Clean up any existing configuration
      Application.delete_env(:ci_runners, :github_webhook_secret)
      
      assert :error == WebhookVerifier.get_webhook_secret()
    end

    test "returns error for empty string secret" do
      Application.put_env(:ci_runners, :github_webhook_secret, "")
      
      assert :error == WebhookVerifier.get_webhook_secret()
      
      # Clean up
      Application.delete_env(:ci_runners, :github_webhook_secret)
    end

    test "returns error for nil secret" do
      Application.put_env(:ci_runners, :github_webhook_secret, nil)
      
      assert :error == WebhookVerifier.get_webhook_secret()
      
      # Clean up
      Application.delete_env(:ci_runners, :github_webhook_secret)
    end

    test "returns error for non-string config values" do
      Application.put_env(:ci_runners, :github_webhook_secret, 123)
      
      assert :error == WebhookVerifier.get_webhook_secret()
      
      # Clean up
      Application.delete_env(:ci_runners, :github_webhook_secret)
    end
  end
end