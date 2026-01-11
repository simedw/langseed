defmodule Langseed.Repo.Migrations.AddPausedToConcepts do
  use Ecto.Migration

  def change do
    alter table(:concepts) do
      add :paused, :boolean, default: false, null: false
    end

    create index(:concepts, [:paused])
  end
end
