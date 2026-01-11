defmodule LangseedWeb.Plugs.SetLocale do
  @moduledoc """
  Plug to set the Gettext locale based on the user's selected language.
  """

  @language_to_locale %{
    "zh" => "zh",
    "ja" => "ja",
    "sv" => "sv",
    "en" => "en"
  }

  def init(opts), do: opts

  def call(conn, _opts) do
    locale = get_locale_from_scope(conn)
    Gettext.put_locale(LangseedWeb.Gettext, locale)
    conn
  end

  defp get_locale_from_scope(conn) do
    case conn.assigns[:current_scope] do
      %{language: language} -> Map.get(@language_to_locale, language, "en")
      _ -> "en"
    end
  end
end
