defmodule Langseed.Repo.Migrations.ChangeAudioPathToText do
  use Ecto.Migration

  def change do
    alter table(:concepts) do
      modify :audio_path, :text, from: :string
    end
  end
end
