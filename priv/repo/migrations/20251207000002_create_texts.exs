defmodule Langseed.Repo.Migrations.CreateTexts do
  use Ecto.Migration

  def change do
    create table(:texts) do
      add :title, :string, null: false
      add :content, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:texts, [:updated_at])
  end
end
