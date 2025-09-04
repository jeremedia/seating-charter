FactoryBot.define do
  factory :interaction_tracking do
    association :student_a, factory: :student
    association :student_b, factory: :student
    association :cohort
    
    interaction_date { Date.current }
    interaction_context { 'seating_arrangement' }
    
    interaction_metadata do
      {
        'seating_event_id' => create(:seating_event).id,
        'table_number' => 1,
        'duration_minutes' => 60
      }
    end

    trait :workshop_interaction do
      interaction_context { 'workshop' }
      interaction_metadata do
        {
          'workshop_name' => 'Crisis Management Training',
          'activity_type' => 'group_exercise'
        }
      end
    end

    trait :recent do
      interaction_date { Date.current }
    end

    trait :old do
      interaction_date { 1.month.ago }
    end
  end
end