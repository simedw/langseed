defmodule Langseed.Repo.Migrations.UpdateQuestionsForSrs do
  use Ecto.Migration

  def change do
    # Add used_at timestamp for race-condition-free question tracking
    alter table(:questions) do
      add :used_at, :utc_datetime
    end

    # Backfill: used = true → used_at = updated_at
    execute(
      "UPDATE questions SET used_at = updated_at WHERE used = true",
      "UPDATE questions SET used = true WHERE used_at IS NOT NULL"
    )

    # Rename fill_blank to multiple_choice for semantic clarity
    execute(
      "UPDATE questions SET question_type = 'multiple_choice' WHERE question_type = 'fill_blank'",
      "UPDATE questions SET question_type = 'fill_blank' WHERE question_type = 'multiple_choice'"
    )

    # Create index on used_at for efficient queries
    create index(:questions, [:concept_id, :question_type, :used_at])
  end
end
