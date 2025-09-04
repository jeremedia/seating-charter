FactoryBot.define do
  factory :user do
    email { Faker::Internet.unique.email }
    password { 'password123' }
    password_confirmation { 'password123' }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    role { :instructor }

    trait :admin do
      role { :admin }
    end

    trait :instructor do
      role { :instructor }
    end

    # Create a user with confirmed email for integration tests
    trait :confirmed do
      confirmed_at { Time.current }
    end
  end
end