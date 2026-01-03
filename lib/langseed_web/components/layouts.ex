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

  attr :practice_ready, :boolean,
    default: false,
    doc: "whether there are practice items ready"

  def app(assigns) do
    ~H"""
    <header class="bg-base-200 border-b border-base-300">
      <div class="navbar px-4 sm:px-6 lg:px-8">
        <div class="flex-1">
          <a href="/vocabulary" class="flex items-center gap-2">
            <span class="text-2xl">🌱</span>
            <span class="text-lg font-bold">LangSeed</span>
          </a>
        </div>
        <div class="flex-none flex items-center gap-2">
          <.language_selector current_scope={@current_scope} />
          <.theme_toggle />
          <.audio_toggle />
        </div>
      </div>
      <div class="flex gap-1 px-4 pb-2">
        <a href="/vocabulary" class="btn btn-sm btn-ghost">
          <.icon name="hero-book-open" class="size-4" /> {gettext("Vocabulary")}
        </a>
        <a href="/graph" class="btn btn-sm btn-ghost">
          <.icon name="hero-share" class="size-4" /> {gettext("Graph")}
        </a>
        <a href="/analyze" class="btn btn-sm btn-ghost">
          <.icon name="hero-magnifying-glass" class="size-4" /> {gettext("Analyze")}
        </a>
        <a href="/texts" class="btn btn-sm btn-ghost">
          <.icon name="hero-document-text" class="size-4" /> {gettext("Texts")}
        </a>
        <a href="/practice" class="btn btn-sm btn-ghost relative group">
          <.icon
            name="hero-academic-cap"
            class={["size-4", @practice_ready && "animate-pulse text-primary"]}
          />
          <span class={[@practice_ready && "animate-pulse text-primary font-semibold"]}>
            {gettext("Practice")}
          </span>
        </a>
      </div>
    </header>

    <main class="mx-auto max-w-4xl">
      {@inner_content}
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Mobile-friendly bottom navigation bar.
  """
  attr :practice_ready, :boolean, default: false

  def bottom_nav(assigns) do
    ~H"""
    <nav class="btm-nav btm-nav-md bg-base-200 border-t border-base-300">
      <.nav_item href="/vocabulary" icon="hero-book-open" label="Vocabulary" />
      <.nav_item href="/analyze" icon="hero-magnifying-glass" label="Analyze" />
      <.nav_item
        href="/practice"
        icon="hero-academic-cap"
        label="Practice"
        indicator={@practice_ready}
      />
    </nav>
    """
  end

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :indicator, :boolean, default: false

  defp nav_item(assigns) do
    ~H"""
    <a href={@href} class="text-base-content hover:bg-base-300 transition-colors relative">
      <.icon name={@icon} class={["size-5", @indicator && "animate-pulse text-primary"]} />
      <span class={["btm-nav-label text-xs", @indicator && "animate-pulse text-primary font-semibold"]}>
        {@label}
      </span>
    </a>
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
  Toggle for audio autoplay. When disabled, audio won't auto-play after quiz answers.
  The preference is stored in localStorage.
  """
  def audio_toggle(assigns) do
    ~H"""
    <button
      id="audio-autoplay-toggle"
      phx-hook="AudioAutoplaySync"
      class="btn btn-ghost btn-circle btn-xs opacity-60 hover:opacity-100"
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
