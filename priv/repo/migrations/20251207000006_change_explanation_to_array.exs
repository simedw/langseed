defmodule Langseed.Repo.Migrations.ChangeExplanationToArray do
  use Ecto.Migration

  def up do
    # First, rename the old column
    rename table(:concepts), :explanation, to: :explanation_old

    # Add new array column
    alter table(:concepts) do
      add :explanations, {:array, :string}, default: []
    end

    # Migrate existing data
    execute """
    UPDATE concepts
    SET explanations = CASE
      WHEN explanation_old IS NOT NULL AND explanation_old != ''
      THEN ARRAY[explanation_old]
      ELSE ARRAY[]::varchar[]
    END
    """

    # Drop old column
    alter table(:concepts) do
      remove :explanation_old
    end
  end

  def down do
    alter table(:concepts) do
      add :explanation, :string
    end

    execute """
    UPDATE concepts
    SET explanation = explanations[1]
    """

    alter table(:concepts) do
      remove :explanations
    end
  end
end




