class NaturalLanguageParsingService
  class << self
    # Main method to parse natural language instructions into seating rules
    def parse_instruction(instruction_text, seating_event, user)
      # Create the NaturalLanguageInstruction record
      nl_instruction = NaturalLanguageInstruction.create!(
        seating_event: seating_event,
        instruction_text: instruction_text,
        created_by: user,
        parsing_status: 'pending'
      )

      begin
        # Mark as processing
        nl_instruction.mark_as_processing!

        # Get available attributes for context
        cohort_attributes = get_cohort_attributes(seating_event.cohort)
        
        # Parse the instruction using GPT-5
        parsing_result = parse_with_ai(instruction_text, cohort_attributes)
        
        # Validate the parsing result
        validate_parsing_result!(parsing_result)
        
        # Extract confidence score
        confidence = extract_confidence_score(parsing_result)
        
        # Create seating rules from parsed result
        seating_rules = create_seating_rules(parsing_result, seating_event, nl_instruction)
        
        # Mark instruction as completed
        nl_instruction.mark_as_completed!(
          seating_rules.map(&:attributes),
          parsing_result,
          confidence
        )

        {
          success: true,
          instruction: nl_instruction,
          rules: seating_rules,
          confidence: confidence
        }

      rescue => e
        Rails.logger.error "NaturalLanguageParsingService error: #{e.message}"
        nl_instruction.mark_as_failed!(e.message)
        
        {
          success: false,
          instruction: nl_instruction,
          error: e.message
        }
      end
    end

    # Parse multiple instructions at once
    def parse_batch(instruction_texts, seating_event, user)
      results = []
      
      instruction_texts.each do |text|
        result = parse_instruction(text, seating_event, user)
        results << result
        
        # Small delay to avoid rate limiting
        sleep(0.5) unless text == instruction_texts.last
      end
      
      results
    end

    # Preview parsing without creating records
    def preview_parsing(instruction_text, seating_event)
      cohort_attributes = get_cohort_attributes(seating_event.cohort)
      
      begin
        parsing_result = parse_with_ai(instruction_text, cohort_attributes)
        confidence = extract_confidence_score(parsing_result)
        
        {
          success: true,
          interpretation: parsing_result,
          confidence: confidence,
          rule_count: parsing_result.dig('rules')&.length || 0
        }
      rescue => e
        {
          success: false,
          error: e.message
        }
      end
    end

    private

    def get_cohort_attributes(cohort)
      students = cohort.students.limit(100) # Sample for attribute discovery
      
      # Get available custom attributes
      custom_attrs = students.map { |s| s.student_attributes&.keys || [] }.flatten.uniq
      
      # Get available inference fields
      inference_fields = students.map { |s| s.inferences&.keys || [] }.flatten.uniq
      
      # Get sample values for each field
      attribute_info = {}
      
      (custom_attrs + inference_fields).uniq.each do |field|
        values = students.map do |s|
          s.get_attribute(field) || s.get_inference_value(field)
        end.compact.uniq.first(10)
        
        attribute_info[field] = values if values.any?
      end
      
      {
        total_students: cohort.students.count,
        attributes: attribute_info,
        common_fields: %w[organization location title gender agency_level department_type seniority_level]
      }
    end

    def parse_with_ai(instruction_text, cohort_attributes)
      prompt = build_parsing_prompt(instruction_text, cohort_attributes)
      
      response = OpenaiService.call(
        prompt,
        purpose: "natural_language_parsing",
        user: nil, # System call
        model_override: 'gpt-5' # Force GPT-5 for parsing
      )

      # Parse the JSON response
      JSON.parse(response)
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse AI response: #{response}"
      raise "AI returned invalid JSON: #{e.message}"
    end

    def build_parsing_prompt(instruction_text, cohort_attributes)
      <<~PROMPT
        You are a seating arrangement expert. Parse this natural language instruction into structured seating rules.

        INSTRUCTION: "#{instruction_text}"

        CONTEXT:
        - Total students: #{cohort_attributes[:total_students]}
        - Available attributes: #{cohort_attributes[:attributes].keys.join(', ')}
        - Common fields: #{cohort_attributes[:common_fields].join(', ')}
        - Sample attribute values: #{cohort_attributes[:attributes].map { |k, v| "#{k}: #{v.first(3).join(', ')}" }.join('; ')}

        RULE TYPES:
        1. separation: Keep specified groups/individuals apart
        2. clustering: Group similar people together  
        3. distribution: Spread people evenly across tables
        4. proximity: Place people near or far from others
        5. custom: Complex rules with specific constraints

        OUTPUT FORMAT (JSON):
        {
          "confidence": 0.95,
          "interpretation": "Brief explanation of what you understood",
          "rules": [
            {
              "rule_type": "separation|clustering|distribution|proximity|custom",
              "description": "Clear description of this specific rule",
              "target_attributes": {
                "field_name": ["value1", "value2"]
              },
              "constraints": {
                "min_distance": 1,
                "max_per_table": 2,
                "distribution_strategy": "even",
                "custom_logic": "any additional constraints"
              },
              "priority": 1
            }
          ],
          "examples": ["Example of who this applies to", "Another example"]
        }

        GUIDELINES:
        - Be specific about which attributes to use
        - Set appropriate constraints for the rule type
        - Use available attribute values from the context
        - Set confidence based on clarity of instruction
        - Higher priority = more important rule (1 is highest)
        - For separation rules, set min_distance >= 1
        - For clustering rules, specify grouping criteria
        - For distribution rules, specify distribution_strategy
        - If instruction is unclear, set confidence < 0.7 and explain why

        Parse the instruction now:
      PROMPT
    end

    def validate_parsing_result!(result)
      raise "Missing confidence score" unless result['confidence'].present?
      raise "Missing rules array" unless result['rules'].is_a?(Array)
      raise "No rules generated" if result['rules'].empty?
      
      result['rules'].each_with_index do |rule, index|
        raise "Rule #{index + 1} missing rule_type" unless rule['rule_type'].present?
        raise "Rule #{index + 1} has invalid rule_type" unless SeatingRule::RULE_TYPES.include?(rule['rule_type'])
        raise "Rule #{index + 1} missing description" unless rule['description'].present?
      end
    end

    def extract_confidence_score(result)
      confidence = result['confidence'].to_f
      confidence.clamp(0.0, 1.0)
    end

    def create_seating_rules(parsing_result, seating_event, nl_instruction)
      rules = []
      
      parsing_result['rules'].each_with_index do |rule_data, index|
        rule = SeatingRule.create!(
          seating_event: seating_event,
          rule_type: rule_data['rule_type'],
          natural_language_input: nl_instruction.instruction_text,
          parsed_rule: rule_data,
          confidence_score: parsing_result['confidence'].to_f,
          target_attributes: rule_data['target_attributes'] || {},
          constraints: rule_data['constraints'] || {},
          priority: rule_data['priority'] || (index + 1),
          active: true
        )
        
        rules << rule
      end
      
      rules
    end

    # Common parsing patterns for quick templates  
    def get_common_patterns
      [
        {
          pattern: "Keep all {group} at different tables",
          example: "Keep all FBI agents at different tables",
          rule_type: "separation"
        },
        {
          pattern: "Group {attribute} together",
          example: "Group all California agencies together",
          rule_type: "clustering"
        },
        {
          pattern: "Spread {group} evenly",
          example: "Spread military personnel evenly",
          rule_type: "distribution"
        },
        {
          pattern: "Place {group1} near {group2}",
          example: "Place new students near experienced ones",
          rule_type: "proximity"
        },
        {
          pattern: "Separate people from the same {attribute}",
          example: "Separate people from the same agency",
          rule_type: "separation"
        },
        {
          pattern: "Ensure each table has mix of {attribute}",
          example: "Ensure each table has mix of federal, state, and local",
          rule_type: "distribution"
        }
      ]
    end
  end
end