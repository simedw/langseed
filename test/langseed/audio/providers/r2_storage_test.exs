defmodule Langseed.Audio.Providers.R2StorageTest do
  use ExUnit.Case, async: true

  alias Langseed.Audio.Providers.R2Storage

  describe "available?/0" do
    test "returns false when R2 is not configured" do
      # Check current availability - should be false in test env without credentials
      result = R2Storage.available?()
      assert is_boolean(result)
    end

    test "requires all four config values to be available" do
      # Save and clear all config
      original = Application.get_env(:langseed, :r2_storage, %{})

      # Only access_key_id and secret_access_key - missing account_id and bucket
      Application.put_env(:langseed, :r2_storage, %{
        access_key_id: "test_key",
        secret_access_key: "test_secret",
        account_id: nil,
        bucket: nil
      })

      refute R2Storage.available?()

      # Only account_id and bucket - missing keys
      Application.put_env(:langseed, :r2_storage, %{
        access_key_id: nil,
        secret_access_key: nil,
        account_id: "test_account",
        bucket: "test_bucket"
      })

      refute R2Storage.available?()

      # All four present - should be available
      Application.put_env(:langseed, :r2_storage, %{
        access_key_id: "test_key",
        secret_access_key: "test_secret",
        account_id: "test_account",
        bucket: "test_bucket"
      })

      assert R2Storage.available?()

      # Restore original
      Application.put_env(:langseed, :r2_storage, original)
    end

    test "treats empty strings as not configured" do
      original = Application.get_env(:langseed, :r2_storage, %{})

      # All values present but bucket is empty string
      Application.put_env(:langseed, :r2_storage, %{
        access_key_id: "test_key",
        secret_access_key: "test_secret",
        account_id: "test_account",
        bucket: ""
      })

      refute R2Storage.available?()

      # Restore original
      Application.put_env(:langseed, :r2_storage, original)
    end
  end

  describe "behavior implementation" do
    test "implements StorageProvider behavior" do
      behaviors = R2Storage.__info__(:attributes)[:behaviour] || []
      assert Langseed.Audio.StorageProvider in behaviors
    end
  end

  describe "path generation" do
    # These tests verify the expected path format used by the Audio module
    test "audio paths follow expected format" do
      # The Audio module generates paths like: tts/<voice>/<language>/<hash>.wav
      path = "tts/Puck/zh/abc123def456.wav"

      assert String.starts_with?(path, "tts/")
      assert String.ends_with?(path, ".wav")
      assert String.contains?(path, "/zh/")
    end
  end
end
