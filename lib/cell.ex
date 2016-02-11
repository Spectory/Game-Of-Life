defmodule Cell do

  def start(near_me, status, parent) do
    GenServer.start(__MODULE__, {near_me, status, parent})
  end

  def init({near_me, status, parent}) do
    state = %{parent: parent, near_me: near_me, status: status, new_status: status, queried: 0, alive_near: 0}
    do_all(near_me,
      fn(cell) ->
        GenServer.call(cell, :acknowledge)
      end)
    {:ok, state}
  end

  def handle_call(:print, _, state) do
    {:reply, state[:new_status], state}
  end

  def handle_call(:acknowledge, {pid, _}, state) do
    new_near_me =
      state[:near_me]
      |> List.insert_at(0, pid)
    new_state =
      state
      |> Map.put(:near_me, new_near_me)

    {:reply, :ok, new_state}
  end

  def handle_call(:prepare_next, _, state) do
    new_state =
      state
      |> Helper.set_key(:status, state[:new_status])
      |> Helper.reset_key(:queried)
      |> Helper.reset_key(:alive_near)
    {:reply, :ok, new_state}
  end

  def handle_cast(:next, state) do
    do_all(state[:near_me],
      fn (cell) ->
        GenServer.cast(cell, {:status, self})
      end)
    {:noreply, state}
  end

  def handle_cast({:status, from}, state) do
    GenServer.cast(from, {:response, state[:status]})
    {:noreply, state}
  end

  def handle_cast({:response, response}, state) do
    new_state =
      state
      |> Helper.inc_key(:queried)
      |> handle_response(response)
      |> is_done

    {:noreply, new_state}
  end

  defp handle_response(state, :dead), do: state

  defp handle_response(state, :alive), do: Helper.inc_key(state, :alive_near)

  defp is_done(state) do
    if state[:queried] == Enum.count(state[:near_me]) do
      new_state =
        state
        |> Helper.set_key(:new_status, calc_status(state[:status], state[:alive_near]))

      inform_done(new_state)
      new_state
    else
      state
    end
  end

  defp inform_done(state) do
    GenServer.cast(state[:parent], :done)
  end

  defp calc_status(_, 3), do: :alive

  defp calc_status(:alive, 2), do: :alive

  defp calc_status(_, _), do: :dead

  defp do_all([], _), do: nil

  defp do_all([head | []], func), do: func.(head)

  defp do_all([head | tail], func) do
    func.(head)
    do_all(tail, func)
  end
end
