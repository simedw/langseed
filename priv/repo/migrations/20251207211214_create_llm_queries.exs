defmodule Langseed.Repo.Migrations.CreateLlmQueries do
  use Ecto.Migration

  def change do
    create table(:llm_queries) do
      add :user_id, references(:users, on_delete: :delete_all)
      add :query_type, :string
      add :model, :string
      add :input_tokens, :integer
      add :output_tokens, :integer

      timestamps()
    end

    create index(:llm_queries, [:user_id])
    create index(:llm_queries, [:query_type])
  end
end
