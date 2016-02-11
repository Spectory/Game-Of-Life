defmodule GOL do

  def start(args) do
    {:ok, pid} = GenServer.start(__MODULE__, args)
    pid
  end

  def init(args) do
    {last_index, statuses} = parse_init_args(args)
    cells = Enum.reduce(0..last_index, {},
      fn(y, grid) ->
        curr_row = Enum.reduce(0..last_index, {},
          fn(x, row) ->
            near = get_near(x, row, y, grid, last_index)
            status = get_status(x, y, statuses)
            {:ok, pid} = Cell.start(near, status, self)
            Tuple.append(row, pid)
          end)
        Tuple.append(grid, curr_row)
      end)
    state = %{cells: cells, done: :math.pow(last_index + 1, 2), run: false}
    {:ok, state}
  end

  def print(pid) do
    GenServer.cast(pid, :print)
  end

  def next(pid) do
    GenServer.cast(pid, :next)
  end

  def play(pid) do
    GenServer.cast(pid, :play)
  end

  def handle_cast(:print, state) do
    cells = state[:cells]
    func =
      fn(cell) ->
        IO.write if GenServer.call(cell, :print) == :alive, do: "O", else: "X"
      end
    do_all(cells, func, true)
    IO.puts ""
    {:noreply, state}
  end

  def handle_cast(:next, state) do
    new_state = state
    if state[:done] < :math.pow(tuple_size(state[:cells]), 2) do
      IO.puts "Last generation still in progress"
    else
      cells = state[:cells]
      new_state = Helper.set_key(state, :done, 0)
      do_all(cells,
        fn(cell) ->
          GenServer.call(cell, :prepare_next)
        end)

      do_all(cells,
        fn(cell) ->
          GenServer.cast(cell, :next)
        end)
    end
    {:noreply, new_state}
  end

  def handle_cast(:play, state) do
    new_state = Helper.set_key(state, :run, true)
    GenServer.cast(self, :next)
    {:noreply, new_state}
  end

  def handle_cast(:done, state) do
    new_state = Helper.inc_key(state, :done)
    if state[:run] && new_state[:done] == :math.pow(tuple_size(new_state[:cells]), 2) do
      GenServer.cast(self, :print)
      GenServer.cast(self, :next)
      :timer.sleep(1000)
    end
    {:noreply, new_state}
  end


  defp parse_init_args(num) when is_number(num), do: {num - 1, nil}

  defp parse_init_args(statuses), do: {tuple_size(statuses) - 1, statuses}

  defp do_all(cells, func, new_line \\ false) do
    last_index = tuple_size(cells) - 1
    Enum.each(0..last_index,
      fn(cell_row_index) ->
        cell_row = elem(cells, cell_row_index)
        Enum.each(0..last_index,
          fn(cell_index) ->
            cell = elem(cell_row, cell_index)
            func.(cell)
          end)
        if new_line, do: IO.puts ""
      end)
  end

  defp get_near(0, _, 0, _, _), do: []

  defp get_near(0, _, y, grid, _) when y != 0 do
    prev_row = elem(grid, y - 1)
    [elem(prev_row, 0), elem(prev_row, 1)]
  end

  defp get_near(x, row, 0, _, _)do
    [elem(row, x - 1)]
  end

  defp get_near(x, row, y, grid, last) when x == last do
    prev_row = elem(grid, y - 1)
    [elem(prev_row, x - 1), elem(prev_row, x), elem(row, x - 1)]
  end

  defp get_near(x, row, y, grid, _) do
    prev_row = elem(grid, y - 1)
    [elem(prev_row, x - 1), elem(prev_row, x), elem(prev_row, x + 1), elem(row, x - 1)]
  end

  defp get_status(_, _, nil) do
    if :crypto.rand_uniform(1, 5) == 1, do: :alive, else: :dead
  end

  defp get_status(x, y, statuses) do
    statuses
    |> elem(y)
    |> elem(x)
  end
end
