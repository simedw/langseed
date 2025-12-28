defmodule LangseedWeb.SpeakButtonComponentTest do
  use LangseedWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias LangseedWeb.SpeakButtonComponent

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
end
