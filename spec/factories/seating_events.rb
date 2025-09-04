FactoryBot.define do
  factory :seating_event do
    association :cohort
    name { "Day #{Faker::Number.between(from: 1, to: 10)} - #{Faker::Lorem.words(number: 3).join(' ').titleize}" }
    event_type { :single_day }
    event_date { Date.current + Faker::Number.between(from: 1, to: 30).days }
    table_size { 4 }
    total_tables { 10 }

    trait :single_day do
      event_type { :single_day }
    end

    trait :multi_day do
      event_type { :multi_day }
    end

    trait :workshop do
      event_type { :workshop }
      name { "#{Faker::Lorem.words(number: 2).join(' ').titleize} Workshop" }
    end

    trait :today do
      event_date { Date.current }
    end

    trait :upcoming do
      event_date { Date.current + 1.week }
    end

    trait :past do
      event_date { Date.current - 1.week }
    end

    trait :small_tables do
      table_size { 3 }
      total_tables { 8 }
    end

    trait :large_tables do
      table_size { 6 }
      total_tables { 7 }
    end

    trait :with_arrangements do
      transient do
        arrangements_count { 2 }
      end

      after(:create) do |seating_event, evaluator|
        create_list(:seating_arrangement, evaluator.arrangements_count, seating_event: seating_event)
      end
    end

    trait :with_rules do
      transient do
        rules_count { 3 }
      end

      after(:create) do |seating_event, evaluator|
        create_list(:seating_rule, evaluator.rules_count, seating_event: seating_event)
      end
    end

    # Create a seating event with students ready for optimization
    trait :ready_for_optimization do
      association :cohort, :with_students

      after(:create) do |seating_event|
        # Ensure the cohort has enough students for optimization
        students_needed = [seating_event.max_students_capacity, 20].min
        current_count = seating_event.cohort.students.count
        
        if current_count < students_needed
          create_list(:student, students_needed - current_count, 
                     :with_inferences, cohort: seating_event.cohort)
        end
      end
    end
  end
end