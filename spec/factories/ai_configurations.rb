FactoryBot.define do
  factory :ai_configuration do
    ai_model_name { 'gpt-4o-mini' }
    temperature { 0.7 }
    max_tokens { 1000 }
    cost_per_token { 0.00015 }
    retry_attempts { 3 }
    batch_size { 5 }
    active { true }

    trait :gpt4 do
      ai_model_name { 'gpt-4o' }
      cost_per_token { 0.005 }
    end

    trait :gpt5 do
      ai_model_name { 'gpt-5-turbo' }
      cost_per_token { 0.01 }
      temperature { nil } # GPT-5 doesn't support temperature parameter
    end

    trait :inactive do
      active { false }
    end

    trait :high_cost do
      cost_per_token { 0.02 }
    end

    trait :large_context do
      max_tokens { 4000 }
    end
  end
end