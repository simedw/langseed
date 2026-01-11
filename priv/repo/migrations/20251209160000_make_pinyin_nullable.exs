defmodule Langseed.Repo.Migrations.MakePinyinNullable do
  use Ecto.Migration

  def change do
    # Pinyin is only relevant for Chinese - make it nullable for other languages
    alter table(:concepts) do
      modify :pinyin, :string, null: true
    end
  end
end




