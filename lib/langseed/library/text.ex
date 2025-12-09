defmodule Langseed.Library.Text do
  @moduledoc """
  Schema for user-saved texts used for reading and vocabulary extraction.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "texts" do
    field :title, :string
    field :content, :string
    # Language code (e.g., "zh", "ja", "ko", "en", "sv")
    field :language, :string, default: "zh"

    belongs_to :user, Langseed.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(text, attrs) do
    text
    |> cast(attrs, [:title, :content, :language, :user_id])
    |> validate_required([:content])
    |> maybe_generate_title()
  end

  defp maybe_generate_title(changeset) do
    case get_field(changeset, :title) do
      nil ->
        content = get_field(changeset, :content) || ""
        title = generate_title(content)
        put_change(changeset, :title, title)

      "" ->
        content = get_field(changeset, :content) || ""
        title = generate_title(content)
        put_change(changeset, :title, title)

      _ ->
        changeset
    end
  end

  defp generate_title(content) do
    content
    |> String.trim()
    |> String.slice(0, 20)
    |> then(fn title ->
      if String.length(content) > 20, do: title <> "...", else: title
    end)
    |> case do
      "" -> "无标题"
      title -> title
    end
  end
end
