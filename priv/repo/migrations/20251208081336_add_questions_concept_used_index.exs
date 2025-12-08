defmodule Langseed.Repo.Migrations.AddQuestionsConceptUsedIndex do
  use Ecto.Migration

  def change do
    create index(:questions, [:concept_id, :used])
  end
end
