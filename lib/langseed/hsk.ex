defmodule Langseed.HSK do
  @moduledoc """
  HSK 3.0 level lookup service.

  Loads HSK vocabulary data into an ETS table for fast O(1) lookups.
  Levels 1-6 are individual, levels 7-9 are combined as "7-9".
  """

  use GenServer

  @table :hsk_levels

  # Client API

  @doc """
  Looks up the HSK level for a word.

  Returns the level as a string (e.g., "1", "4", "7-9") or nil if not found.
  """
  @spec lookup(String.t()) :: String.t() | nil
  def lookup(word) do
    case :ets.lookup(@table, word) do
      [{^word, level}] -> level
      [] -> nil
    end
  end

  @doc """
  Starts the HSK lookup service.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    load_data()
    {:ok, %{}}
  end

  defp load_data do
    path = Application.app_dir(:langseed, "priv/data/hsk30.json")

    case File.read(path) do
      {:ok, content} ->
        data = Jason.decode!(content)

        Enum.each(data, fn {word, level} ->
          :ets.insert(@table, {word, level})
        end)

      {:error, reason} ->
        require Logger
        Logger.warning("Failed to load HSK data: #{inspect(reason)}")
    end
  end
end
