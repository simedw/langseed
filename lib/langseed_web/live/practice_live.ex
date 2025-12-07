defmodule LangseedWeb.PracticeLive do
  use LangseedWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Practice")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen pb-20 flex items-center justify-center">
      <div class="text-center p-8">
        <div class="text-6xl mb-4">🚧</div>
        <h1 class="text-2xl font-bold mb-2">练习 Practice</h1>
        <p class="text-lg opacity-70">Coming Soon</p>
        <p class="text-sm opacity-50 mt-4">
          Practice exercises will help you reinforce your vocabulary.
        </p>
      </div>
    </div>
    """
  end
end
