source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.2", ">= 8.0.2.1"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Authentication
gem "devise"

# Environment variables
gem "dotenv-rails"

# OpenAI integration
gem "ruby-openai"

# PDF processing and export
gem "prawn"
gem "prawn-table"
gem "pdf-reader"

# Excel processing
gem "roo"
gem "roo-xls"
gem "caxlsx"
gem "caxlsx_rails"

# File upload processing
gem "image_processing", "~> 1.2"

# QR code generation
gem "rqrcode"

# ZIP file handling
gem "rubyzip", require: 'zip'

# Tailwind CSS
gem "tailwindcss-rails"

# Background job processing (for AI calls)
gem "sidekiq"

# HTTP client for API calls
gem "httparty"

# JSON handling
gem "oj"

# Pagination
gem "kaminari"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # RSpec testing framework
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "shoulda-matchers"
  gem "vcr"
  gem "webmock"
  gem "timecop"
  gem "database_cleaner-active_record"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
  gem "rspec_junit_formatter"
  gem "simplecov", require: false
  gem "simplecov-lcov", require: false
end

group :production do
  # Error tracking
  gem "rollbar"
  
  # Performance monitoring
  gem "newrelic_rpm"
  
  # Rate limiting
  gem "rack-attack"
  
  # Logging
  gem "lograge"
  
  # Health checks
  gem "health_check"
end
