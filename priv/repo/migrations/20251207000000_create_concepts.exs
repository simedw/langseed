defmodule Langseed.Repo.Migrations.CreateConcepts do
  use Ecto.Migration

  def change do
    create table(:concepts) do
      add :word, :string, null: false
      add :pinyin, :string, null: false
      add :meaning, :string, null: false
      add :part_of_speech, :string, null: false
      add :explanation, :string
      add :example_sentence, :string
      add :understanding, :integer, default: 0, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:concepts, [:word])
    create index(:concepts, [:understanding])
  end
end
