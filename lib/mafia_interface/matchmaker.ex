defmodule MafiaInterface.Matchmaker do
  use GenServer

  alias MafiaEngine.GameSupervisor

  # Client

  def start_link([]) do

    game_id = GameSupervisor.start_game()

    GenServer.start_link(__MODULE__, game_id, name: __MODULE__)
  end

  def match() do
    GenServer.call(__MODULE__, :match)
  end

  # Server (callbacks)

  @impl true
  def init(game_id) do

    MafiaEngine.PubSub.sub(game_id, self())

    {:ok, game_id}
  end

  @impl true
  def handle_call(:match, _from, game_id) do
    game_id = 
      if GameSupervisor.exists_id?(game_id) do
        game_id
      else
        refresh_game_id(game_id)
      end
    {:reply, game_id, game_id}
  end

  @impl true
  def handle_info({:game_update, :state, :playing}, game_id) do
    {:noreply, refresh_game_id(game_id)}
  end

  @impl true
  def handle_info(_, game_id) do
    {:noreply, game_id}
  end

  defp refresh_game_id(old_game_id) do
    MafiaEngine.PubSub.unsub(old_game_id, self())
    
    new_game_id = GameSupervisor.start_game()

    MafiaEngine.PubSub.sub(new_game_id, self())

    new_game_id
  end

end
