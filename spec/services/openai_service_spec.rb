require 'rails_helper'

RSpec.describe OpenaiService do
  let(:user) { create(:user) }
  let(:ai_config) { create(:ai_configuration, active: true) }

  before do
    ai_config
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return('test-api-key')
  end

  describe '.call', :vcr do
    let(:prompt) { "Test prompt for analysis" }
    let(:purpose) { "test_purpose" }

    context 'with valid configuration' do
      let(:mock_client) { instance_double(OpenAI::Client) }
      let(:mock_response) do
        {
          "choices" => [
            {
              "message" => {
                "content" => "Test response from OpenAI"
              }
            }
          ],
          "usage" => {
            "prompt_tokens" => 10,
            "completion_tokens" => 5
          }
        }
      end

      before do
        allow(OpenAI::Client).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:chat).and_return(mock_response)
      end

      it 'makes successful API call' do
        result = described_class.call(prompt, purpose: purpose, user: user)
        
        expect(result).to eq("Test response from OpenAI")
        expect(mock_client).to have_received(:chat).with(hash_including(
          parameters: hash_including(
            model: ai_config.ai_model_name,
            messages: [{ role: "user", content: prompt }]
          )
        ))
      end

      it 'tracks cost for API call' do
        expect {
          described_class.call(prompt, purpose: purpose, user: user)
        }.to change { CostTracking.count }.by(1)

        cost_record = CostTracking.last
        expect(cost_record.user).to eq(user)
        expect(cost_record.purpose).to eq(purpose)
        expect(cost_record.input_tokens).to eq(10)
        expect(cost_record.output_tokens).to eq(5)
      end

      it 'uses model override when provided' do
        override_model = 'gpt-4o-mini'
        described_class.call(prompt, purpose: purpose, user: user, model_override: override_model)
        
        expect(mock_client).to have_received(:chat).with(hash_including(
          parameters: hash_including(model: override_model)
        ))
      end

      context 'with GPT-5 model' do
        let(:ai_config) { create(:ai_configuration, active: true, ai_model_name: 'gpt-5-turbo') }

        it 'uses max_completion_tokens instead of max_tokens' do
          described_class.call(prompt, purpose: purpose, user: user)
          
          expect(mock_client).to have_received(:chat).with(hash_including(
            parameters: hash_including(
              max_completion_tokens: ai_config.max_tokens
            ).and(not_including(:max_tokens, :temperature))
          ))
        end
      end

      context 'with non-GPT-5 model' do
        let(:ai_config) { create(:ai_configuration, active: true, ai_model_name: 'gpt-4o') }

        it 'uses max_tokens and temperature parameters' do
          described_class.call(prompt, purpose: purpose, user: user)
          
          expect(mock_client).to have_received(:chat).with(hash_including(
            parameters: hash_including(
              max_tokens: ai_config.max_tokens,
              temperature: ai_config.temperature.to_f
            ).and(not_including(:max_completion_tokens))
          ))
        end
      end
    end

    context 'with rate limiting' do
      let(:mock_client) { instance_double(OpenAI::Client) }

      before do
        allow(OpenAI::Client).to receive(:new).and_return(mock_client)
        allow(described_class).to receive(:sleep) # Speed up tests
      end

      it 'retries on rate limit error' do
        rate_limit_error = OpenAI::RateLimitError.new("Rate limit exceeded")
        success_response = {
          "choices" => [{ "message" => { "content" => "Success" } }],
          "usage" => { "prompt_tokens" => 10, "completion_tokens" => 5 }
        }

        allow(mock_client).to receive(:chat)
          .and_raise(rate_limit_error)
          .and_return(success_response)

        result = described_class.call(prompt, purpose: purpose, user: user, max_retries: 2)
        
        expect(result).to eq("Success")
        expect(mock_client).to have_received(:chat).twice
      end

      it 'raises error after max retries' do
        rate_limit_error = OpenAI::RateLimitError.new("Rate limit exceeded")
        allow(mock_client).to receive(:chat).and_raise(rate_limit_error)

        expect {
          described_class.call(prompt, purpose: purpose, user: user, max_retries: 1)
        }.to raise_error(OpenAI::RateLimitError)
      end
    end

    context 'with API errors' do
      let(:mock_client) { instance_double(OpenAI::Client) }

      before do
        allow(OpenAI::Client).to receive(:new).and_return(mock_client)
      end

      it 'raises OpenAI::APIError' do
        api_error = OpenAI::APIError.new("API Error")
        allow(mock_client).to receive(:chat).and_raise(api_error)

        expect {
          described_class.call(prompt, purpose: purpose, user: user)
        }.to raise_error(OpenAI::APIError)
      end

      it 'raises StandardError for unexpected errors' do
        allow(mock_client).to receive(:chat).and_raise(StandardError.new("Unexpected error"))

        expect {
          described_class.call(prompt, purpose: purpose, user: user)
        }.to raise_error(StandardError, "Unexpected error")
      end
    end

    context 'without active configuration' do
      before do
        ai_config.update!(active: false)
      end

      it 'raises error when no active configuration' do
        expect {
          described_class.call(prompt, purpose: purpose, user: user)
        }.to raise_error("No active AI configuration found")
      end
    end
  end

  describe '.batch_call' do
    let(:prompts) { ["Prompt 1", "Prompt 2", "Prompt 3"] }
    let(:purpose) { "batch_test" }

    before do
      allow(described_class).to receive(:call).and_return("Mocked response")
      allow(described_class).to receive(:sleep) # Speed up tests
    end

    it 'processes all prompts' do
      results = described_class.batch_call(prompts, purpose: purpose, user: user)
      
      expect(results).to eq(["Mocked response", "Mocked response", "Mocked response"])
      expect(described_class).to have_received(:call).exactly(3).times
    end

    it 'respects batch size configuration' do
      ai_config.update!(batch_size: 2)
      
      described_class.batch_call(prompts, purpose: purpose, user: user)
      
      expect(described_class).to have_received(:sleep).at_least(1).times
    end

    it 'passes model override to individual calls' do
      model_override = 'gpt-4o-mini'
      described_class.batch_call(prompts, purpose: purpose, user: user, model_override: model_override)
      
      expect(described_class).to have_received(:call).with(
        anything, 
        hash_including(purpose: purpose, user: user, model_override: model_override)
      ).exactly(3).times
    end
  end

  describe '.test_interface' do
    let(:mock_response) { "Test response" }

    before do
      allow(described_class).to receive(:call).and_return(mock_response)
    end

    it 'returns successful test result' do
      result = described_class.test_interface(user: user)
      
      expect(result[:success]).to be true
      expect(result[:response]).to eq(mock_response)
      expect(result[:timestamp]).to be_within(1.second).of(Time.current)
      expect(result[:model_used]).to eq(ai_config.ai_model_name)
    end

    it 'handles errors gracefully' do
      allow(described_class).to receive(:call).and_raise(StandardError.new("Test error"))
      
      result = described_class.test_interface(user: user)
      
      expect(result[:success]).to be false
      expect(result[:error]).to eq("Test error")
      expect(result[:timestamp]).to be_within(1.second).of(Time.current)
    end

    it 'accepts custom sample prompt' do
      custom_prompt = "Custom test prompt"
      described_class.test_interface(custom_prompt, user: user)
      
      expect(described_class).to have_received(:call).with(
        custom_prompt,
        hash_including(purpose: "test_interface", user: user)
      )
    end
  end

  describe '.available_models' do
    it 'returns list of supported models' do
      models = described_class.available_models
      
      expect(models).to be_an(Array)
      expect(models).to include('gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo')
    end
  end

  describe '.configured?' do
    context 'with API key and active configuration' do
      it 'returns true' do
        expect(described_class.configured?).to be true
      end
    end

    context 'without API key' do
      before do
        allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return(nil)
      end

      it 'returns false' do
        expect(described_class.configured?).to be false
      end
    end

    context 'without active configuration' do
      before do
        ai_config.update!(active: false)
      end

      it 'returns false' do
        expect(described_class.configured?).to be false
      end
    end
  end

  describe 'private methods' do
    describe '.generate_request_id' do
      it 'generates unique request IDs' do
        id1 = described_class.send(:generate_request_id)
        id2 = described_class.send(:generate_request_id)
        
        expect(id1).to match(/^openai_[a-f0-9]{16}$/)
        expect(id2).to match(/^openai_[a-f0-9]{16}$/)
        expect(id1).not_to eq(id2)
      end
    end

    describe '.calculate_backoff' do
      it 'calculates exponential backoff' do
        expect(described_class.send(:calculate_backoff, 1)).to eq(1)
        expect(described_class.send(:calculate_backoff, 2)).to eq(2)
        expect(described_class.send(:calculate_backoff, 3)).to eq(4)
        expect(described_class.send(:calculate_backoff, 4)).to eq(8)
        expect(described_class.send(:calculate_backoff, 5)).to eq(16)
        expect(described_class.send(:calculate_backoff, 6)).to eq(30) # Cap at 30
      end
    end

    describe '.calculate_cost' do
      it 'calculates cost based on token usage' do
        cost = described_class.send(:calculate_cost, 100, 50, ai_config)
        expected_cost = (150 * ai_config.cost_per_token).round(6)
        
        expect(cost).to eq(expected_cost)
      end

      it 'uses default cost per token if not configured' do
        ai_config.update!(cost_per_token: nil)
        cost = described_class.send(:calculate_cost, 100, 50, ai_config)
        expected_cost = (150 * 0.00003).round(6)
        
        expect(cost).to eq(expected_cost)
      end
    end
  end
end