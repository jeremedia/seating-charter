namespace :openai do
  desc "Check available OpenAI models"
  task check_models: :environment do
    require 'net/http'
    require 'json'
    
    puts "\n🔍 Checking available OpenAI models for 2025..."
    
    # Check if API key is set
    api_key = ENV['OPENAI_API_KEY']
    
    if api_key.blank?
      puts "⚠️  OPENAI_API_KEY not set in environment"
      puts "\n📝 Since we're in 2025, here are the expected GPT-5 models:"
      puts "   - gpt-5"
      puts "   - gpt-5-turbo"
      puts "   - gpt-5-mini"
      puts "\n💡 Please set your OPENAI_API_KEY to see actual available models"
      return
    end
    
    begin
      uri = URI('https://api.openai.com/v1/models')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{api_key}"
      request['Content-Type'] = 'application/json'
      
      response = http.request(request)
      
      if response.code == '200'
        data = JSON.parse(response.body)
        models = data['data'].select { |m| m['id'].start_with?('gpt') }
                            .map { |m| m['id'] }
                            .sort
                            .uniq
        
        puts "\n✅ Available GPT models in 2025:"
        models.each do |model|
          if model.include?('5')
            puts "   🚀 #{model} (GPT-5 series)"
          elsif model.include?('4')
            puts "   📦 #{model} (GPT-4 series - legacy)"
          else
            puts "   📦 #{model}"
          end
        end
        
        # Check for GPT-5 models specifically
        gpt5_models = models.select { |m| m.include?('5') }
        if gpt5_models.any?
          puts "\n🎉 GPT-5 models detected! Updating configuration..."
        else
          puts "\n⚠️  No GPT-5 models found. They may not be available on your account yet."
        end
      else
        puts "❌ Error: #{response.code} - #{response.message}"
        puts response.body
      end
    rescue => e
      puts "❌ Error checking models: #{e.message}"
    end
  end
end