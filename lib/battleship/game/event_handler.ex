defmodule Battleship.Game.EventHandler do
  alias Battleship.{LobbyChannel, GameChannel}

  def handle_event({:game_stopped, game_id}) do
    GameChannel.broadcast_stop(game_id)
    :ok
  end
  def handle_event(:game_created), do: broadcast_update()
  def handle_event(:player_joined), do: broadcast_update()
  def handle_event(:game_over), do: broadcast_update()
  def handle_event(:player_shot), do: broadcast_update()
  def handle_event(_), do: :ok

  defp broadcast_update do
    LobbyChannel.broadcast_current_games
    :ok
  end
end
