defmodule ItWhistWeb.PageController do
  use ItWhistWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
