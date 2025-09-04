VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.default_cassette_options = {
    record: :new_episodes,
    re_record_interval: 7.days
  }

  # Filter sensitive data
  config.filter_sensitive_data('<OPENAI_API_KEY>') { ENV['OPENAI_API_KEY'] }
  config.filter_sensitive_data('<OPENAI_ORGANIZATION_ID>') { ENV['OPENAI_ORGANIZATION_ID'] }

  # Allow localhost connections for system tests
  config.ignore_localhost = true
  
  # Ignore connections to test database
  config.ignore_request do |request|
    URI(request.uri).port == 5432 # PostgreSQL port
  end
end