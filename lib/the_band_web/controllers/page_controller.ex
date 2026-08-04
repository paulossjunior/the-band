defmodule TheBandWeb.PageController do
  use TheBandWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
