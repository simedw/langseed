defmodule Langseed.LibraryFixtures do
  @moduledoc """
  This module defines test helpers for creating library entities.
  """

  alias Langseed.Library

  def valid_text_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      content: "这是一个测试文本。",
      title: "测试标题"
    })
  end

  def text_fixture(user, attrs \\ %{}) do
    attrs = valid_text_attrs(attrs)
    {:ok, text} = Library.create_text(user, attrs)
    text
  end
end
