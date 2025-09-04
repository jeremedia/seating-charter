FactoryBot.define do
  factory :student do
    association :cohort
    name { Faker::Name.name }
    title { Faker::Job.title }
    organization { Faker::Company.name }
    location { "#{Faker::Address.city}, #{Faker::Address.state_abbr}" }
    
    # Initialize with empty hashes for JSON fields
    student_attributes { {} }
    inferences { {} }

    trait :with_basic_attributes do
      student_attributes do
        {
          'department' => Faker::Commerce.department,
          'years_of_service' => Faker::Number.between(from: 1, to: 20),
          'education_level' => %w[Bachelor Master PhD].sample
        }
      end
    end

    trait :with_inferences do
      inferences do
        {
          'gender' => {
            'value' => %w[male female].sample,
            'confidence' => Faker::Number.decimal(l_digits: 1, r_digits: 2)
          },
          'agency_level' => {
            'value' => %w[federal state local].sample,
            'confidence' => Faker::Number.decimal(l_digits: 1, r_digits: 2)
          },
          'department_type' => {
            'value' => %w[law_enforcement emergency_services administration].sample,
            'confidence' => Faker::Number.decimal(l_digits: 1, r_digits: 2)
          },
          'seniority_level' => {
            'value' => %w[entry mid senior executive].sample,
            'confidence' => Faker::Number.decimal(l_digits: 1, r_digits: 2)
          }
        }
      end
    end

    trait :with_high_confidence_inferences do
      inferences do
        {
          'gender' => {
            'value' => %w[male female].sample,
            'confidence' => 0.95
          },
          'agency_level' => {
            'value' => %w[federal state local].sample,
            'confidence' => 0.92
          }
        }
      end
    end

    trait :with_low_confidence_inferences do
      inferences do
        {
          'gender' => {
            'value' => %w[male female].sample,
            'confidence' => 0.45
          },
          'agency_level' => {
            'value' => %w[federal state local].sample,
            'confidence' => 0.30
          }
        }
      end
    end

    trait :male do
      inferences do
        {
          'gender' => {
            'value' => 'male',
            'confidence' => 0.95
          }
        }
      end
    end

    trait :female do
      inferences do
        {
          'gender' => {
            'value' => 'female',
            'confidence' => 0.95
          }
        }
      end
    end

    trait :federal_agent do
      title { "Special Agent" }
      organization { "Federal Bureau of Investigation" }
      inferences do
        {
          'agency_level' => {
            'value' => 'federal',
            'confidence' => 0.98
          },
          'department_type' => {
            'value' => 'law_enforcement',
            'confidence' => 0.95
          }
        }
      end
    end

    trait :local_police do
      title { "Police Officer" }
      organization { "#{Faker::Address.city} Police Department" }
      inferences do
        {
          'agency_level' => {
            'value' => 'local',
            'confidence' => 0.90
          },
          'department_type' => {
            'value' => 'law_enforcement',
            'confidence' => 0.88
          }
        }
      end
    end

    # Create a student with parsed name components
    trait :with_name_components do
      transient do
        first_name { Faker::Name.first_name }
        last_name { Faker::Name.last_name }
      end

      name { "#{first_name} #{last_name}" }
    end
  end
end