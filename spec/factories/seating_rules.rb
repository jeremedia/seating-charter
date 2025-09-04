FactoryBot.define do
  factory :seating_rule do
    association :seating_event
    association :created_by, factory: :user
    
    rule_type { 'separation' }
    natural_language_input { "Keep law enforcement and emergency services at different tables" }
    priority { 5 }
    active { true }
    confidence_score { 0.85 }
    
    target_attributes do
      {
        'department_type' => ['law_enforcement', 'emergency_services']
      }
    end
    
    constraints do
      {
        'min_separation' => 1,
        'applies_to' => 'all_matching'
      }
    end

    trait :separation do
      rule_type { 'separation' }
      natural_language_input { "Separate students from different agency levels" }
      target_attributes do
        {
          'agency_level' => ['federal', 'state', 'local']
        }
      end
    end

    trait :clustering do
      rule_type { 'clustering' }
      natural_language_input { "Group students from the same department together" }
      target_attributes do
        {
          'department_type' => ['law_enforcement']
        }
      end
      constraints do
        {
          'cluster_size' => 3,
          'max_clusters' => 2
        }
      end
    end

    trait :distribution do
      rule_type { 'distribution' }
      natural_language_input { "Distribute gender evenly across all tables" }
      target_attributes do
        {
          'gender' => ['male', 'female']
        }
      end
      constraints do
        {
          'distribution_type' => 'even',
          'tolerance' => 0.2
        }
      end
    end

    trait :proximity do
      rule_type { 'proximity' }
      natural_language_input { "Place senior officers near junior staff" }
      target_attributes do
        {
          'seniority_level' => ['senior', 'entry']
        }
      end
      constraints do
        {
          'proximity_type' => 'near',
          'max_distance' => 1
        }
      end
    end

    trait :custom do
      rule_type { 'custom' }
      natural_language_input { "Apply custom constraint based on organization size" }
      target_attributes do
        {
          'organization_size' => ['large', 'small']
        }
      end
      constraints do
        {
          'custom_logic' => 'balance_by_attribute',
          'weight_factor' => 1.5
        }
      end
    end

    trait :high_priority do
      priority { 1 }
    end

    trait :low_priority do
      priority { 10 }
    end

    trait :high_confidence do
      confidence_score { 0.95 }
    end

    trait :low_confidence do
      confidence_score { 0.45 }
    end

    trait :inactive do
      active { false }
    end

    trait :with_specific_students do
      transient do
        target_students { [] }
      end
      
      target_students { target_students }
      natural_language_input { "Keep specified students together" }
      rule_type { 'clustering' }
      
      target_attributes do
        {
          'student_ids' => target_students.map(&:id)
        }
      end
    end

    trait :gender_balance do
      rule_type { 'distribution' }
      natural_language_input { "Ensure equal gender distribution at each table" }
      target_attributes do
        {
          'gender' => ['male', 'female']
        }
      end
      constraints do
        {
          'distribution_type' => 'balanced',
          'tolerance' => 0.1
        }
      end
      priority { 2 }
      confidence_score { 0.92 }
    end

    trait :agency_mixing do
      rule_type { 'distribution' }
      natural_language_input { "Mix federal, state, and local agency representatives at each table" }
      target_attributes do
        {
          'agency_level' => ['federal', 'state', 'local']
        }
      end
      constraints do
        {
          'distribution_type' => 'mixed',
          'min_variety' => 2
        }
      end
      priority { 3 }
    end

    trait :department_separation do
      rule_type { 'separation' }
      natural_language_input { "Avoid placing too many people from the same department at one table" }
      target_attributes do
        {
          'department_type' => ['law_enforcement', 'emergency_services', 'administration']
        }
      end
      constraints do
        {
          'max_same_department' => 2,
          'enforce_strict' => false
        }
      end
      priority { 4 }
    end

    trait :ai_generated do
      ai_reasoning { "AI determined this rule based on natural language processing of instructor preferences" }
      ai_generated { true }
      confidence_score { 0.78 }
    end
  end
end