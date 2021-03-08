defmodule MafiaInterfaceWeb.PageLive do
  use MafiaInterfaceWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_event("play", _, socket) do
    {:noreply, push_redirect(
      socket,
      to: Routes.live_path(socket, MafiaInterfaceWeb.Play))
    }
  end

end
