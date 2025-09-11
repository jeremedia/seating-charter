require_relative 'config/environment'

# Simplified model for testing
class SimpleStudent < OpenAI::BaseModel
  required :name, String
  required :title, String, nil?: true
  required :organization, String, nil?: true
  required :gender, String, nil?: true  # Just gender for now
end

class SimpleRoster < OpenAI::BaseModel
  required :students, OpenAI::ArrayOf[SimpleStudent]
end

puts "Testing with gpt-5-nano (fastest variant)..."
client = OpenAI::Client.new(api_key: ENV['OPENAI_API_KEY'])

prompt = "Extract students and infer gender:\n\nJohn Smith - Manager - FEMA\nSarah Johnson - Director - FBI"

begin
  start = Time.now
  
  response = client.responses.create(
    model: 'gpt-5-nano',  # Fastest GPT-5 variant
    input: [
      { role: 'system', content: 'Extract student info and infer gender from first names.' },
      { role: 'user', content: prompt }
    ],
    text: SimpleRoster
  )
  
  duration = Time.now - start
  
  # Parse response
  message_output = response.output.find { |item| item.is_a?(OpenAI::Models::Responses::ResponseOutputMessage) }
  if message_output
    content = message_output.content.first
    data = content.parsed
    
    puts "\n✅ Success in #{duration.round(2)} seconds!"
    puts "Students found: #{data.students.size}"
    
    data.students.each do |s|
      puts "\n#{s.name}"
      puts "  Title: #{s.title}"
      puts "  Organization: #{s.organization}"  
      puts "  Gender: #{s.gender || 'not inferred'}"
    end
  end
  
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(3)
end