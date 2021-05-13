defmodule MafiaInterfaceWeb.Mafia do
  use MafiaInterfaceWeb, :live_view

  alias MafiaEngine.{Game, GameSupervisor, PubSub, Players, Player, Settings}
  alias MafiaInterfaceWeb.{MafiaView, Endpoint}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, default_assigns(socket), temporary_assigns: [messages: []]}
  end

  @impl true
  def handle_params(%{"game_id" => game_id}, _uri, socket) do
    {:noreply, 
      if Map.has_key?(socket.assigns, :my_name) do
        join_game(game_id, socket.assigns.my_name, socket)
      else
        assign(socket, :state, :join)
      end
        |> assign(:game_id, game_id)
    }
  end

  @impl true
  def handle_params(_, _uri, socket) do
    {:noreply, assign(socket, :state, :create)}
  end

  # Render in function of state assign

  @impl true
  def render(%{state: :create} = assigns), do:
    MafiaView.render("home.html", assigns)

  @impl true
  def render(%{state: :join} = assigns), do:
    MafiaView.render("home.html", assigns)

  @impl true
  def render(%{state: :lobby} = assigns), do:
    MafiaView.render("lobby.html", assigns)

  @impl true
  def render(%{state: :playing} = assigns), do:
    MafiaView.render("playing.html", assigns)

  # Terminate

  @impl true
  def terminate(_reason, socket) do
    case socket.assigns.state do
    :lobby ->
      Game.remove_player(socket.assigns.game_id, socket.assigns.my_name)
      PubSub.unsub(socket.assigns.game_id, self())
    :playing ->
      PubSub.unsub_player(socket.assigns.game_id, socket.assigns.my_name)
    _ -> :ok
    end
    :ok
  end

  # Handle event

  @impl true
  def handle_event("join", %{"name" => name}, socket) do
      {:noreply, join_game(socket.assigns.game_id, name, socket)}
  end

  @impl true
  def handle_event("create", %{"name" => name}, socket) do
    game_id = GameSupervisor.start_game()
    MafiaInterface.Admin.start(game_id)
    new_socket = assign(socket, :my_name, name)
    {:noreply, push_patch(new_socket,
      to: Routes.live_path(new_socket, MafiaInterfaceWeb.Mafia, game_id))}
  end

  @impl true
  def handle_event("send_msg", %{"text" => text}, socket) do
    msg = {socket.assigns.my_name, text}
    {can_talk?, to} =
      if socket.assigns.state == :playing do
        Game.talk_to(socket.assigns.game_id, socket.assigns.my_name)
      else
        {true, :everyone}
      end
    if can_talk? do
      Endpoint.broadcast_from(self(), topic(socket.assigns.game_id), "send_msg", %{msg: msg, to: to})
      {:noreply, assign(socket, :messages, [msg | socket.assigns.messages])}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("decrease_timer", %{"phase" => phase}, socket) do
    Game.decrease_timer(socket.assigns.game_id, phase)
    {:noreply, socket}
  end

  @impl true
  def handle_event("increase_timer", %{"phase" => phase}, socket) do
    Game.increase_timer(socket.assigns.game_id, phase)
    {:noreply, socket}
  end

  @impl true
  def handle_event("decrease_role", %{"role" => role}, socket) do
    Game.decrease_role(socket.assigns.game_id, role)
    {:noreply, socket}
  end

  @impl true
  def handle_event("increase_role", %{"role" => role}, socket) do
    Game.increase_role(socket.assigns.game_id, role)
    {:noreply, socket}
  end

  @impl true
  def handle_event("start_game", _values, socket) do
    Game.start_game(socket.assigns.game_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("ready", _values, socket) do
    my_name = socket.assigns.my_name
    ready = Map.update!(socket.assigns.ready, my_name, & not &1)

    if Enum.all?(ready, fn {_, x} -> x end), do:
      Game.start_game(socket.assigns.game_id)

    Endpoint.broadcast_from(self(), topic(socket.assigns.game_id), "ready", my_name)
    {:noreply, assign(socket, :ready, ready)}
  end

  @impl true
  def handle_event("next_phase", _values, socket) do
    Game.next_phase(socket.assigns.game_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("accuse", %{"accused" => accused}, socket) do
    Game.accuse(socket.assigns.game_id, socket.assigns.my_name, accused)
    {:noreply, assign(socket, :my_selection, accused)}
  end

  @impl true
  def handle_event("withdraw", _values, socket) do
    Game.withdraw(socket.assigns.game_id, socket.assigns.my_name)
    {:noreply, assign(socket, :my_selection, nil)}
  end

  @impl true
  def handle_event("vote_innocent", _values, socket) do
    Game.vote_innocent(socket.assigns.game_id, socket.assigns.my_name)
    {:noreply, assign(socket, :my_selection, :innocent)}
  end

  @impl true
  def handle_event("vote_guilty", _values, socket) do
    Game.vote_guilty(socket.assigns.game_id, socket.assigns.my_name)
    {:noreply, assign(socket, :my_selection, :guilty)}
  end

  @impl true
  def handle_event("remove_vote", _values, socket) do
    Game.remove_vote(socket.assigns.game_id, socket.assigns.my_name)
    {:noreply, assign(socket, :my_selection, nil)}
  end

  @impl true
  def handle_event("select", %{"target" => target}, socket) do
    Game.select(socket.assigns.game_id, socket.assigns.my_name, target)
    {:noreply, assign(socket, :my_selection, target)}
  end

  @impl true
  def handle_event("unselect", _values, socket) do
    Game.unselect(socket.assigns.game_id, socket.assigns.my_name)
    {:noreply, assign(socket, :my_selection, nil)}
  end

  @impl true
  def handle_event("toggle_help", _values, socket) do
    {:noreply, assign(socket, :show_help, not socket.assigns.show_help)}
  end

  # Handle info

  @impl true
  def handle_info(%{event: "send_msg", payload: %{msg: msg, to: to}}, socket) do
    if to == :everyone or to == Players.get(socket.assigns.players, socket.assigns.my_name).role do
    {:noreply, assign(socket, :messages, [msg | socket.assigns.messages])}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(%{event: "ready", payload: name}, socket) do
    ready = Map.update!(socket.assigns.ready, name, & not &1)
    {:noreply, assign(socket, :ready, ready)}
  end

  @impl true
  def handle_info(%{event: "new_lobby", payload: game_id}, socket) do
    {:noreply, assign(socket, :new_lobby, game_id)}
  end

  @impl true
  def handle_info({:game_update, update, data}, socket) do
    {:noreply, handle_update(update, data, socket)}
  end

  @impl true
  def handle_info(:tick, socket) do
    timer = Time.diff(socket.assigns.timer_end, Time.utc_now())
    if timer > 0, do:
      Process.send_after(self(), :tick, 1000)
    {:noreply, assign(socket, :timer, timer)}
  end

  def default_assigns(socket), do:
    socket    
    |> assign(:messages, [])
    |> assign(:state, :create)

  def lobby_assigns(socket), do:
    socket
    |> assign(:players, [])
    |> assign(:ready, %{})
    |> assign(:settings, Settings.new())
    |> assign(:state, :lobby) 

  def playing_assigns(socket), do:
    socket
    |> assign(:my_selection, nil)
    |> assign(:accusations, MafiaEngine.Accusations.new(0))
    |> assign(:accused, nil)
    |> assign(:timer, 0)
    |> assign(:show_help, false)
    |> assign(:phase, :afternoon)
    |> assign(:winner, :unknown)
    |> assign(:state, :playing) 

  defp join_game(game_id, name, socket) do
    with true <- GameSupervisor.exists_id?(game_id),
          false <- Game.started?(game_id)
    do
      PubSub.sub_player(game_id, name, self())
      with {:ok, players} <- Game.add_player(game_id, name)
      do
        Endpoint.subscribe(topic(game_id))
        lobby_assigns(socket)
          |> assign(:players, players)
          |> assign(:ready, ready(%{}, players))
          |> assign(:my_name, name)
      else
        {:error, :name_already_taken} ->
          PubSub.unsub_player(game_id, name)
          put_flash(socket, :error, "Name already taken")
      end
    else
      false -> push_patch(put_flash(socket, :error, "Game does not exist"),to: Routes.live_path(socket, MafiaInterfaceWeb.Mafia))
      true -> push_patch(put_flash(socket, :error, "Game is in progress"), to: Routes.live_path(socket, MafiaInterfaceWeb.Mafia))
    end
  end

  # When game ends redirect to the new lobby
  defp handle_update(:state, :shutdown, socket), do:
    push_patch(socket, to: Routes.live_path(socket, MafiaInterfaceWeb.Mafia, socket.assigns.new_lobby))

  # When the game starts initialize the assigns
  defp handle_update(:state, :playing, socket), do:
    playing_assigns(socket)

  # When phase changes reset selection
  defp handle_update(:phase, data, socket), do:
    socket
    |> assign(:my_selection, nil)
    |> assign(:messages, [{:game_msg, humanize(data)} | socket.assigns.messages])
    |> assign(:phase, data)

  # With new players info keep the known role
  defp handle_update(:players, data, socket) do
    players = socket.assigns.players
    updated_players =
      data
      |> Enum.map(&keep_known_role(&1, players))

    socket
    |> assign(:players, updated_players)
    |> assign(:ready, ready(socket.assigns.ready, updated_players))
  end

  defp handle_update(:role, {name, role}, socket) do
    updated_players =
      socket.assigns.players
      |> MafiaEngine.Players.set_role(name, role)

    assign(socket, :players, updated_players)
  end

  defp handle_update(:timer, data, socket) do
    Process.send_after(self(), :tick, 1000)
    timer_end = Time.add(Time.utc_now(), data, :millisecond)
    socket
    |> assign(:timer_end, timer_end)
    |> assign(:timer, div(data,1000))
  end

  defp handle_update(update, data, socket) do
    assign(socket, update, data)
  end

  defp keep_known_role(p, players) do
    case Players.get(players, p.name) do
      :none -> p
      %{role: :unknown} -> p
      %{role: known} -> Player.set_role(p, known)
    end
  end

  defp ready(r, players) do
    ready_map =
      players
      |> Enum.map(fn %{name: name} -> {name, false} end)
      |> Map.new()
    Enum.reduce(r, ready_map, fn {name, x}, acc -> Map.replace(acc, name, x) end)
  end

  defp topic(game_id), do: "game:#{game_id}"

end