FactoryBot.define do
  factory :cohort do
    association :user
    name { "CHDS Cohort #{Faker::Number.unique.number(digits: 3)}" }
    description { Faker::Lorem.paragraph(sentence_count: 3) }
    start_date { Date.current + 1.week }
    end_date { start_date + 12.weeks }
    max_students { 40 }

    trait :active do
      start_date { Date.current - 1.week }
      end_date { Date.current + 11.weeks }
    end

    trait :upcoming do
      start_date { Date.current + 2.weeks }
      end_date { Date.current + 14.weeks }
    end

    trait :past do
      start_date { Date.current - 13.weeks }
      end_date { Date.current - 1.week }
    end

    trait :with_students do
      transient do
        students_count { 20 }
      end

      after(:create) do |cohort, evaluator|
        create_list(:student, evaluator.students_count, cohort: cohort)
      end
    end

    trait :full_capacity do
      after(:create) do |cohort|
        create_list(:student, cohort.max_students, cohort: cohort)
      end
    end
  end
end