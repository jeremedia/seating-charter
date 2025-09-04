class InteractionTracking < ApplicationRecord
  belongs_to :student_a
  belongs_to :student_b
  belongs_to :seating_event
end
