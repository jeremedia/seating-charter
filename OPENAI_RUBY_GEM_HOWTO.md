# OpenAI Ruby Gem Structured Outputs HOWTO

This comprehensive guide is based on the official OpenAI Ruby gem (v0.22.0) examples and documentation for implementing structured outputs properly.

## 🎯 Critical Insights from Official Examples

### Two Main API Patterns

The official OpenAI Ruby gem provides two different approaches for structured outputs:

1. **Responses API** (Recommended for new projects)
2. **Chat Completions API** (Traditional approach)

## 📋 Pattern 1: Responses API (Recommended)

### Basic Setup

```ruby
require 'openai'

# Define BaseModel classes
class Student < OpenAI::BaseModel
  required :name, String
  required :title, String, nil?: true
  required :organization, String, nil?: true
  required :location, String, nil?: true
  required :additional_info, String, nil?: true
end

class StudentRoster < OpenAI::BaseModel
  required :students, OpenAI::ArrayOf[Student]
  required :total_count, Integer, nil?: true
  required :cohort_name, String, nil?: true
end

# Initialize client
client = OpenAI::Client.new(api_key: ENV['OPENAI_API_KEY'])
```

### Making the API Call

```ruby
response = client.responses.create(
  model: "gpt-5",  # Use GPT-5 as requested
  input: [
    { role: "system", content: "You are an expert at extracting student information..." },
    { role: "user", content: "Extract students from this text: #{text_content}" }
  ],
  text: StudentRoster  # Pass the BaseModel class directly
)
```

### Parsing the Response (CRITICAL!)

```ruby
# The correct way to parse structured outputs from responses API
response
  .output
  .flat_map { _1.content }
  .grep_v(OpenAI::Models::Responses::ResponseOutputRefusal)  # Filter out refusals
  .each do |content|
    # content.parsed is an instance of your BaseModel class
    structured_data = content.parsed  # This is a StudentRoster instance
    puts structured_data.students.map(&:name)
  end

# For single response, you can also do:
first_content = response.output.first.content.first
if !first_content.is_a?(OpenAI::Models::Responses::ResponseOutputRefusal)
  structured_data = first_content.parsed
  # Use structured_data as your StudentRoster instance
end
```

### Streaming Support

```ruby
stream = client.responses.stream(
  input: "Extract student info from this document...",
  model: "gpt-5",
  text: StudentRoster
)

stream.each do |event|
  case event
  when OpenAI::Streaming::ResponseTextDeltaEvent
    print(event.delta)  # Progressive output
  when OpenAI::Streaming::ResponseTextDoneEvent
    puts
    puts("--- Parsed object ---")
    pp(event.parsed)  # Final structured object
  end
end

# Get final response after streaming
final_response = stream.get_final_response
```

## 📋 Pattern 2: Chat Completions API (Traditional)

### API Call

```ruby
chat_completion = client.chat.completions.create(
  model: "gpt-5",
  messages: [
    { role: "system", content: "Extract student information..." },
    { role: "user", content: text_content }
  ],
  response_format: StudentRoster  # Use response_format instead of text
)
```

### Parsing the Response

```ruby
chat_completion
  .choices
  .reject { _1.message.refusal }  # Filter out refusals
  .each do |choice|
    # choice.message.parsed is your structured object
    structured_data = choice.message.parsed
    puts structured_data.students.size
  end
```

## 🏗️ BaseModel Class Definitions

### Basic Types

```ruby
class Student < OpenAI::BaseModel
  required :name, String                    # Required string
  required :age, Integer, nil?: true        # Optional integer
  required :is_active, OpenAI::Boolean      # Boolean type
  required :score, Float, nil?: true        # Optional float
end
```

### Arrays and Collections

```ruby
class Roster < OpenAI::BaseModel
  required :students, OpenAI::ArrayOf[Student]                    # Array of objects
  required :tags, OpenAI::ArrayOf[String], nil?: true            # Optional array of strings
  required :optional_students, 
           OpenAI::ArrayOf[Student, doc: "who might not show up"], 
           nil?: true                                             # With documentation
end
```

### Enums

```ruby
class StudentAnalysis < OpenAI::BaseModel
  required :status, OpenAI::EnumOf[:active, :inactive, :pending]   # String enum
  required :level, OpenAI::EnumOf[:beginner, :intermediate, :advanced]
end
```

### Unions (Multiple Types)

```ruby
class FlexibleStudent < OpenAI::BaseModel
  required :identifier, OpenAI::UnionOf[String, Integer]          # Either string or int
  required :location, OpenAI::UnionOf[String, Location], nil?: true  # String or complex object
end
```

### Nested Objects

```ruby
class Location < OpenAI::BaseModel
  required :address, String
  required :city, String, doc: "City name"
  required :postal_code, String, nil?: true
end

class Student < OpenAI::BaseModel
  required :name, String
  required :location, Location, nil?: true  # Nested object
end
```

### Documentation

```ruby
class WellDocumentedStudent < OpenAI::BaseModel
  required :name, String, doc: "Full name of the student"
  required :department, String, 
           doc: "Academic department or agency affiliation"
  required :confidence_scores, 
           OpenAI::ArrayOf[Float], 
           nil?: true,
           doc: "Array of confidence scores for various inferences"
end
```

## ⚠️ Common Mistakes and Fixes

### 1. Wrong Response Parsing

❌ **Wrong:**
```ruby
# This doesn't work with responses API
structured_data = response.parsed
```

✅ **Correct:**
```ruby
# Must use the chain: output -> flat_map -> content -> parsed
structured_data = response.output.first.content.first.parsed
```

### 2. Optional Fields Syntax

❌ **Wrong:**
```ruby
class Student < OpenAI::BaseModel
  optional :title, String  # This doesn't exist
end
```

✅ **Correct:**
```ruby
class Student < OpenAI::BaseModel
  required :title, String, nil?: true  # This is how you make it optional
end
```

### 3. Model Naming Conflicts

❌ **Wrong:**
```ruby
class Student < OpenAI::BaseModel  # Conflicts with Rails Student model
end
```

✅ **Correct:**
```ruby
class OpenAIStudent < OpenAI::BaseModel  # Use prefixed names
end
```

### 4. Array Definition

❌ **Wrong:**
```ruby
required :students, Array[Student]  # Regular Ruby array
```

✅ **Correct:**
```ruby
required :students, OpenAI::ArrayOf[Student]  # OpenAI array wrapper
```

## 🚀 Function Calling with Structured Outputs

```ruby
class GetWeather < OpenAI::BaseModel
  required :location, String, doc: "City and country e.g. Bogotá, Colombia"
  required :units, OpenAI::EnumOf[:celsius, :fahrenheit], nil?: true
end

response = client.responses.create(
  model: "gpt-5",
  input: [{ role: :user, content: "What's the weather in Paris?" }],
  tools: [GetWeather]  # Pass BaseModel as function definition
)

response.output.each do |output|
  weather_request = output.parsed  # Instance of GetWeather
  puts "Location: #{weather_request.location}"
  puts "Units: #{weather_request.units}"
end
```

## 🔍 Error Handling and Refusals

```ruby
response = client.responses.create(
  model: "gpt-5",
  input: [
    { role: "system", content: "Extract information..." },
    { role: "user", content: text_content }
  ],
  text: StudentRoster
)

response.output.flat_map { _1.content }.each do |content|
  case content
  when OpenAI::Models::Responses::ResponseOutputRefusal
    puts "AI refused to process: #{content.refusal}"
  else
    structured_data = content.parsed
    # Process your structured data
    puts "Found #{structured_data.students.size} students"
  end
end
```

## 📊 Usage Tracking and Costs

```ruby
response = client.responses.create(
  model: "gpt-5",
  input: [...],
  text: StudentRoster
)

# Access usage information
usage = response.usage
puts "Input tokens: #{usage.prompt_tokens}"
puts "Output tokens: #{usage.completion_tokens}"
puts "Total tokens: #{usage.total_tokens}"

# Calculate costs (GPT-5 pricing example)
input_cost = (usage.prompt_tokens / 1000.0) * 0.01
output_cost = (usage.completion_tokens / 1000.0) * 0.02
total_cost = input_cost + output_cost
```

## 🎯 Best Practices for Our CHDS Application

### 1. Service Class Structure

```ruby
class OpenaiServiceV2
  def self.extract_student_roster(text_content, user: nil)
    client = OpenAI::Client.new(api_key: ENV['OPENAI_API_KEY'])
    
    response = client.responses.create(
      model: 'gpt-5',
      input: [
        { role: "system", content: "You are an expert at extracting student information..." },
        { role: "user", content: build_extraction_prompt(text_content) }
      ],
      text: OpenAIStudentRoster
    )
    
    # Parse structured response correctly
    content = response.output.first.content.first
    if content.is_a?(OpenAI::Models::Responses::ResponseOutputRefusal)
      return { success: false, error: "AI refused to process", students: [] }
    end
    
    structured_data = content.parsed
    
    {
      success: true,
      students: structured_data.students.map(&:to_h),
      total_count: structured_data.total_count,
      cohort_name: structured_data.cohort_name
    }
  rescue StandardError => e
    { success: false, error: e.message, students: [] }
  end
end
```

### 2. Model Definitions for CHDS

```ruby
# app/services/openai_models.rb
class OpenAIStudent < OpenAI::BaseModel
  required :name, String
  required :title, String, nil?: true
  required :organization, String, nil?: true
  required :location, String, nil?: true
  required :additional_info, String, nil?: true
end

class OpenAIStudentRoster < OpenAI::BaseModel
  required :students, OpenAI::ArrayOf[OpenAIStudent]
  required :total_count, Integer, nil?: true
  required :cohort_name, String, nil?: true
end

class OpenAIStudentAttribute < OpenAI::BaseModel
  required :confidence, Float  # 0.0 to 1.0
  required :value, String
  required :reasoning, String, nil?: true
end

class OpenAIStudentAnalysis < OpenAI::BaseModel
  required :name, String
  required :gender, OpenAIStudentAttribute, nil?: true
  required :agency_level, OpenAIStudentAttribute, nil?: true
  required :department_type, OpenAIStudentAttribute, nil?: true
  required :seniority_level, OpenAIStudentAttribute, nil?: true
end
```

## 🔥 Key Takeaways

1. **Always use `response.output.flat_map { _1.content }` for responses API parsing**
2. **Filter out refusals with `.grep_v(OpenAI::Models::Responses::ResponseOutputRefusal)`**
3. **Use `required :field, Type, nil?: true` for optional fields**
4. **Prefix model names to avoid conflicts with Rails models**
5. **Use `OpenAI::ArrayOf[Type]` not regular Ruby arrays**
6. **Use `OpenAI::EnumOf[:value1, :value2]` for string enums**
7. **Always handle refusals and errors gracefully**
8. **Access structured data with `.parsed` on the content object**

## 📞 Testing Your Implementation

```ruby
# Quick test in Rails console
client = OpenAI::Client.new(api_key: ENV['OPENAI_API_KEY'])

response = client.responses.create(
  model: 'gpt-5',
  input: [
    { role: "user", content: "Extract: John Smith - Fire Chief - LAFD" }
  ],
  text: OpenAIStudentRoster
)

content = response.output.first.content.first
if !content.is_a?(OpenAI::Models::Responses::ResponseOutputRefusal)
  pp content.parsed.students.first.name  # Should print "John Smith"
end
```

This guide is based on the official OpenAI Ruby gem v0.22.0 examples and should be the definitive reference for implementing structured outputs in our CHDS seating charter application.