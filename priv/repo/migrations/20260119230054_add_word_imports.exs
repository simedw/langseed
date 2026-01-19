defmodule Langseed.Repo.Migrations.AddWordImports do
  use Ecto.Migration

  def change do
    create table(:word_imports) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :language, :string, null: false
      add :word, :string, null: false
      add :context, :text
      add :status, :string, null: false, default: "pending"
      add :error, :text

      timestamps()
    end

    create index(:word_imports, [:user_id])
    create index(:word_imports, [:user_id, :status])
    create index(:word_imports, [:status])
  end
end
