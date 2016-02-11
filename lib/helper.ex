defmodule Helper do
  def inc_key(map, key) do
    set_key(map, key, map[key] + 1)
  end

  def reset_key(map, key) do
    set_key(map, key, 0)
  end

  def set_key(map, key, value) do
    Map.put(map, key, value)
  end
end
