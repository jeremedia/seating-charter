class SeatingArrangement < ApplicationRecord
  belongs_to :seating_event
  belongs_to :created_by
end
