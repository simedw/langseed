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

  def app(assigns) do
    ~H"""
    <header class="bg-base-200 border-b border-base-300">
      <div class="navbar px-4 sm:px-6 lg:px-8">
        <div class="flex-1">
          <a href="/" class="flex items-center gap-2">
            <span class="text-2xl">🌱</span>
            <span class="text-lg font-bold">LangSeed</span>
          </a>
        </div>
        <div class="flex-none">
          <.theme_toggle />
        </div>
      </div>
      <div class="flex gap-1 px-4 pb-2">
        <a href="/" class="btn btn-sm btn-ghost">
          <.icon name="hero-book-open" class="size-4" /> 词汇
        </a>
        <a href="/graph" class="btn btn-sm btn-ghost">
          <.icon name="hero-share" class="size-4" /> 图谱
        </a>
        <a href="/analyze" class="btn btn-sm btn-ghost">
          <.icon name="hero-magnifying-glass" class="size-4" /> 分析
        </a>
        <a href="/texts" class="btn btn-sm btn-ghost">
          <.icon name="hero-document-text" class="size-4" /> 文本
        </a>
        <a href="/practice" class="btn btn-sm btn-ghost">
          <.icon name="hero-academic-cap" class="size-4" /> 练习
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
  def bottom_nav(assigns) do
    ~H"""
    <nav class="btm-nav btm-nav-md bg-base-200 border-t border-base-300">
      <.nav_item href="/" icon="hero-book-open" label="Vocabulary" />
      <.nav_item href="/analyze" icon="hero-magnifying-glass" label="Analyze" />
      <.nav_item href="/practice" icon="hero-academic-cap" label="Practice" />
    </nav>
    """
  end

  defp nav_item(assigns) do
    ~H"""
    <a href={@href} class="text-base-content hover:bg-base-300 transition-colors">
      <.icon name={@icon} class="size-5" />
      <span class="btm-nav-label text-xs">{@label}</span>
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
