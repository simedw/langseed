defmodule Langseed.Vocabulary.Graph do
  @moduledoc """
  Builds a dependency graph of vocabulary words based on their explanations.

  If word A appears in the explanation of word B, we create an edge A → B,
  meaning "A is used to explain B" or "B depends on A".
  """

  alias Langseed.Vocabulary
  alias Langseed.Accounts.Scope

  @doc """
  Builds a graph of word dependencies for a scope's vocabulary.

  Returns a map with:
  - `nodes`: List of %{id: word, understanding: level, pinyin: string}
  - `links`: List of %{source: word, target: word} where source is used to explain target
  """
  @spec build_graph(Scope.t()) :: %{nodes: list(map()), links: list(map())}
  def build_graph(%Scope{} = scope) do
    concepts = Vocabulary.list_concepts(scope)
    known_words = MapSet.new(concepts, & &1.word)

    nodes =
      Enum.map(concepts, fn c ->
        %{
          id: c.word,
          understanding: c.understanding,
          pinyin: c.pinyin,
          meaning: c.meaning,
          part_of_speech: c.part_of_speech
        }
      end)

    links =
      concepts
      |> Enum.flat_map(fn concept ->
        # Find all known words used in this concept's explanations
        words_in_explanation = extract_words_from_explanations(concept.explanations, known_words)

        # Create edges: each word in explanation → this concept
        # (meaning: those words are used to define this word)
        words_in_explanation
        |> Enum.reject(&(&1 == concept.word))
        |> Enum.map(fn source_word ->
          %{source: source_word, target: concept.word}
        end)
      end)
      |> Enum.uniq()

    %{nodes: nodes, links: links}
  end

  @doc """
  Builds graph statistics for display.
  """
  @spec graph_stats(Scope.t()) :: map()
  def graph_stats(%Scope{} = scope) do
    graph = build_graph(scope)

    # Calculate in-degree (how many words depend on this word)
    in_degrees =
      Enum.reduce(graph.links, %{}, fn link, acc ->
        Map.update(acc, link.source, 1, &(&1 + 1))
      end)

    # Calculate out-degree (how many words this word depends on)
    out_degrees =
      Enum.reduce(graph.links, %{}, fn link, acc ->
        Map.update(acc, link.target, 1, &(&1 + 1))
      end)

    # Find most foundational words (highest in-degree = used to explain many others)
    foundational =
      in_degrees
      |> Enum.sort_by(fn {_word, count} -> -count end)
      |> Enum.take(10)

    # Find most complex words (highest out-degree = need many words to explain)
    complex =
      out_degrees
      |> Enum.sort_by(fn {_word, count} -> -count end)
      |> Enum.take(10)

    # Find isolated words (no edges)
    all_connected =
      MapSet.union(
        MapSet.new(graph.links, & &1.source),
        MapSet.new(graph.links, & &1.target)
      )

    isolated =
      graph.nodes
      |> Enum.map(& &1.id)
      |> Enum.reject(&MapSet.member?(all_connected, &1))

    %{
      node_count: length(graph.nodes),
      edge_count: length(graph.links),
      foundational: foundational,
      complex: complex,
      isolated_count: length(isolated)
    }
  end

  # Extract Chinese words from explanations that exist in known vocabulary
  defp extract_words_from_explanations(explanations, known_words) when is_list(explanations) do
    explanations
    |> Enum.flat_map(&extract_chinese_words/1)
    |> Enum.filter(&MapSet.member?(known_words, &1))
    |> Enum.uniq()
  end

  defp extract_words_from_explanations(nil, _known_words), do: []

  # Extract Chinese characters/words from text
  # This is a simple approach - we look for continuous Chinese character sequences
  defp extract_chinese_words(text) when is_binary(text) do
    # Match sequences of CJK characters
    ~r/[\p{Han}]+/u
    |> Regex.scan(text)
    |> List.flatten()
  end

  defp extract_chinese_words(_), do: []
end
