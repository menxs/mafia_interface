defmodule MafiaInterface.Admin do
  use GenServer

  alias MafiaEngine.GameSupervisor

  # Client

  def start(game_id) do
    GenServer.start(__MODULE__, game_id)
  end

  # Server (callbacks)

  @impl true
  def init(game_id) do
    MafiaInterfaceWeb.Endpoint.subscribe(topic(game_id))
    MafiaEngine.PubSub.sub(game_id, self())
    {:ok, game_id}
  end

  @impl true
  def handle_info({:game_update, :phase, :game_over}, s) do
    game_id = GameSupervisor.start_game()
    MafiaInterface.Admin.start(game_id)
    MafiaInterfaceWeb.Endpoint.broadcast_from(self(), topic(s), "new_lobby", game_id)
    {:stop, :normal, s}
  end

  @impl true
  def handle_info({:game_update, :state, :shutdown}, s) do
    {:stop, :normal, s}
  end

  @impl true
  def handle_info(_, s) do
    {:noreply, s}
  end

  defp topic(game_id), do: "game:#{game_id}"

end