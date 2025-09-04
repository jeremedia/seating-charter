class InferenceFeedback < ApplicationRecord
  belongs_to :student_import_record
  belongs_to :user
end
