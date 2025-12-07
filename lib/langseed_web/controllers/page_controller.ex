defmodule LangseedWeb.PageController do
  use LangseedWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
