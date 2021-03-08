defmodule MafiaInterfaceWeb.Play do
  use MafiaInterfaceWeb, :live_view

  alias MafiaEngine.{Game, GameSupervisor, PubSub, Players, Player}
  alias MafiaInterfaceWeb.PlayView

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"game_id" => game_id}, _uri, socket) do
    {:noreply, join_game(socket, game_id)}
  end

  @impl true
  def handle_params(_, _uri, socket) do
    {:noreply, assign(socket, :state, :matchmaker)}
  end

  @impl true
  def render(%{state: :loading} = assigns), do:
    PlayView.render("loading.html", assigns)

  @impl true
  def render(%{state: :matchmaker} = assigns), do:
    PlayView.render("matchmaker.html", assigns)

  @impl true
  def render(%{state: :game_lobby} = assigns), do:
    PlayView.render("game_lobby.html", assigns)

  @impl true
  def render(%{state: :playing} = assigns), do:
    PlayView.render("playing.html", assigns)

  @impl true
  def terminate(_reason, socket) do
    case socket.assigns.state do
    :game_lobby ->
      Game.remove_player(socket.assigns.game_id, socket.assigns.my_name)
      PubSub.unsub(socket.assigns.game_id, self())
    :playing ->
      PubSub.unsub_player(socket.assigns.game_id, socket.assigns.my_name)
    _ -> :ok
    end
    :ok
  end

  @impl true
  def handle_event("matchmaker_play", _values, socket) do
    game_id = MafiaInterface.Matchmaker.match()
    {:noreply, push_patch(socket,
      to: Routes.live_path(socket, MafiaInterfaceWeb.Play, game_id))}
  end

  @impl true
  def handle_event("matchmaker_create", _values, socket) do
    game_id = GameSupervisor.start_game()
    {:noreply, push_patch(socket,
      to: Routes.live_path(socket, MafiaInterfaceWeb.Play, game_id))}
  end

  @impl true
  def handle_event("matchmaker_join", %{"game_id" => game_id}, socket) do
    {:noreply, push_patch(socket,
      to: Routes.live_path(socket, MafiaInterfaceWeb.Play, game_id))}
  end

  @impl true
  def handle_event("set_name", %{"name" => name}, socket) do
    {:ok, players} = Game.add_player(socket.assigns.game_id, name)
    PubSub.sub_player(socket.assigns.game_id, name, self())
    #fetch again the assigns
    {:noreply,
      socket
      |> assign(:my_name, name)
      |> assign(:players, players)
    }
  end

  @impl true
  def handle_event("start_game", _values, socket) do
    Game.start_game(socket.assigns.game_id)
    {:noreply, socket}
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
  def handle_info({:game_update, update, data}, socket) do
    {:noreply, handle_update(update, data, socket)}
  end

  @impl true
  def handle_info({:player_update, update, data}, socket) do
    {:noreply, handle_update(update, data, socket)}
  end

  @impl true
  def handle_info(:tick, socket) do
    timer = Time.diff(socket.assigns.timer_end, Time.utc_now())
    if timer > 0, do:
      Process.send_after(self(), :tick, 1000)
    {:noreply, assign(socket, :timer, timer)}
  end

  @impl true
  def handle_info(msg, socket) do
    IO.puts "Got a message: #{inspect msg}"
    {:noreply, socket}
  end

  defp join_game(socket, game_id) do
    with true <- GameSupervisor.exists_id?(game_id),
          false <- Game.started?(game_id)
    do
      MafiaEngine.PubSub.sub(game_id, self())
      Game.get_players(game_id)
      game_lobby_assigns(socket, game_id)
    else
      false -> put_flash(assign(socket, :state, :matchmaker), :error, "Game does not exist")
      true -> put_flash(assign(socket, :state, :matchmaker), :error, "Game already started")
    end
  end

  defp game_lobby_assigns(socket, game_id) do
    socket
    |> assign(:players, %{})
    |> assign(:my_name, nil)
    |> assign(:game_id, game_id)
    |> assign(:messages, [])
    |> assign(:state, :game_lobby)
  end

  defp handle_update(:state, :playing, socket) do
    socket
    |> assign(:my_selection, nil)
    |> assign(:accusations, MafiaEngine.Accusations.new(0))
    |> assign(:timer, 0)
    |> assign(:phase, :afternoon)
    |> assign(:state, :playing)
  end

  defp handle_update(:state, :shutdown, socket) do
    push_patch(socket,
      to: Routes.live_path(socket, MafiaInterfaceWeb.Play))
  end

  defp handle_update(:phase, data, socket) do
    socket
    |> assign(:my_selection, nil)
    |> assign(:phase, data)
  end

  defp handle_update(:players, data, socket) do
    players = socket.assigns.players
    updated_players =
      data
      |> Enum.map(&keep_known_role(&1, players))

    assign(socket, :players, updated_players)
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

end
