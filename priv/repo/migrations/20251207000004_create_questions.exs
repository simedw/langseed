defmodule Langseed.Repo.Migrations.CreateQuestions do
  use Ecto.Migration

  def change do
    create table(:questions) do
      add :concept_id, references(:concepts, on_delete: :delete_all), null: false
      add :question_type, :string, null: false
      add :question_text, :text, null: false
      add :correct_answer, :string
      add :options, {:array, :string}, default: []
      add :explanation, :text
      add :used, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:questions, [:concept_id])
    create index(:questions, [:used])
    create index(:questions, [:question_type])
  end
end




