FactoryBot.define do
  factory :cost_tracking do
    association :user
    
    request_id { "openai_#{SecureRandom.hex(8)}" }
    ai_model_used { 'gpt-4o-mini' }
    input_tokens { 150 }
    output_tokens { 75 }
    cost_estimate { 0.003375 } # (150 + 75) * 0.00015
    purpose { 'test_purpose' }
    created_at { Time.current }

    trait :expensive_call do
      ai_model_used { 'gpt-4o' }
      input_tokens { 1000 }
      output_tokens { 500 }
      cost_estimate { 0.75 } # Higher cost for GPT-4
    end

    trait :inference_call do
      purpose { 'attribute_inference' }
      input_tokens { 200 }
      output_tokens { 50 }
    end

    trait :parsing_call do
      purpose { 'natural_language_parsing' }
      input_tokens { 500 }
      output_tokens { 200 }
    end

    trait :recent do
      created_at { 1.hour.ago }
    end

    trait :old do
      created_at { 1.month.ago }
    end
  end
end