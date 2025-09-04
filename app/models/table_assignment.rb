class TableAssignment < ApplicationRecord
  belongs_to :seating_arrangement
  belongs_to :student
end
