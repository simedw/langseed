defmodule LangseedWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use LangseedWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @languages [
    {"zh", "中文", "🇨🇳"},
    {"ja", "日本語", "🇯🇵"},
    {"sv", "Svenska", "🇸🇪"},
    {"en", "English", "🇬🇧"}
  ]

  def languages, do: @languages

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :practice_count, :integer,
    default: 0,
    doc: "number of practice items ready"

  attr :current_path, :string,
    default: "/",
    doc: "current page path for active tab indication"

  attr :word_import_count, :integer,
    default: 0,
    doc: "number of words being imported"

  attr :word_import_processing, :string,
    default: nil,
    doc: "the word currently being processed"

  attr :page_title, :string,
    default: nil,
    doc: "page title shown on mobile header"

  slot :header_stats, doc: "optional stats shown in mobile header center"

  def app(assigns) do
    ~H"""
    <%!-- Desktop header --%>
    <header class="hidden md:flex navbar bg-base-200 border-b border-base-300 px-4 sm:px-6 lg:px-8">
      <div class="navbar-start">
        <a href="/vocabulary" class="flex items-center gap-2">
          <span class="text-2xl">🌱</span>
          <span class="text-lg font-bold">LangSeed</span>
        </a>
      </div>

      <div class="navbar-center">
        <ul class="menu menu-horizontal gap-1">
          <li>
            <a href="/vocabulary" class={["btn btn-ghost btn-sm", String.starts_with?(@current_path, "/vocabulary") && "btn-active"]}>
              <.icon name="hero-book-open" class="size-4" /> {gettext("Vocabulary")}
            </a>
          </li>
          <li>
            <a href="/graph" class={["btn btn-ghost btn-sm", String.starts_with?(@current_path, "/graph") && "btn-active"]}>
              <.icon name="hero-share" class="size-4" /> {gettext("Graph")}
            </a>
          </li>
          <li>
            <a href="/analyze" class={["btn btn-ghost btn-sm", String.starts_with?(@current_path, "/analyze") && "btn-active"]}>
              <.icon name="hero-magnifying-glass" class="size-4" /> {gettext("Analyze")}
            </a>
          </li>
          <li>
            <a href="/texts" class={["btn btn-ghost btn-sm", String.starts_with?(@current_path, "/texts") && "btn-active"]}>
              <.icon name="hero-document-text" class="size-4" /> {gettext("Texts")}
            </a>
          </li>
          <li>
            <a href="/practice" class={["btn btn-ghost btn-sm", String.starts_with?(@current_path, "/practice") && "btn-active"]}>
              <span class="relative inline-flex">
                <.icon name="hero-academic-cap" class="size-4" />
                <span :if={@practice_count > 0} class="absolute -top-1.5 -right-2.5 badge badge-primary badge-xs min-w-[1.25rem]">
                  {if @practice_count > 99, do: "99+", else: @practice_count}
                </span>
              </span>
              <span>{gettext("Practice")}</span>
            </a>
          </li>
        </ul>
      </div>

      <div class="navbar-end flex items-center gap-2">
        <.word_import_indicator count={@word_import_count} processing={@word_import_processing} />
        <.language_selector current_scope={@current_scope} />
        <.user_dropdown current_scope={@current_scope} />
      </div>
    </header>

    <%!-- Mobile header --%>
    <header class="md:hidden flex items-center justify-between bg-base-200 border-b border-base-300 px-4 py-2">
      <div class="flex items-center gap-2 min-w-0">
        <a href="/vocabulary" class="text-xl">🌱</a>
        <span :if={@page_title} class="font-semibold truncate">{@page_title}</span>
      </div>

      <div :if={@header_stats != []} class="flex-1 flex justify-center text-sm text-base-content/70">
        {render_slot(@header_stats)}
      </div>

      <div class="flex items-center gap-1">
        <.language_selector current_scope={@current_scope} />
        <.user_dropdown current_scope={@current_scope} />
      </div>
    </header>

    <main class="mx-auto max-w-4xl pb-16 md:pb-0">
      {@inner_content}
    </main>

    <.flash_group flash={@flash} />

    <div class="md:hidden">
      <.bottom_nav practice_count={@practice_count} current_path={@current_path} />
    </div>
    """
  end

  @doc """
  Mobile-friendly bottom navigation bar.
  """
  attr :practice_count, :integer, default: 0
  attr :current_path, :string, default: "/"

  def bottom_nav(assigns) do
    ~H"""
    <nav class="fixed bottom-0 left-0 right-0 bg-base-200/95 backdrop-blur border-t border-base-300 px-6 py-2 flex justify-around items-center">
      <a
        href="/vocabulary"
        class={[
          "flex flex-col items-center gap-0.5 py-1 px-3 transition-colors",
          if(String.starts_with?(@current_path, "/vocabulary"), do: "text-primary", else: "text-base-content/70 hover:text-base-content")
        ]}
      >
        <.icon name="hero-book-open" class="size-5" />
        <span class="text-[10px]">{gettext("Vocabulary")}</span>
      </a>
      <a
        href="/analyze"
        class={[
          "flex flex-col items-center gap-0.5 py-1 px-3 transition-colors",
          if(String.starts_with?(@current_path, "/analyze"), do: "text-primary", else: "text-base-content/70 hover:text-base-content")
        ]}
      >
        <.icon name="hero-magnifying-glass" class="size-5" />
        <span class="text-[10px]">{gettext("Analyze")}</span>
      </a>
      <a
        href="/practice"
        class={[
          "flex flex-col items-center gap-0.5 py-1 px-3 transition-colors",
          if(String.starts_with?(@current_path, "/practice"), do: "text-primary", else: "text-base-content/70 hover:text-base-content")
        ]}
      >
        <span class="relative inline-flex">
          <.icon name="hero-academic-cap" class="size-5" />
          <span :if={@practice_count > 0} class="absolute -top-1 -right-2 badge badge-primary badge-xs text-[8px] min-w-[1rem] h-4">
            {if @practice_count > 99, do: "99+", else: @practice_count}
          </span>
        </span>
        <span class="text-[10px]">{gettext("Practice")}</span>
      </a>
    </nav>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Language selector dropdown for switching between languages.
  """
  attr :current_scope, :map, default: nil

  def language_selector(assigns) do
    current_language = if assigns.current_scope, do: assigns.current_scope.language, else: "zh"

    {_code, label, flag} =
      Enum.find(@languages, {"zh", "中文", "🇨🇳"}, fn {code, _, _} -> code == current_language end)

    assigns =
      assigns
      |> assign(:current_language, current_language)
      |> assign(:current_label, label)
      |> assign(:current_flag, flag)
      |> assign(:languages, @languages)

    ~H"""
    <div class="dropdown dropdown-end">
      <div tabindex="0" role="button" class="btn btn-ghost btn-sm gap-1">
        <span class="text-base">{@current_flag}</span>
        <span class="hidden sm:inline text-xs">{@current_label}</span>
        <.icon name="hero-chevron-down-micro" class="size-3" />
      </div>
      <ul
        tabindex="0"
        class="dropdown-content menu bg-base-100 rounded-box z-50 w-40 p-2 shadow-lg border border-base-300"
      >
        <%= for {code, label, flag} <- @languages do %>
          <li>
            <.link
              href={~p"/language?language=#{code}"}
              method="put"
              class={["flex items-center gap-2", code == @current_language && "active"]}
            >
              <span class="text-base">{flag}</span>
              <span>{label}</span>
            </.link>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end

  @doc """
  Language menu for use inside dropdowns (shows all options inline).
  """
  attr :current_scope, :map, default: nil

  def language_menu(assigns) do
    current_language = if assigns.current_scope, do: assigns.current_scope.language, else: "zh"

    assigns =
      assigns
      |> assign(:current_language, current_language)
      |> assign(:languages, @languages)

    ~H"""
    <div class="flex flex-wrap gap-1">
      <%= for {code, label, flag} <- @languages do %>
        <.link
          href={~p"/language?language=#{code}"}
          method="put"
          class={[
            "btn btn-sm gap-1",
            if(code == @current_language, do: "btn-primary", else: "btn-ghost")
          ]}
        >
          <span>{flag}</span>
          <span class="text-xs">{label}</span>
        </.link>
      <% end %>
    </div>
    """
  end

  @doc """
  Toggle for audio autoplay. When disabled, audio won't auto-play after quiz answers.
  The preference is stored in localStorage.
  """
  def audio_toggle(assigns) do
    ~H"""
    <button
      id="audio-autoplay-toggle"
      phx-hook="AudioAutoplaySync"
      class="btn btn-ghost btn-sm gap-1"
      phx-click={JS.dispatch("phx:toggle-audio-autoplay")}
      title={gettext("Toggle audio autoplay")}
    >
      <.icon
        name="hero-speaker-wave-micro"
        class="size-4 [[data-audio-autoplay=false]_&]:hidden"
      />
      <.icon
        name="hero-speaker-x-mark-micro"
        class="size-4 hidden [[data-audio-autoplay=false]_&]:block"
      />
    </button>
    """
  end

  @doc """
  User dropdown with account info and preferences.
  """
  attr :current_scope, :map, default: nil

  def user_dropdown(assigns) do
    ~H"""
    <div class="dropdown dropdown-end">
      <div tabindex="0" role="button" class="btn btn-ghost btn-circle">
        <.icon name="hero-user-circle" class="size-6" />
      </div>
      <div
        tabindex="0"
        class="dropdown-content bg-base-100 rounded-box z-50 w-64 p-4 shadow-lg border border-base-300 mt-2"
      >
        <%= if @current_scope && @current_scope.user do %>
          <div class="mb-3 pb-3 border-b border-base-300">
            <p class="text-sm font-medium truncate">{@current_scope.user.email}</p>
          </div>

          <div class="flex items-center justify-between mb-3">
            <span class="text-sm">{gettext("Theme")}</span>
            <.theme_toggle />
          </div>

          <div class="flex items-center justify-between mb-3">
            <span class="text-sm">{gettext("Audio autoplay")}</span>
            <.audio_toggle />
          </div>

          <div class="mb-3 pb-3 border-b border-base-300">
            <span class="text-sm text-base-content/70 mb-2 block">{gettext("Language")}</span>
            <.language_menu current_scope={@current_scope} />
          </div>

          <.link href={~p"/users/log-out"} method="delete" class="btn btn-ghost btn-sm w-full justify-start">
            <.icon name="hero-arrow-right-on-rectangle" class="size-4" />
            {gettext("Log out")}
          </.link>
        <% else %>
          <.link href={~p"/auth/google"} class="btn btn-primary btn-sm w-full">
            Sign in with Google
          </.link>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Shows word import progress indicator when words are being imported.
  """
  attr :count, :integer, default: 0
  attr :processing, :string, default: nil

  def word_import_indicator(assigns) do
    ~H"""
    <div
      :if={@count > 0}
      class="flex items-center gap-2 px-3 py-1 bg-primary/10 rounded-full text-sm"
      title={gettext("Importing words...")}
    >
      <.icon name="hero-arrow-path" class="size-4 animate-spin text-primary" />
      <span class="font-medium">
        <%= if @processing do %>
          <span class="text-primary">{@processing}</span>
        <% end %>
        <span class="opacity-70">
          ({@count})
        </span>
      </span>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
