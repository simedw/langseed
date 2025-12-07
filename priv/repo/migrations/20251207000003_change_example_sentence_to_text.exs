defmodule Langseed.Repo.Migrations.ChangeExampleSentenceToText do
  use Ecto.Migration

  def change do
    alter table(:concepts) do
      modify :example_sentence, :text, from: :string
    end
  end
end
