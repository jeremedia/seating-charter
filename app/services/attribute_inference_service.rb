class AttributeInferenceService
  include HTTParty
  
  class << self
    # Main method to infer attributes for a student
    def infer_attributes(student, user: nil, specific_attributes: nil)
      attributes_to_infer = specific_attributes || ['gender', 'agency_level', 'department_type', 'seniority_level']
      results = {}
      
      attributes_to_infer.each do |attribute|
        case attribute
        when 'gender'
          results[attribute] = infer_gender(student, user: user)
        when 'agency_level'
          results[attribute] = infer_agency_level(student, user: user)
        when 'department_type'
          results[attribute] = infer_department_type(student, user: user)
        when 'seniority_level'
          results[attribute] = infer_seniority_level(student, user: user)
        end
      end
      
      # Apply results to student
      results.each do |attribute, result|
        if result[:success]
          student.set_inference(attribute, result[:value], result[:confidence])
        end
      end
      
      student.save! if results.any? { |_, result| result[:success] }
      
      results
    end
    
    # Batch inference for multiple students
    def batch_infer_attributes(students, user: nil, specific_attributes: nil, progress_callback: nil)
      results = {}
      total_students = students.size
      
      students.each_with_index do |student, index|
        progress_callback&.call("Processing student #{index + 1} of #{total_students}: #{student.name}")
        
        begin
          student_results = infer_attributes(student, user: user, specific_attributes: specific_attributes)
          results[student.id] = {
            success: true,
            student: student,
            results: student_results
          }
        rescue StandardError => e
          results[student.id] = {
            success: false,
            student: student,
            error: e.message
          }
        end
        
        # Small delay to avoid rate limits
        sleep(0.2) if index < total_students - 1
      end
      
      progress_callback&.call("Completed inference for #{total_students} students")
      results
    end
    
    # Gender inference based on first names
    def infer_gender(student, user: nil)
      first_name = extract_first_name(student.name)
      
      return conservative_fallback('gender') if first_name.blank?
      
      # Try rule-based inference first (faster and cheaper)
      rule_based_result = infer_gender_rule_based(first_name)
      if rule_based_result[:confidence] >= 0.8
        return rule_based_result
      end
      
      # Fall back to AI if rule-based is not confident enough
      infer_gender_with_ai(first_name, student, user: user)
    end
    
    # Agency level classification (federal/state/local/military/private)
    def infer_agency_level(student, user: nil)
      return conservative_fallback('agency_level') unless student.organization.present?
      
      # Try rule-based inference first
      rule_based_result = infer_agency_level_rule_based(student.organization)
      if rule_based_result[:confidence] >= 0.8
        return rule_based_result
      end
      
      # Fall back to AI
      infer_agency_level_with_ai(student, user: user)
    end
    
    # Department type detection
    def infer_department_type(student, user: nil)
      return conservative_fallback('department_type') unless student.organization.present? || student.title.present?
      
      # Try rule-based inference first
      rule_based_result = infer_department_type_rule_based(student.organization, student.title)
      if rule_based_result[:confidence] >= 0.8
        return rule_based_result
      end
      
      # Fall back to AI
      infer_department_type_with_ai(student, user: user)
    end
    
    # Seniority level inference
    def infer_seniority_level(student, user: nil)
      return conservative_fallback('seniority_level') unless student.title.present?
      
      # Try rule-based inference first
      rule_based_result = infer_seniority_level_rule_based(student.title)
      if rule_based_result[:confidence] >= 0.8
        return rule_based_result
      end
      
      # Fall back to AI
      infer_seniority_level_with_ai(student, user: user)
    end
    
    private
    
    def extract_first_name(full_name)
      return nil if full_name.blank?
      
      # Handle common name formats
      name_parts = full_name.strip.split(/\s+/)
      first_name = name_parts.first
      
      # Remove titles and prefixes
      prefixes = ['mr', 'mrs', 'ms', 'dr', 'prof', 'rev', 'hon', 'sen', 'rep']
      first_name = name_parts[1] if prefixes.include?(first_name.downcase)
      
      first_name&.gsub(/[^a-zA-Z]/, '')&.capitalize
    end
    
    def infer_gender_rule_based(first_name)
      # Common male names
      male_names = %w[
        John James Robert Michael William David Richard Thomas Christopher Daniel
        Matthew Anthony Mark Donald Steven Paul Andrew Joshua Kenneth Joseph
        Brian Kevin Timothy Ronald Jason Jeffrey Ryan Jacob Gary Nicholas
        Eric Jonathan Stephen Larry Justin Scott Brandon Benjamin Samuel
        Gregory Alexander Patrick Frank Raymond Jack Dennis Jerry Tyler Aaron
        Henry Douglas Peter Zachary Nathan Walter Kyle Harold Carl Arthur
        Gerald Wayne Jordan Billy Ralph Bobby Russell Louis Philip Johnny
        Mason Owen Luis Diego Liam Noah Logan Sebastian Oliver Julian Lucas
      ].map(&:downcase)
      
      # Common female names
      female_names = %w[
        Mary Patricia Jennifer Linda Barbara Elizabeth Maria Susan Margaret
        Dorothy Lisa Nancy Karen Betty Helen Sandra Donna Carol Ruth Sharon
        Michelle Laura Sarah Kimberly Deborah Jessica Shirley Cynthia Angela
        Melissa Brenda Amy Anna Rebecca Virginia Kathleen Pamela Martha Debra
        Amanda Stephanie Carolyn Christine Marie Janet Catherine Frances Ann
        Samantha Debbie Rachel Caroline Emma Olivia Sophia Isabella Ava Mia
        Emily Abigail Madison Charlotte Harper Sofia Avery Elizabeth Ella
      ].map(&:downcase)
      
      name_lower = first_name.downcase
      
      if male_names.include?(name_lower)
        { success: true, value: 'male', confidence: 0.9 }
      elsif female_names.include?(name_lower)
        { success: true, value: 'female', confidence: 0.9 }
      else
        { success: true, value: 'unknown', confidence: 0.3 }
      end
    end
    
    def infer_gender_with_ai(first_name, student, user: nil)
      prompt = build_gender_inference_prompt(first_name, student)
      
      begin
        response = OpenaiService.call(prompt, purpose: 'attribute_inference', user: user)
        parse_inference_response(response, 'gender')
      rescue StandardError => e
        Rails.logger.error "AI gender inference failed: #{e.message}"
        conservative_fallback('gender')
      end
    end
    
    def infer_agency_level_rule_based(organization)
      org_lower = organization.downcase
      
      # Federal indicators
      federal_keywords = [
        'fbi', 'cia', 'nsa', 'dhs', 'ice', 'cbp', 'atf', 'dea', 'usss', 'fema',
        'federal', 'department of', 'bureau of', 'agency', 'administration',
        'service', 'customs', 'immigration', 'homeland security', 'defense',
        'justice', 'treasury', 'state department', 'usda', 'epa'
      ]
      
      # Military indicators
      military_keywords = [
        'army', 'navy', 'air force', 'marines', 'coast guard', 'national guard',
        'military', 'armed forces', 'defense', 'fort', 'base', 'naval', 'marine corps'
      ]
      
      # State indicators
      state_keywords = [
        'state police', 'state bureau', 'state department', 'highway patrol',
        'state fire', 'state emergency', 'governor', 'state of'
      ]
      
      # Local indicators
      local_keywords = [
        'city of', 'county of', 'police department', 'fire department',
        'sheriff', 'municipal', 'metro', 'township'
      ]
      
      if federal_keywords.any? { |keyword| org_lower.include?(keyword) }
        { success: true, value: 'federal', confidence: 0.85 }
      elsif military_keywords.any? { |keyword| org_lower.include?(keyword) }
        { success: true, value: 'military', confidence: 0.85 }
      elsif state_keywords.any? { |keyword| org_lower.include?(keyword) }
        { success: true, value: 'state', confidence: 0.85 }
      elsif local_keywords.any? { |keyword| org_lower.include?(keyword) }
        { success: true, value: 'local', confidence: 0.85 }
      else
        { success: true, value: 'unknown', confidence: 0.3 }
      end
    end
    
    def infer_agency_level_with_ai(student, user: nil)
      prompt = build_agency_level_inference_prompt(student)
      
      begin
        response = OpenaiService.call(prompt, purpose: 'attribute_inference', user: user)
        parse_inference_response(response, 'agency_level')
      rescue StandardError => e
        Rails.logger.error "AI agency level inference failed: #{e.message}"
        conservative_fallback('agency_level')
      end
    end
    
    def infer_department_type_rule_based(organization, title)
      text = "#{organization} #{title}".downcase
      
      # Law enforcement
      if text.match?(/police|sheriff|detective|officer|fbi|atf|dea|marshal|trooper/)
        return { success: true, value: 'law_enforcement', confidence: 0.9 }
      end
      
      # Fire/EMS
      if text.match?(/fire|ems|paramedic|firefighter|rescue/)
        return { success: true, value: 'fire_ems', confidence: 0.9 }
      end
      
      # Emergency Management
      if text.match?(/emergency|disaster|fema|preparedness|response/)
        return { success: true, value: 'emergency_management', confidence: 0.9 }
      end
      
      # Military
      if text.match?(/army|navy|air force|marines|military|colonel|captain|major|sergeant/)
        return { success: true, value: 'military', confidence: 0.9 }
      end
      
      # Intelligence
      if text.match?(/intelligence|analyst|cia|nsa|counterintelligence/)
        return { success: true, value: 'intelligence', confidence: 0.9 }
      end
      
      # Public Health
      if text.match?(/health|medical|cdc|epidemiology|public health/)
        return { success: true, value: 'public_health', confidence: 0.9 }
      end
      
      # Cybersecurity
      if text.match?(/cyber|information security|it security|technology/)
        return { success: true, value: 'cybersecurity', confidence: 0.9 }
      end
      
      { success: true, value: 'unknown', confidence: 0.3 }
    end
    
    def infer_department_type_with_ai(student, user: nil)
      prompt = build_department_type_inference_prompt(student)
      
      begin
        response = OpenaiService.call(prompt, purpose: 'attribute_inference', user: user)
        parse_inference_response(response, 'department_type')
      rescue StandardError => e
        Rails.logger.error "AI department type inference failed: #{e.message}"
        conservative_fallback('department_type')
      end
    end
    
    def infer_seniority_level_rule_based(title)
      title_lower = title.downcase
      
      # Senior/Executive level
      if title_lower.match?(/director|chief|commander|superintendent|assistant secretary|deputy|executive/)
        return { success: true, value: 'senior', confidence: 0.85 }
      end
      
      # Mid-level
      if title_lower.match?(/manager|supervisor|lieutenant|captain|major|coordinator|specialist/)
        return { success: true, value: 'mid_level', confidence: 0.85 }
      end
      
      # Entry/Junior level
      if title_lower.match?(/officer|agent|analyst|technician|deputy|corporal|sergeant/)
        return { success: true, value: 'junior', confidence: 0.85 }
      end
      
      { success: true, value: 'unknown', confidence: 0.3 }
    end
    
    def infer_seniority_level_with_ai(student, user: nil)
      prompt = build_seniority_level_inference_prompt(student)
      
      begin
        response = OpenaiService.call(prompt, purpose: 'attribute_inference', user: user)
        parse_inference_response(response, 'seniority_level')
      rescue StandardError => e
        Rails.logger.error "AI seniority level inference failed: #{e.message}"
        conservative_fallback('seniority_level')
      end
    end
    
    def build_gender_inference_prompt(first_name, student)
      <<~PROMPT
        Please infer the gender based on the first name: "#{first_name}"
        
        Additional context:
        Full name: #{student.name}
        Title: #{student.title}
        
        Respond with only one of: "male", "female", or "unknown" (if uncertain).
        Be conservative - use "unknown" if you're not confident.
      PROMPT
    end
    
    def build_agency_level_inference_prompt(student)
      <<~PROMPT
        Please classify the agency level for this person based on their organization:
        
        Name: #{student.name}
        Organization: #{student.organization}
        Title: #{student.title}
        Location: #{student.location}
        
        Classify as one of:
        - "federal" (US federal government agencies)
        - "state" (state government agencies)
        - "local" (city, county, municipal agencies)
        - "military" (armed forces, military branches)
        - "private" (private sector, contractors)
        - "unknown" (if uncertain)
        
        Be conservative - use "unknown" if you're not confident.
        Respond with only the classification.
      PROMPT
    end
    
    def build_department_type_inference_prompt(student)
      <<~PROMPT
        Please classify the department type for this person:
        
        Name: #{student.name}
        Organization: #{student.organization}
        Title: #{student.title}
        
        Classify as one of:
        - "law_enforcement"
        - "fire_ems"
        - "emergency_management"
        - "military"
        - "intelligence"
        - "public_health"
        - "cybersecurity"
        - "transportation"
        - "homeland_security"
        - "unknown"
        
        Be conservative - use "unknown" if you're not confident.
        Respond with only the classification.
      PROMPT
    end
    
    def build_seniority_level_inference_prompt(student)
      <<~PROMPT
        Please classify the seniority level based on this person's title:
        
        Title: #{student.title}
        Organization: #{student.organization}
        
        Classify as one of:
        - "senior" (director, chief, executive level)
        - "mid_level" (manager, supervisor, middle management)
        - "junior" (officer, agent, entry to mid-level)
        - "unknown" (if uncertain)
        
        Be conservative - use "unknown" if you're not confident.
        Respond with only the classification.
      PROMPT
    end
    
    def parse_inference_response(response, attribute_type)
      value = response.strip.downcase
      
      # Map confidence based on response clarity
      confidence = case value
                   when /unknown/
                     0.3
                   else
                     0.8 # AI responses are generally less confident than rule-based
                   end
      
      { success: true, value: value, confidence: confidence }
    end
    
    def conservative_fallback(attribute_type)
      { success: true, value: 'unknown', confidence: 0.1 }
    end
    
    # Sample data for testing
    def test_with_sample_students(cohort_id, user: nil)
      cohort = Cohort.find(cohort_id)
      
      # Create sample students if none exist
      if cohort.students.empty?
        sample_students = [
          { name: "John Smith", title: "Supervisory Special Agent", organization: "FBI", location: "Washington, DC" },
          { name: "Sarah Johnson", title: "Captain", organization: "U.S. Army", location: "Fort Bragg, NC" },
          { name: "Michael Davis", title: "Emergency Management Director", organization: "City of Phoenix", location: "Phoenix, AZ" },
          { name: "Lisa Chen", title: "Intelligence Analyst", organization: "CIA", location: "Langley, VA" },
          { name: "Robert Wilson", title: "Fire Chief", organization: "Miami-Dade Fire Rescue", location: "Miami, FL" }
        ]
        
        sample_students.each do |student_data|
          cohort.students.create!(student_data)
        end
      end
      
      students = cohort.students.limit(5)
      
      begin
        results = batch_infer_attributes(students, user: user) do |message|
          Rails.logger.info "Sample inference progress: #{message}"
        end
        
        {
          success: true,
          students_processed: students.size,
          results: results,
          message: "Successfully tested attribute inference with sample data"
        }
      rescue StandardError => e
        {
          success: false,
          error: e.message,
          message: "Failed to test with sample data"
        }
      end
    end
  end
end