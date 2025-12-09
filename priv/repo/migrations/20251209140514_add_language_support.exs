defmodule Langseed.Repo.Migrations.AddLanguageSupport do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :selected_language, :string, default: "zh"
    end

    alter table(:concepts) do
      add :language, :string, null: false, default: "zh"
    end

    create index(:concepts, [:language])

    alter table(:texts) do
      add :language, :string, null: false, default: "zh"
    end
  end
end
