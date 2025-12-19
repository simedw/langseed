defmodule Langseed.LLM.Client do
  @moduledoc """
  Minimal LLM client that handles calling the model and tracking usage.

  Designed for composability:

      prompt
      |> Client.generate()
      |> Client.track_usage(user_id, "analyze_word")
      |> Client.parse_json()
  """

  alias Langseed.Analytics

  @default_model "gemini-3-flash-preview"

  defmodule Response do
    @moduledoc "Wrapper for LLM response with usage metadata"

    @type t :: %__MODULE__{
            text: String.t() | nil,
            model: String.t(),
            input_tokens: integer() | nil,
            output_tokens: integer() | nil
          }

    defstruct [:text, :model, :input_tokens, :output_tokens]
  end

  @doc """
  Generates text from the LLM.

  Returns `{:ok, %Response{}}` with the response text and token usage,
  or `{:error, reason}`.
  """
  @spec generate(String.t(), String.t()) :: {:ok, Response.t()} | {:error, String.t()}
  def generate(prompt, model \\ @default_model) do
    case ReqLLM.generate_text("google:#{model}", prompt) do
      {:ok, response} ->
        usage = extract_usage(response)

        {:ok,
         %Response{
           text: ReqLLM.Response.text(response),
           model: model,
           input_tokens: usage.input_tokens,
           output_tokens: usage.output_tokens
         }}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Tracks usage by logging to the analytics module.

  Designed to be piped after `generate/2`:

      prompt
      |> Client.generate()
      |> Client.track_usage(user_id, "analyze_word")

  Returns `{:ok, text}` on success (extracting just the text for downstream use),
  or passes through `{:error, reason}`.
  """
  @spec track_usage({:ok, Response.t()} | {:error, String.t()}, integer() | nil, String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def track_usage({:ok, %Response{} = response}, user_id, query_type) do
    Analytics.log_query(%{
      user_id: user_id,
      query_type: query_type,
      model: response.model,
      input_tokens: response.input_tokens,
      output_tokens: response.output_tokens
    })

    {:ok, response.text}
  end

  def track_usage({:error, _} = error, _user_id, _query_type), do: error

  @doc """
  Parses a JSON response, cleaning markdown code fences if present.

  Returns `{:ok, map}` or `{:error, reason}`.
  """
  @spec parse_json({:ok, String.t()} | {:error, String.t()}) ::
          {:ok, map()} | {:error, String.t()}
  def parse_json({:ok, nil}), do: {:error, "Empty response from API"}

  def parse_json({:ok, response}) when is_binary(response) do
    cleaned = clean_json_response(response)

    case Jason.decode(cleaned) do
      {:ok, data} -> {:ok, data}
      {:error, _} -> {:error, "Failed to parse JSON response: #{cleaned}"}
    end
  end

  def parse_json({:error, _} = error), do: error

  @doc """
  Cleans a JSON response by removing markdown code fences.
  """
  @spec clean_json_response(String.t()) :: String.t()
  def clean_json_response(response) do
    response
    |> String.trim()
    |> String.replace(~r/^```json\n?/, "")
    |> String.replace(~r/\n?```$/, "")
    |> String.trim()
  end

  # Private helpers

  defp extract_usage(%{usage: usage}) when is_map(usage) do
    %{
      input_tokens: Map.get(usage, :input_tokens) || Map.get(usage, :prompt_tokens),
      output_tokens: Map.get(usage, :output_tokens) || Map.get(usage, :completion_tokens)
    }
  end

  defp extract_usage(_), do: %{input_tokens: nil, output_tokens: nil}
end
