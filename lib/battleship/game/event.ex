defmodule Battleship.Game.Event do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    {:ok, %{}}
  end

  def game_created, do: GenServer.cast(__MODULE__, :game_created)
  def player_joined, do: GenServer.cast(__MODULE__, :player_joined)
  def game_over, do: GenServer.cast(__MODULE__, :game_over)
  def game_stopped(game_id), do: GenServer.cast(__MODULE__, {:game_stopped, game_id})
  def player_shot, do: GenServer.cast(__MODULE__, :player_shot)

  def handle_cast(event, state) do
    Battleship.Game.EventHandler.handle_event(event)
    {:noreply, state}
  end
end
