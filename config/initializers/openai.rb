OpenAI.configure do |config|
  config.access_token = ENV.fetch("OPENAI_API_KEY", nil)
  config.log_errors = Rails.env.development? # Will log errors to the Rails logger
end