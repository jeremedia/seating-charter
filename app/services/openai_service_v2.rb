# Load the OpenAI BaseModel classes
require_relative 'openai_models'

# Modernized OpenAI Service using the official OpenAI gem with structured outputs
# Always uses GPT-5 as requested
class OpenaiServiceV2
  class << self
    def initialize_client
      @client ||= OpenAI::Client.new(api_key: ENV['OPENAI_API_KEY'])
    end

    # Extract student roster data using structured outputs - ALWAYS GPT-5
    def extract_student_roster(text_content, purpose: 'roster_parsing', user: nil)
      config = get_active_configuration
      raise "No active AI configuration found" unless config

      client = initialize_client
      request_id = generate_request_id
      
      # Build the extraction prompt
      prompt = build_roster_extraction_prompt(text_content)
      
      begin
        response = client.responses.create(
          model: 'gpt-5-nano', # Using fastest GPT-5 variant for better performance
          input: [
            { role: "system", content: "You are an expert at extracting student information from educational rosters. Extract all student names and infer demographic attributes. For gender, always choose 'male', 'female', or 'unsure' based on the first name. Always provide confidence scores between 0.0 and 1.0." },
            { role: "user", content: prompt }
          ],
          text: OpenAIStudentRoster # Use structured output
        )

        # Track costs
        track_cost(
          user: user,
          request_id: request_id,
          model: 'gpt-5',
          response: response,
          purpose: purpose,
          config: config
        )

        # Parse structured response for GPT-5 (handles reasoning + output)
        message_output = response.output.find { |item| item.is_a?(OpenAI::Models::Responses::ResponseOutputMessage) }
        return { success: false, error: "No message output found in response", students: [] } unless message_output
        
        content = message_output.content.first
        
        # Check if AI refused to process
        if content.is_a?(OpenAI::Models::Responses::ResponseOutputRefusal)
          return { success: false, error: "AI refused to process: #{content.refusal}", students: [] }
        end
        
        # Extract structured data
        structured_data = content.parsed
        
        {
          success: true,
          students: structured_data.students.map(&:to_h),
          total_count: structured_data.total_count,
          cohort_name: structured_data.cohort_name
        }
        
      rescue StandardError => e
        Rails.logger.error "OpenAI structured extraction error: #{e.message}"
        { success: false, error: e.message, students: [] }
      end
    end

    # Extract student roster from uploaded file using file API - ALWAYS GPT-5
    def extract_roster_from_file(file_path, purpose: 'roster_parsing', user: nil)
      config = get_active_configuration
      raise "No active AI configuration found" unless config

      client = initialize_client
      request_id = generate_request_id

      begin
        # For now, fall back to text extraction since file API needs more research
        # Extract text from file and process with structured outputs
        text_content = case File.extname(file_path).downcase
                      when '.pdf'
                        extract_pdf_text(file_path)
                      else
                        File.read(file_path)
                      end

        response = client.responses.create(
          model: 'gpt-5-nano', # Using fastest GPT-5 variant for better performance
          input: [
            {
              role: "system",
              content: "You are an expert at extracting student information from educational documents. Extract all student names and infer demographic attributes. For gender, always choose 'male', 'female', or 'unsure' based on the first name. Always provide confidence scores between 0.0 and 1.0."
            },
            {
              role: "user", 
              content: "Please extract all student information from this document. Include names, titles, organizations, locations, and any additional information about each student.\n\nDocument content:\n#{text_content}"
            }
          ],
          text: OpenAIStudentRoster # Use structured output
        )

        # Track costs
        track_cost(
          user: user,
          request_id: request_id,
          model: 'gpt-5',
          response: response,
          purpose: purpose,
          config: config
        )

        # No file cleanup needed for text-based approach

        # Parse structured response for GPT-5 (handles reasoning + output)
        message_output = response.output.find { |item| item.is_a?(OpenAI::Models::Responses::ResponseOutputMessage) }
        return { success: false, error: "No message output found in response", students: [] } unless message_output
        
        content = message_output.content.first
        
        # Check if AI refused to process
        if content.is_a?(OpenAI::Models::Responses::ResponseOutputRefusal)
          return { success: false, error: "AI refused to process: #{content.refusal}", students: [] }
        end
        
        # Extract structured data
        structured_data = content.parsed
        
        {
          success: true,
          students: structured_data.students.map(&:to_h),
          total_count: structured_data.total_count,
          cohort_name: structured_data.cohort_name
        }

      rescue StandardError => e
        Rails.logger.error "OpenAI file extraction error: #{e.message}"
        # No file cleanup needed for text-based approach
        { success: false, error: e.message, students: [] }
      end
    end

    # Analyze student attributes using structured outputs - ALWAYS GPT-5
    def analyze_student_attributes(student_name, title: nil, organization: nil, user: nil)
      config = get_active_configuration
      raise "No active AI configuration found" unless config

      client = initialize_client
      request_id = generate_request_id

      # Build analysis prompt
      prompt = build_attribute_analysis_prompt(student_name, title, organization)

      begin
        response = client.responses.create(
          model: 'gpt-5-nano', # Using fastest GPT-5 variant for better performance
          input: [
            { role: "system", content: "You are an expert at inferring demographic and professional attributes from names and job information. Provide confidence scores for your inferences." },
            { role: "user", content: prompt }
          ],
          text: OpenAIStudentAnalysis # Use structured output
        )

        # Track costs
        track_cost(
          user: user,
          request_id: request_id,
          model: 'gpt-5',
          response: response,
          purpose: 'attribute_analysis',
          config: config
        )

        # Parse structured response for GPT-5 (handles reasoning + output)
        message_output = response.output.find { |item| item.is_a?(OpenAI::Models::Responses::ResponseOutputMessage) }
        return { name: student_name, error: "No message output found in response" } unless message_output
        
        content = message_output.content.first
        
        # Check if AI refused to process
        if content.is_a?(OpenAI::Models::Responses::ResponseOutputRefusal)
          return { name: student_name, error: "AI refused to process: #{content.refusal}" }
        end
        
        # Return structured analysis
        content.parsed.to_h

      rescue StandardError => e
        Rails.logger.error "OpenAI attribute analysis error: #{e.message}"
        { name: student_name, error: e.message }
      end
    end

    # Test the new structured interface - ALWAYS GPT-5
    def test_structured_interface(sample_text = nil, user: nil)
      sample_text ||= """
      John Smith - Emergency Manager - FEMA
      Sarah Johnson - Fire Chief - Los Angeles Fire Department  
      Mike Davis - Police Captain - NYPD
      """

      begin
        result = extract_student_roster(
          sample_text,
          purpose: "test_structured_interface",
          user: user
        )
        
        {
          success: result[:success],
          students_found: result[:students]&.size || 0,
          sample_student: result[:students]&.first,
          timestamp: Time.current,
          model_used: 'gpt-5-nano'
        }
      rescue StandardError => e
        {
          success: false,
          error: e.message,
          timestamp: Time.current,
          model_used: 'gpt-5-nano'
        }
      end
    end

    private

    def build_roster_extraction_prompt(text_content)
      <<~PROMPT
        Please extract all student information from the following text. This appears to be from an educational roster or class list.

        For each student, extract:
        - Full name (required)
        - Job title or position (if available)
        - Organization/agency (if available) 
        - Location (if available)
        - Any additional relevant information
        
        ALSO, for each student, infer the following attributes based on their name, title, and organization:
        - Gender (male/female/unsure) with confidence score (0.0 to 1.0)
        - Agency level (federal/state/local/private/unsure) with confidence score
        - Department type (emergency_management/fire/police/medical/other/unsure) with confidence score
        - Seniority level (entry/mid/senior/executive/unsure) with confidence score
        
        Be conservative with confidence scores. Only use high confidence (>0.7) when quite certain.

        Text to analyze:
        #{text_content}

        Extract all students you can identify, even if some information is missing for certain students.
      PROMPT
    end

    def build_attribute_analysis_prompt(student_name, title, organization)
      info_parts = [student_name]
      info_parts << title if title.present?
      info_parts << organization if organization.present?
      combined_info = info_parts.join(" - ")

      <<~PROMPT
        Analyze this student information and infer attributes with confidence scores (0.0 to 1.0):
        
        Student: #{combined_info}
        
        Please analyze and provide:
        1. Gender inference (male/female/unsure) with confidence score
        2. Agency level (federal/state/local/private/unsure) with confidence score  
        3. Department type (emergency_management/fire/police/medical/other/unsure) with confidence score
        4. Seniority level (entry/mid/senior/executive/unsure) with confidence score
        
        Base your inferences on the name, title, and organization. Be conservative with confidence scores.
        Only return high confidence (>0.7) if you're quite certain based on the available information.
      PROMPT
    end

    def get_active_configuration
      @active_config ||= AiConfiguration.find_by(active: true)
    end

    def generate_request_id
      "openai_#{SecureRandom.hex(8)}"
    end

    def track_cost(user:, request_id:, model:, response:, purpose:, config:)
      return unless user

      # Extract usage from new OpenAI gem response structure
      usage = response.respond_to?(:usage) ? response.usage : nil
      return unless usage

      input_tokens = usage.respond_to?(:prompt_tokens) ? usage.prompt_tokens : 0
      output_tokens = usage.respond_to?(:completion_tokens) ? usage.completion_tokens : 0
      
      # Calculate cost for GPT-5
      cost_estimate = calculate_gpt5_cost(input_tokens, output_tokens)
      
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

    def calculate_gpt5_cost(input_tokens, output_tokens)
      # GPT-5 pricing (approximate based on current patterns)
      # Input: ~$0.01 per 1K tokens, Output: ~$0.02 per 1K tokens
      input_cost = (input_tokens / 1000.0) * 0.01
      output_cost = (output_tokens / 1000.0) * 0.02
      (input_cost + output_cost).round(6)
    end

    def extract_pdf_text(file_path)
      begin
        reader = PDF::Reader.new(file_path)
        text_content = ""
        
        reader.pages.each do |page|
          text_content += page.text + "\n"
        end
        
        # Clean up the extracted text
        text_content.gsub(/\s+/, ' ').squeeze(' ').strip
        
      rescue StandardError => e
        Rails.logger.error "Error extracting PDF text: #{e.message}"
        ""
      end
    end
  end
end