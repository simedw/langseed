defmodule Mix.Tasks.Audio.Backfill do
  @moduledoc """
  Generates audio for all questions that don't have cached audio in R2.

  Usage:
      mix audio.backfill           # All languages
      mix audio.backfill --lang en # Specific language
      mix audio.backfill --dry-run # Show what would be generated
  """

  use Mix.Task

  import Ecto.Query

  alias Langseed.Repo
  alias Langseed.Audio
  alias Langseed.Practice.Question
  alias Langseed.Practice.QuestionAudio

  @shortdoc "Backfill audio for questions missing cached audio"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(args, switches: [lang: :string, dry_run: :boolean])
    lang_filter = opts[:lang]
    dry_run = opts[:dry_run] || false

    if not Audio.cache_available?() do
      Mix.shell().error("Audio caching not available. Check TTS and R2 configuration.")
      exit({:shutdown, 1})
    end

    Mix.shell().info("Finding questions needing audio...")

    questions = get_questions_needing_audio(lang_filter)

    if Enum.empty?(questions) do
      Mix.shell().info("✓ All questions have cached audio!")
    else
      Mix.shell().info("Found #{length(questions)} questions needing audio")

      if dry_run do
        Mix.shell().info("\n[DRY RUN] Would generate audio for:")

        Enum.each(questions, fn {q, lang, sentence} ->
          created = Calendar.strftime(q.inserted_at, "%Y-%m-%d %H:%M:%S")

          Mix.shell().info(
            "  - Q#{q.id} (#{lang}) created #{created}: #{String.slice(sentence, 0, 40)}..."
          )
        end)
      else
        generate_audio_for_questions(questions)
      end
    end
  end

  defp get_questions_needing_audio(lang_filter) do
    query =
      from q in Question,
        join: c in assoc(q, :concept),
        select: {q, c.language}

    query =
      if lang_filter do
        where(query, [q, c], c.language == ^lang_filter)
      else
        query
      end

    Repo.all(query)
    |> Enum.map(fn {question, lang} ->
      sentence = QuestionAudio.sentence_for_question(question)
      {question, lang, sentence}
    end)
    |> Enum.filter(fn {_q, lang, sentence} ->
      path = Audio.audio_path_for(sentence, lang)
      path != nil and not Audio.Providers.R2Storage.audio_exists?(path)
    end)
  end

  defp generate_audio_for_questions(questions) do
    total = length(questions)

    questions
    |> Enum.with_index(1)
    |> Enum.each(fn {{question, lang, sentence}, idx} ->
      Mix.shell().info("[#{idx}/#{total}] Generating audio for Q#{question.id} (#{lang})...")

      case Audio.generate_sentence_audio(sentence, lang) do
        {:ok, url} when not is_nil(url) ->
          Mix.shell().info("  ✓ Cached: #{String.slice(url, 0, 60)}...")

        {:ok, nil} ->
          Mix.shell().info("  ⚠ No TTS for language: #{lang}")

        {:error, reason} ->
          Mix.shell().error("  ✗ Failed: #{inspect(reason)}")
      end
    end)

    Mix.shell().info("\n✓ Done!")
  end
end
