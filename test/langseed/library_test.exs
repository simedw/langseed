defmodule Langseed.LibraryTest do
  use Langseed.DataCase

  alias Langseed.Library
  alias Langseed.Library.Text

  import Langseed.AccountsFixtures
  import Langseed.LibraryFixtures

  describe "list_texts/1" do
    test "returns all texts for a user" do
      user = user_fixture()
      text = text_fixture(user)

      texts = Library.list_texts(user)
      assert length(texts) == 1
      assert hd(texts).id == text.id
    end

    test "returns empty list for nil user" do
      assert Library.list_texts(nil) == []
    end

    test "does not return other users' texts" do
      user1 = user_fixture()
      user2 = user_fixture()
      text_fixture(user1)

      assert Library.list_texts(user2) == []
    end
  end

  describe "list_recent_texts/2" do
    test "returns limited number of texts" do
      user = user_fixture()
      text_fixture(user, %{content: "Text 1"})
      text_fixture(user, %{content: "Text 2"})
      text_fixture(user, %{content: "Text 3"})

      texts = Library.list_recent_texts(user, 2)
      assert length(texts) == 2
    end

    test "returns empty list for nil user" do
      assert Library.list_recent_texts(nil, 5) == []
    end
  end

  describe "get_text!/2" do
    test "returns the text for the given user and id" do
      user = user_fixture()
      text = text_fixture(user)

      fetched = Library.get_text!(user, text.id)
      assert fetched.id == text.id
    end

    test "raises for nil user" do
      assert_raise RuntimeError, "Authentication required", fn ->
        Library.get_text!(nil, 1)
      end
    end
  end

  describe "get_text/2" do
    test "returns the text for the given id" do
      user = user_fixture()
      text = text_fixture(user)

      fetched = Library.get_text(user, text.id)
      assert fetched.id == text.id
    end

    test "returns nil for non-existent text" do
      user = user_fixture()
      assert Library.get_text(user, 999) == nil
    end

    test "returns nil for nil user" do
      assert Library.get_text(nil, 1) == nil
    end
  end

  describe "create_text/2" do
    test "creates a text with valid data" do
      user = user_fixture()
      attrs = valid_text_attrs()

      assert {:ok, %Text{} = text} = Library.create_text(user, attrs)
      assert text.content == "这是一个测试文本。"
    end

    test "auto-generates title from content when not provided" do
      user = user_fixture()
      attrs = %{content: "这是一个很长的文本内容，应该被截断用作标题。"}

      assert {:ok, %Text{} = text} = Library.create_text(user, attrs)
      # Title is first 20 chars + "..."
      assert String.starts_with?(text.title, "这是一个很长的文本内容")
      assert String.ends_with?(text.title, "...")
    end

    test "returns error for nil user" do
      attrs = valid_text_attrs()
      assert {:error, "Authentication required"} = Library.create_text(nil, attrs)
    end

    test "returns error for invalid data" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Library.create_text(user, %{})
    end
  end

  describe "update_text/2" do
    test "updates the text with valid data" do
      user = user_fixture()
      text = text_fixture(user)

      assert {:ok, updated} = Library.update_text(text, %{title: "Updated Title"})
      assert updated.title == "Updated Title"
    end
  end

  describe "delete_text/1" do
    test "deletes the text" do
      user = user_fixture()
      text = text_fixture(user)

      assert {:ok, %Text{}} = Library.delete_text(text)
      assert Library.list_texts(user) == []
    end
  end
end
