defmodule Langseed.Repo.Migrations.AddExplanationQuality do
  use Ecto.Migration

  def change do
    alter table(:concepts) do
      # AI's satisfaction with its explanation (1-5 scale, 5 = very satisfied)
      add :explanation_quality, :integer
      # Words the AI wishes it had to make a better explanation (stored as JSON array)
      add :desired_words, {:array, :string}, default: []
    end
  end
end




