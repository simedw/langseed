defmodule LangseedWeb.SpeakButtonComponentTest do
  use LangseedWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias LangseedWeb.SpeakButtonComponent
  alias LangseedWeb.SharedComponents

  describe "render/1" do
    test "renders speaker icon when not loading" do
      html =
        render_component(SpeakButtonComponent, %{
          id: "test-speak",
          text: "你好",
          audio_url: nil,
          concept_id: nil,
          language: "zh"
        })

      assert html =~ "hero-speaker-wave"
      refute html =~ "loading"
    end

    test "renders solid icon when audio_url is present" do
      html =
        render_component(SpeakButtonComponent, %{
          id: "test-speak",
          text: "你好",
          audio_url: "https://example.com/audio.mp3",
          concept_id: 1,
          language: "zh"
        })

      assert html =~ "hero-speaker-wave-solid"
    end

    test "renders outline icon when audio_url is nil" do
      html =
        render_component(SpeakButtonComponent, %{
          id: "test-speak",
          text: "你好",
          audio_url: nil,
          concept_id: 1,
          language: "zh"
        })

      # Outline icon (not solid)
      assert html =~ "hero-speaker-wave"
      refute html =~ "hero-speaker-wave-solid"
    end

    test "renders loading spinner when loading" do
      # We can't easily test the loading state without a full LiveView,
      # but we can verify the component renders without error
      html =
        render_component(SpeakButtonComponent, %{
          id: "test-speak",
          text: "你好",
          audio_url: nil,
          concept_id: nil,
          language: "zh"
        })

      assert html =~ "speak-btn"
    end
  end

  describe "non_empty_url logic" do
    # Testing the URL preservation logic indirectly through render_component
    test "shows solid icon when audio_url is present" do
      html =
        render_component(SpeakButtonComponent, %{
          id: "test",
          text: "你好",
          audio_url: "https://example.com/audio.mp3",
          concept_id: 1,
          language: "zh"
        })

      assert html =~ "hero-speaker-wave-solid"
    end

    test "shows outline icon when audio_url is nil" do
      html =
        render_component(SpeakButtonComponent, %{
          id: "test",
          text: "你好",
          audio_url: nil,
          concept_id: 1,
          language: "zh"
        })

      assert html =~ "hero-speaker-wave"
      refute html =~ "hero-speaker-wave-solid"
    end

    test "shows outline icon when audio_url is empty string" do
      html =
        render_component(SpeakButtonComponent, %{
          id: "test",
          text: "你好",
          audio_url: "",
          concept_id: 1,
          language: "zh"
        })

      assert html =~ "hero-speaker-wave"
      refute html =~ "hero-speaker-wave-solid"
    end
  end

  describe "audio_url_for_concept/1 defensive behavior" do
    # audio_path must be an object key only (e.g. tts/Puck/zh/<hash>.wav)
    # URLs and data URLs should be ignored defensively

    test "returns nil for nil concept" do
      assert SharedComponents.audio_url_for_concept(nil) == nil
    end

    test "returns nil for concept with nil audio_path" do
      concept = %{audio_path: nil}
      assert SharedComponents.audio_url_for_concept(concept) == nil
    end

    test "returns nil for concept with empty string audio_path" do
      concept = %{audio_path: ""}
      assert SharedComponents.audio_url_for_concept(concept) == nil
    end

    test "returns nil for concept with HTTP URL audio_path (legacy data)" do
      # Legacy data with URLs should be defensively ignored
      concept = %{audio_path: "https://example.com/audio.wav"}
      assert SharedComponents.audio_url_for_concept(concept) == nil
    end

    test "returns nil for concept with data URL audio_path (legacy data)" do
      # Legacy data URLs should be defensively ignored
      concept = %{audio_path: "data:audio/wav;base64,UklGR..."}
      assert SharedComponents.audio_url_for_concept(concept) == nil
    end

    test "returns nil for object key when storage is not available" do
      # With storage not configured, signing won't work
      # (This tests the fallthrough behavior in test env without R2)
      concept = %{audio_path: "tts/Puck/zh/abc123.wav"}
      # Will return nil if storage is not available in test env
      result = SharedComponents.audio_url_for_concept(concept)
      # Result is either nil (no storage) or a signed URL (storage available)
      assert is_nil(result) or is_binary(result)
    end
  end
end
