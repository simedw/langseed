defmodule Langseed.Repo.Migrations.AddUserIdToDataTables do
  use Ecto.Migration

  def change do
    # Add user_id to concepts (nullable for existing data backfill)
    alter table(:concepts) do
      add :user_id, references(:users, on_delete: :delete_all), null: true
    end

    create index(:concepts, [:user_id])

    # Add user_id to texts (nullable for existing data backfill)
    alter table(:texts) do
      add :user_id, references(:users, on_delete: :delete_all), null: true
    end

    create index(:texts, [:user_id])

    # Add user_id to questions (nullable for existing data backfill)
    alter table(:questions) do
      add :user_id, references(:users, on_delete: :delete_all), null: true
    end

    create index(:questions, [:user_id])
  end
end
