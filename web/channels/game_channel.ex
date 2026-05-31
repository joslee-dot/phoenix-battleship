defmodule Battleship.GameChannel do
  @moduledoc """
  Game channel
  """
  use Phoenix.Channel
  alias Battleship.{Game, Ship}
  alias Battleship.Game.Board
  alias Battleship.Game.Supervisor, as: GameSupervisor
  require Logger

  def join("game:" <> game_id, message, socket) do
    Logger.debug "Joining Game channel #{game_id}", game_id: game_id

    player_id = socket.assigns.player_id
    is_ai_game = message["ai"] == true

    case Game.join(game_id, player_id, socket.channel_pid) do
      {:ok, pid} ->
        Process.monitor(pid)

        socket = socket
        |> assign(:game_id, game_id)
        |> assign(:ai_game, is_ai_game)

        # If AI game, add AI as second player after human joins
        if is_ai_game do
          send(self(), :setup_ai_player)
        end

        {:ok, socket}
      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end

  def handle_in("game:joined", _message, socket) do
    Logger.debug "Broadcasting player joined #{socket.assigns.game_id}"

    player_id = socket.assigns.player_id
    board = Board.get_opponents_data(player_id)

    broadcast! socket, "game:player_joined", %{player_id: player_id, board: board}
    {:noreply, socket}
  end

  def handle_in("game:get_data", _message, socket) do
    player_id = socket.assigns.player_id
    game_id = socket.assigns.game_id

    data = Game.get_data(game_id, player_id)

    {:reply, {:ok, %{game: data}}, socket}
  end

  def handle_in("game:send_message", %{"text" => text}, socket) do
    Logger.debug "Handling send_message on GameChannel #{socket.assigns.game_id}"

    player_id = socket.assigns.player_id
    message = %{player_id: player_id, text: text}

    broadcast! socket, "game:message_sent", %{message: message}

    {:noreply, socket}
  end

  def handle_in("game:place_ship", %{"ship" => ship}, socket) do
    Logger.debug "Handling place_ship on GameChannel #{socket.assigns.game_id}"

    player_id = socket.assigns.player_id
    game_id = socket.assigns.game_id

    ship = %Ship{
      x: ship["x"],
      y: ship["y"],
      size: ship["size"],
      orientation: String.to_existing_atom(ship["orientation"])
    }

    case Board.add_ship(player_id, ship) do
      {:ok, _} ->
        game = Game.get_data(game_id, player_id)
        board = Board.get_opponents_data(player_id)

        broadcast(socket, "game:player:#{Game.get_opponents_id(game, player_id)}:opponents_board_changed", %{board: board})

        {:reply, {:ok, %{game: game}}, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("game:shoot", %{"y" => y, "x" => x}, socket) do
    Logger.debug "Handling shoot on GameChannel #{socket.assigns.game_id}"

    player_id = socket.assigns.player_id
    game_id = socket.assigns.game_id

    case Game.player_shot(game_id, player_id, x: x, y: y) do
      {:ok, %Game{over: true} = game} ->
        broadcast(socket, "game:over", %{game: game})
        {:noreply, socket}
      {:ok, game} ->
        opponent_id = Game.get_opponents_id(game, player_id)
        broadcast(socket, "game:player:#{opponent_id}:set_game", %{game: Game.get_data(game_id, opponent_id)})

        # If opponent is AI, fire back automatically after a short delay
        if is_ai_player?(opponent_id) do
          Process.send_after(self(), {:ai_shoot, game_id, opponent_id, player_id}, 1000)
        end

        {:reply, {:ok, %{game: Game.get_data(game_id, player_id)}}, socket}
      _ ->
        {:reply, {:error, %{reason: "Something went wrong while shooting"}}, socket}
    end
  end

  def terminate(reason, socket) do
    Logger.debug "Terminating GameChannel #{socket.assigns.game_id} #{inspect reason}"

    player_id = socket.assigns.player_id
    game_id = socket.assigns.game_id

    # For AI games, don't destroy the game on disconnect - let the player reconnect
    if Map.get(socket.assigns, :ai_game, false) do
      Logger.debug "AI game #{game_id} - keeping game alive for reconnection"
      :ok
    else
      case Game.player_left(game_id, player_id) do
        {:ok, game} ->
          GameSupervisor.stop_game(game_id)

          broadcast(socket, "game:over", %{game: game})
          broadcast(socket, "game:player_left", %{player_id: player_id})

          :ok
        _ ->
          :ok
      end
    end
  end

  def handle_info(:setup_ai_player, socket) do
    game_id = socket.assigns.game_id
    ai_player_id = "ai-" <> Battleship.generate_player_id()

    Logger.debug "Setting up AI player #{ai_player_id} for game #{game_id}"

    case Game.join(game_id, ai_player_id, self()) do
      {:ok, _pid} ->
        # Place AI ships
        Battleship.Game.AI.place_ships(ai_player_id)

        # Store AI player id in socket assigns
        socket = assign(socket, :ai_player_id, ai_player_id)

        # Broadcast AI player joined with board data
        board = Board.get_opponents_data(ai_player_id)
        broadcast!(socket, "game:player_joined", %{player_id: ai_player_id, board: board})

        {:noreply, socket}
      {:error, reason} ->
        Logger.error "Failed to add AI player: #{reason}"
        {:noreply, socket}
    end
  end

  def handle_info({:ai_shoot, game_id, ai_player_id, human_player_id}, socket) do
    Logger.debug "AI taking shot in game #{game_id}"

    {x, y} = Battleship.Game.AI.choose_shot(human_player_id)

    case Game.player_shot(game_id, ai_player_id, x: x, y: y) do
      {:ok, %Game{over: true} = game} ->
        broadcast(socket, "game:over", %{game: game})
      {:ok, game} ->
        push(socket, "game:player:#{human_player_id}:set_game", %{game: Game.get_data(game_id, human_player_id)})
      _ ->
        :ok
    end

    {:noreply, socket}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  def broadcast_stop(game_id) do
    Logger.debug "Broadcasting game:stopped from GameChannel #{game_id}"

    Battleship.Endpoint.broadcast("game:#{game_id}", "game:stopped", %{})
  end

  defp is_ai_player?(player_id) when is_binary(player_id) do
    String.starts_with?(player_id, "ai-")
  end
  defp is_ai_player?(_), do: false
end
