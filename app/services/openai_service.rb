class OpenaiService
  include HTTParty
  
  class << self
    def initialize_client
      OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
    end

    # Main method to make OpenAI API calls with cost tracking and error handling
    def call(prompt, purpose:, user: nil, max_retries: nil, model_override: nil)
      config = get_active_configuration
      raise "No active AI configuration found" unless config

      # Use override model if provided, otherwise use config model
      model = model_override || config.ai_model_name
      max_retries ||= config.retry_attempts
      
      client = initialize_client
      request_id = generate_request_id
      
      attempt = 0
      begin
        attempt += 1
        
        # Build parameters based on model type (GPT-5 has different requirements)
        params = {
          model: model,
          messages: [{ role: "user", content: prompt }]
        }
        
        # GPT-5 specific adjustments
        if model.start_with?('gpt-5')
          # GPT-5 uses max_completion_tokens instead of max_tokens
          params[:max_completion_tokens] = config.max_tokens
          # GPT-5 currently only supports default temperature (1.0)
          # Don't include temperature parameter for GPT-5
        else
          # GPT-4 and earlier models
          params[:temperature] = config.temperature.to_f
          params[:max_tokens] = config.max_tokens
        end
        
        response = client.chat(parameters: params)
        
        # Track costs
        track_cost(
          user: user,
          request_id: request_id,
          model: model,
          response: response,
          purpose: purpose,
          config: config
        )
        
        # Return the content
        response.dig("choices", 0, "message", "content")
        
      rescue OpenAI::RateLimitError => e
        if attempt <= max_retries
          sleep_time = calculate_backoff(attempt)
          Rails.logger.warn "OpenAI rate limit hit. Retrying in #{sleep_time} seconds (attempt #{attempt}/#{max_retries})"
          sleep(sleep_time)
          retry
        else
          Rails.logger.error "OpenAI rate limit exceeded after #{max_retries} attempts: #{e.message}"
          raise
        end
        
      rescue OpenAI::APIError => e
        Rails.logger.error "OpenAI API error: #{e.message}"
        raise
        
      rescue StandardError => e
        Rails.logger.error "Unexpected error in OpenAI service: #{e.message}"
        raise
      end
    end

    # Batch processing for multiple prompts (for roster parsing)
    def batch_call(prompts, purpose:, user: nil, model_override: nil)
      config = get_active_configuration
      raise "No active AI configuration found" unless config

      batch_size = config.batch_size || 5
      results = []
      
      prompts.each_slice(batch_size) do |batch|
        batch_results = batch.map do |prompt|
          call(prompt, purpose: purpose, user: user, model_override: model_override)
        end
        results.concat(batch_results)
        
        # Small delay between batches to avoid rate limits
        sleep(0.5) unless batch == prompts.last(batch_size)
      end
      
      results
    end

    # Test interface method with sample data
    def test_interface(sample_prompt = nil, user: nil)
      sample_prompt ||= "Please analyze the following student name and provide gender inference: 'John Smith'. Respond with just 'male', 'female', or 'unknown'."
      
      begin
        response = call(
          sample_prompt,
          purpose: "test_interface", 
          user: user
        )
        
        {
          success: true,
          response: response,
          timestamp: Time.current,
          model_used: get_active_configuration&.ai_model_name
        }
      rescue StandardError => e
        {
          success: false,
          error: e.message,
          timestamp: Time.current,
          model_used: get_active_configuration&.ai_model_name
        }
      end
    end

    # Get all available models (for admin UI)
    def available_models
      [
        'gpt-4o',
        'gpt-4o-mini',
        'gpt-4-turbo',
        'gpt-4',
        'gpt-3.5-turbo',
        'gpt-3.5-turbo-16k'
      ]
    end

    # Check if service is properly configured
    def configured?
      ENV['OPENAI_API_KEY'].present? && get_active_configuration.present?
    end

    private

    def get_active_configuration
      @active_config ||= AiConfiguration.find_by(active: true)
    end

    def generate_request_id
      "openai_#{SecureRandom.hex(8)}"
    end

    def calculate_backoff(attempt)
      # Exponential backoff: 1s, 2s, 4s, 8s, 16s
      [2**(attempt - 1), 30].min
    end

    def track_cost(user:, request_id:, model:, response:, purpose:, config:)
      return unless user

      usage = response.dig("usage")
      return unless usage

      input_tokens = usage["prompt_tokens"] || 0
      output_tokens = usage["completion_tokens"] || 0
      
      # Calculate cost based on configuration
      cost_estimate = calculate_cost(input_tokens, output_tokens, config)
      
      CostTracking.create!(
        user: user,
        request_id: request_id,
        ai_model_used: model,
        input_tokens: input_tokens,
        output_tokens: output_tokens,
        cost_estimate: cost_estimate,
        purpose: purpose
      )
      
      Rails.logger.info "OpenAI API call tracked: #{input_tokens + output_tokens} tokens, $#{cost_estimate} estimated cost"
    end

    def calculate_cost(input_tokens, output_tokens, config)
      # Default cost per token if not configured
      cost_per_token = config.cost_per_token || 0.00003 # Default for GPT-4o-mini
      
      # Simple calculation - in reality, input and output tokens have different costs
      total_tokens = input_tokens + output_tokens
      (total_tokens * cost_per_token).round(6)
    end
  end
end