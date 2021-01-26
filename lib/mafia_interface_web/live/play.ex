defmodule MafiaInterfaceWeb.Play do
  use MafiaInterfaceWeb, :live_view

  alias MafiaEngine.{Game, GameSupervisor, PubSub}
  alias MafiaInterfaceWeb.PlayView

  @impl true
  def mount(params, _session, socket) do
    if connected?(socket) do
      {:ok, init_view(params, socket)}
    else
      {:ok, assign(socket, :state, :loading)}
    end
  end

  @impl true
  def render(%{state: :loading} = assigns), do:
    PlayView.render("loading.html", assigns)

  @impl true
  def render(%{state: :waiting} = assigns), do:
    PlayView.render("waiting.html", assigns)

  @impl true
  def render(%{state: {:playing, _phase}} = assigns), do:
    PlayView.render("playing.html", assigns)

  @impl true
  def terminate(_reason, socket) do
    case socket.assigns.state do
    :waiting ->
      Game.remove_player(socket.assigns.game_id, socket.assigns.name)
      PubSub.unsub(socket.assigns.game_id, self())
    {:playing, _} ->
      PubSub.unsub_player(socket.assigns.game_id, socket.assigns.name)
    end
    :ok
  end

  @impl true
  def handle_event("set_name", %{"name" => name}, socket) do
    {:ok, players} = Game.add_player(socket.assigns.game_id, name)
    PubSub.sub_player(socket.assigns.game_id, name, self())
    #fetch again the assigns
    {:noreply,
      socket
      |> assign(:name, name)
      |> assign(:role, :tbd)
      |> assign(:players, players)
      |> assign(:selected, nil)
    }
  end

  @impl true
  def handle_event("start_game", _values, socket) do
    Game.start_game(socket.assigns.game_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("accuse", %{"accused" => accused}, socket) do
    Game.accuse(socket.assigns.game_id, socket.assigns.name, accused)
    {:noreply, assign(socket, :selected, accused)}
  end

  @impl true
  def handle_event("withdraw", _values, socket) do
    Game.withdraw(socket.assigns.game_id, socket.assigns.name)
    {:noreply, assign(socket, :selected, nil)}
  end

  @impl true
  def handle_event("vote_innocent", _values, socket) do
    Game.vote_innocent(socket.assigns.game_id, socket.assigns.name)
    {:noreply, assign(socket, :selected, :innocent)}
  end

  @impl true
  def handle_event("vote_guilty", _values, socket) do
    Game.vote_guilty(socket.assigns.game_id, socket.assigns.name)
    {:noreply, assign(socket, :selected, :guilty)}
  end

  @impl true
  def handle_event("remove_vote", _values, socket) do
    Game.remove_vote(socket.assigns.game_id, socket.assigns.name)
    {:noreply, assign(socket, :selected, nil)}
  end

  @impl true
  def handle_event("select", %{"target" => target}, socket) do
    Game.select(socket.assigns.game_id, socket.assigns.name, target)
    {:noreply, assign(socket, :selected, target)}
  end

  @impl true
  def handle_event("unselect", _values, socket) do
    Game.unselect(socket.assigns.game_id, socket.assigns.name)
    {:noreply, assign(socket, :selected, nil)}
  end

  @impl true
  def handle_info({:game_update, update, data}, socket) do
    {:noreply, handle_update(update, data, socket)}
  end

  @impl true
  def handle_info({:player_update, update, data}, socket) do
    {:noreply, handle_update(update, data, socket)}
  end

  @impl true
  def handle_info(msg, socket) do
    IO.puts "Got a message: #{inspect msg}"
    {:noreply, socket}
  end

  #If creating game
  defp init_view(%{"game_id" => ""}, socket) do
    game_id = "????"
    #{:ok, _pid} = 
      GameSupervisor.start_game(game_id)
    PubSub.sub(game_id, self())
    fresh_assigns(socket, game_id)
  end

  #If joining game
  defp init_view(%{"game_id" => game_id}, socket) do
    PubSub.sub(game_id, self())
    Game.get_players(game_id)
    fresh_assigns(socket, game_id)
  end

  defp init_view(params, socket), do:
    init_view(Map.put(params, "game_id", ""), socket)

  defp fresh_assigns(socket, game_id) do
    socket
    |> assign(:game_id, game_id)
    |> assign(:name, nil)#nil
    |> assign(:players, [])
    |> assign(:accusations, MafiaEngine.Accusations.new(0))
    |> assign(:state, :waiting)#:waiting
    # |> assign(:role, :tbd)#
    # |> assign(:selected, nil)#
  end

  defp handle_update(:state, data, socket) do
    socket
    |> assign(:selected, nil)
    |> assign(:state, data)
  end

  defp handle_update(update, data, socket) do
    assign(socket, update, data)
  end

end
