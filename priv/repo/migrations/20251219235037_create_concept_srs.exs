defmodule Langseed.Repo.Migrations.CreateConceptSrs do
  use Ecto.Migration

  def change do
    create table(:concept_srs) do
      add :concept_id, references(:concepts, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :question_type, :string, null: false
      add :tier, :integer, default: 0, null: false
      add :next_review, :utc_datetime
      add :lapses, :integer, default: 0
      add :streak, :integer, default: 0
      add :ease, :float, default: 2.5

      timestamps(type: :utc_datetime)
    end

    # One SRS record per (user, concept, question_type) tuple
    create unique_index(:concept_srs, [:user_id, :concept_id, :question_type])

    # Composite index for finding due reviews efficiently
    create index(:concept_srs, [:user_id, :next_review])
    create index(:concept_srs, [:user_id, :tier])

    # Backfill: Create SRS records for existing concepts with understanding > 0
    execute(
      """
      INSERT INTO concept_srs (concept_id, user_id, question_type, tier, next_review, lapses, streak, ease, inserted_at, updated_at)
      SELECT
        c.id,
        c.user_id,
        qt.type,
        CASE
          WHEN c.understanding >= 100 THEN 7
          ELSE LEAST(6, FLOOR(c.understanding::float / 100.0 * 7))::integer
        END as tier,
        CASE
          WHEN c.understanding >= 100 THEN NULL
          ELSE NOW()
        END as next_review,
        0 as lapses,
        0 as streak,
        2.5 as ease,
        NOW() as inserted_at,
        NOW() as updated_at
      FROM concepts c
      CROSS JOIN (
        SELECT 'yes_no' as type
        UNION ALL SELECT 'multiple_choice'
        UNION ALL SELECT 'pinyin'
      ) qt
      WHERE c.understanding > 0
        AND c.user_id IS NOT NULL
        AND (c.language = 'zh' OR qt.type != 'pinyin')
      """,
      # Rollback: delete all SRS records
      "DELETE FROM concept_srs"
    )
  end
end
