class StudentImportRecord < ApplicationRecord
  belongs_to :import_session
  belongs_to :student
end
