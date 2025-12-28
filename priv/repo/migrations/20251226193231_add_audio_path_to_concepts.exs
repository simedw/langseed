defmodule Langseed.Repo.Migrations.AddAudioPathToConcepts do
  use Ecto.Migration

  def change do
    alter table(:concepts) do
      add :audio_path, :string
    end
  end
end
