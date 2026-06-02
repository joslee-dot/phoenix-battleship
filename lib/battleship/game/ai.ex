defmodule Battleship.Game.AI do
  @moduledoc """
  AI player for single-player mode.
  Uses hunt-and-target strategy for shooting and random valid placement for ships.
  """
  alias Battleship.{Ship}
  alias Battleship.Game.Board
  require Logger

  @board_size 10
  @ships_sizes [5, 4, 3, 2, 2, 1, 1]
  @orientations [:horizontal, :vertical]
  @grid_value_water "·"
  @grid_value_ship_hit "*"

  @doc """
  Places all ships randomly on the AI player's board.
  """
  def place_ships(player_id) do
    Enum.each(@ships_sizes, fn size ->
      place_ship(player_id, size)
    end)
  end

  defp place_ship(player_id, size) do
    orientation = Enum.random(@orientations)
    {max_x, max_y} = max_coords(size, orientation)
    x = :rand.uniform(max_x + 1) - 1
    y = :rand.uniform(max_y + 1) - 1

    ship = %Ship{x: x, y: y, size: size, orientation: orientation}

    case Board.add_ship(player_id, ship) do
      {:ok, _} -> :ok
      {:error, _} -> place_ship(player_id, size)
    end
  end

  defp max_coords(size, :horizontal), do: {@board_size - size, @board_size - 1}
  defp max_coords(size, :vertical), do: {@board_size - 1, @board_size - size}

  @doc """
  Chooses the next shot using hunt-and-target strategy.
  Returns {x, y} coordinates.
  """
  def choose_shot(opponent_id) do
    board = Board.get_opponents_data(opponent_id)
    grid = board.grid

    # Find cells that have been hit (ship hits) to target adjacent cells
    hits = grid
    |> Enum.filter(fn {_coords, value} -> value == @grid_value_ship_hit end)
    |> Enum.map(fn {coords, _} -> coords end)

    # Find untargeted cells (on opponent's view, ships appear as water)
    available = grid
    |> Enum.filter(fn {_coords, value} -> value == @grid_value_water end)
    |> Enum.map(fn {coords, _} -> coords end)

    case find_target_shot(hits, available, grid) do
      nil -> random_shot(available)
      coords ->
        {y, x} = parse_coords(coords)
        {x, y}
    end
  end

  # Hunt mode: look for adjacent cells next to existing hits
  defp find_target_shot([], _available, _grid), do: nil
  defp find_target_shot(hits, available, _grid) do
    adjacent = hits
    |> Enum.flat_map(&get_adjacent_coords/1)
    |> Enum.filter(&(&1 in available))
    |> Enum.uniq

    case adjacent do
      [] -> nil
      targets -> Enum.random(targets)
    end
  end

  defp get_adjacent_coords(coords) do
    {y, x} = parse_coords(coords)

    [{y - 1, x}, {y + 1, x}, {y, x - 1}, {y, x + 1}]
    |> Enum.filter(fn {r, c} -> r >= 0 and r < @board_size and c >= 0 and c < @board_size end)
    |> Enum.map(fn {r, c} -> "#{r}#{c}" end)
  end

  defp parse_coords(coords) do
    chars = String.graphemes(coords)
    {String.to_integer(Enum.at(chars, 0)), String.to_integer(Enum.at(chars, 1))}
  end

  # Random shot from available cells (checkerboard pattern for efficiency)
  defp random_shot(available) do
    # Prefer checkerboard pattern (more efficient ship hunting)
    checkerboard = Enum.filter(available, fn coords ->
      {y, x} = parse_coords(coords)
      rem(y + x, 2) == 0
    end)

    target = case checkerboard do
      [] -> Enum.random(available)
      cells -> Enum.random(cells)
    end

    {y, x} = parse_coords(target)
    {x, y}
  end
end
