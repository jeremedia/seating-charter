FactoryBot.define do
  factory :table_assignment do
    association :seating_arrangement
    association :student
    
    table_number { 1 }
    seat_position { 1 }
    locked { false }

    trait :locked do
      locked { true }
    end

    trait :table_1 do
      table_number { 1 }
    end

    trait :table_2 do
      table_number { 2 }
    end

    trait :seat_1 do
      seat_position { 1 }
    end

    trait :seat_2 do
      seat_position { 2 }
    end

    trait :with_notes do
      assignment_notes { "Placed for optimal diversity balance" }
    end
  end
end