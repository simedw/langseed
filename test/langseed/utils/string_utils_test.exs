defmodule Langseed.Utils.StringUtilsTest do
  use ExUnit.Case, async: true

  alias Langseed.Utils.StringUtils

  describe "ensure_valid_utf8/1" do
    test "returns empty string for nil" do
      assert StringUtils.ensure_valid_utf8(nil) == ""
    end

    test "returns valid UTF-8 string unchanged" do
      input = "Hello 你好 世界"
      assert StringUtils.ensure_valid_utf8(input) == input
    end

    test "handles empty string" do
      assert StringUtils.ensure_valid_utf8("") == ""
    end

    test "handles Chinese characters" do
      input = "这是中文测试"
      assert StringUtils.ensure_valid_utf8(input) == input
    end

    test "handles emojis" do
      input = "Hello 👋🌍"
      assert StringUtils.ensure_valid_utf8(input) == input
    end
  end
end




