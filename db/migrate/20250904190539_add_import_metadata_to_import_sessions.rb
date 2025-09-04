class AddImportMetadataToImportSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :import_sessions, :import_metadata, :text
  end
end
