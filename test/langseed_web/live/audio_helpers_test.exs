defmodule LangseedWeb.AudioHelpersTest do
  use Langseed.DataCase, async: true

  alias LangseedWeb.AudioHelpers

  # Helper to create a proper socket for testing
  defp make_socket(assigns \\ %{}) do
    %Phoenix.LiveView.Socket{
      assigns: Map.merge(%{__changed__: %{}}, assigns)
    }
  end

  describe "handle_generate_speak_audio/5" do
    test "returns {:noreply, socket}" do
      socket = make_socket()

      result =
        AudioHelpers.handle_generate_speak_audio(
          socket,
          "component-id",
          "你好",
          nil,
          "zh"
        )

      assert {:noreply, ^socket} = result
    end
  end

  describe "handle_speak_audio_result/3" do
    test "returns {:noreply, socket} on success" do
      socket = make_socket(%{current_concept: nil})

      result =
        AudioHelpers.handle_speak_audio_result(
          socket,
          "component-id",
          {:ok, "https://example.com/audio.mp3"}
        )

      assert {:noreply, _socket} = result
    end

    test "returns {:noreply, socket} on error" do
      socket = make_socket()

      result =
        AudioHelpers.handle_speak_audio_result(
          socket,
          "component-id",
          {:error, :not_configured}
        )

      assert {:noreply, _socket} = result
    end

    test "returns {:noreply, socket} for nil result" do
      socket = make_socket()

      result =
        AudioHelpers.handle_speak_audio_result(
          socket,
          "component-id",
          {:ok, nil}
        )

      assert {:noreply, _socket} = result
    end
  end
end
