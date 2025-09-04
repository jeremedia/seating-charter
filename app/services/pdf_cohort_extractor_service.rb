class PdfCohortExtractorService
  include HTTParty
  
  class << self
    # Extract cohort metadata from PDF
    def extract_cohort_metadata(file_path, user: nil)
      raise "File not found: #{file_path}" unless File.exist?(file_path)
      
      begin
        # Extract text from PDF
        text_content = extract_pdf_text(file_path)
        
        # Extract metadata using AI
        metadata = extract_metadata_with_ai(text_content, user: user)
        
        # Get student data using existing AiRosterParser logic
        students_data = extract_students_preview(text_content, user: user)
        
        {
          success: true,
          metadata: metadata,
          students_preview: students_data,
          raw_text: text_content.first(500) + "..." # First 500 chars for debugging
        }
        
      rescue StandardError => e
        Rails.logger.error "Error extracting PDF metadata: #{e.message}"
        {
          success: false,
          error: e.message,
          metadata: default_metadata
        }
      end
    end
    
    # Extract just cohort metadata for form pre-filling
    def extract_metadata_with_ai(text_content, user: nil)
      prompt = build_metadata_extraction_prompt(text_content)
      
      begin
        response = OpenaiService.call(
          prompt,
          purpose: 'cohort_metadata_extraction',
          user: user
        )
        
        parse_metadata_response(response)
        
      rescue StandardError => e
        Rails.logger.error "Error with AI metadata extraction: #{e.message}"
        default_metadata
      end
    end
    
    # Get a preview of students without creating records
    def extract_students_preview(text_content, user: nil, limit: 5)
      # Reuse the existing AiRosterParser logic but don't create records
      prompt = build_student_preview_prompt(text_content, limit)
      
      begin
        response = OpenaiService.call(
          prompt,
          purpose: 'roster_preview',
          user: user
        )
        
        students_data = parse_students_response(response)
        
        {
          count: students_data.size,
          sample: students_data.first(limit),
          estimated_total: estimate_total_students(text_content)
        }
        
      rescue StandardError => e
        Rails.logger.error "Error extracting students preview: #{e.message}"
        {
          count: 0,
          sample: [],
          estimated_total: 0
        }
      end
    end
    
    private
    
    def extract_pdf_text(file_path)
      reader = PDF::Reader.new(file_path)
      text_content = ""
      
      reader.pages.each do |page|
        text_content += page.text + "\n\n"
      end
      
      # Clean up the extracted text
      clean_extracted_text(text_content)
    end
    
    def clean_extracted_text(text)
      # Remove excessive whitespace and clean up common PDF extraction issues
      text.gsub(/\s+/, ' ')
          .gsub(/[^\w\s@.-]/, ' ')
          .squeeze(' ')
          .strip
    end
    
    def build_metadata_extraction_prompt(text_content)
      <<~PROMPT
        Please extract cohort/class information from the following PDF text. Look for:
        - Cohort/class name or title
        - Course dates (start and end dates)
        - Location information
        - Program name or description
        - Academic term/session information
        
        Return the information in this JSON format:
        {
          "name": "Cohort or class name",
          "description": "Brief description or program name",
          "start_date": "YYYY-MM-DD format if found",
          "end_date": "YYYY-MM-DD format if found",
          "location": "Location if mentioned",
          "confidence": {
            "name": 0.9,
            "dates": 0.7,
            "location": 0.5
          },
          "raw_dates": ["any date strings found"]
        }
        
        Important guidelines:
        - Use null for fields that cannot be determined
        - Confidence should be 0.0-1.0 based on how certain you are
        - Look for common date patterns like "January 15, 2025 - March 15, 2025"
        - Include partial information with lower confidence if uncertain
        - For name, look for course titles, cohort names, or class identifiers
        
        Text to analyze:
        #{text_content.first(2000)}
        
        Respond with valid JSON only.
      PROMPT
    end
    
    def build_student_preview_prompt(text_content, limit)
      <<~PROMPT
        Please extract the first #{limit} students from this roster text. Look for patterns that indicate student records with names, titles, organizations, etc.
        
        Return in this JSON format:
        {
          "students": [
            {
              "name": "Full Name",
              "title": "Job Title or null",
              "organization": "Agency/Organization or null",
              "location": "City, State or null"
            }
          ],
          "estimated_total": "your best estimate of total students in the document"
        }
        
        Guidelines:
        - Only include clear student entries
        - Limit to exactly #{limit} students for preview
        - Estimate total based on patterns you see
        - Use null for missing information
        
        Text to analyze:
        #{text_content.first(3000)}
        
        Respond with valid JSON only.
      PROMPT
    end
    
    def parse_metadata_response(response)
      json_text = response.strip.gsub(/```json\n?/, '').gsub(/```\n?/, '')
      
      begin
        parsed = JSON.parse(json_text)
        
        # Clean and validate the data
        {
          name: parsed['name']&.strip&.presence,
          description: parsed['description']&.strip&.presence,
          start_date: parse_date(parsed['start_date']),
          end_date: parse_date(parsed['end_date']),
          location: parsed['location']&.strip&.presence,
          confidence: parsed['confidence'] || {},
          raw_dates: parsed['raw_dates'] || [],
          suggested_max_students: estimate_max_students(parsed)
        }
        
      rescue JSON::ParserError => e
        Rails.logger.error "Failed to parse metadata response: #{e.message}"
        default_metadata
      end
    end
    
    def parse_students_response(response)
      json_text = response.strip.gsub(/```json\n?/, '').gsub(/```\n?/, '')
      
      begin
        parsed = JSON.parse(json_text)
        students = parsed['students'] || []
        
        students.select do |student|
          student['name'].present? && student['name'].length > 2
        end.map do |student|
          {
            name: student['name']&.strip&.titleize,
            title: student['title']&.strip,
            organization: student['organization']&.strip,
            location: student['location']&.strip
          }.compact
        end
        
      rescue JSON::ParserError => e
        Rails.logger.error "Failed to parse students response: #{e.message}"
        []
      end
    end
    
    def parse_date(date_string)
      return nil if date_string.blank?
      
      begin
        # Try to parse various date formats
        if date_string.match(/^\d{4}-\d{2}-\d{2}$/)
          Date.parse(date_string)
        else
          Date.parse(date_string) rescue nil
        end
      rescue
        nil
      end
    end
    
    def estimate_total_students(text)
      # Simple heuristic to estimate student count
      # Count occurrences of common patterns
      lines = text.split("\n")
      
      # Look for numbered lists, bullet points, or name patterns
      student_patterns = [
        /^\d+\.\s+[A-Z][a-z]+\s+[A-Z][a-z]+/,  # "1. John Smith"
        /^[A-Z][a-z]+\s+[A-Z][a-z]+\s+-\s+/,    # "John Smith - Title"
        /^[A-Z][a-z]+,\s+[A-Z][a-z]+/           # "Smith, John"
      ]
      
      count = 0
      lines.each do |line|
        student_patterns.each do |pattern|
          if line.strip.match(pattern)
            count += 1
            break
          end
        end
      end
      
      # If we found patterns, use that count, otherwise estimate based on text length
      count > 0 ? count : [text.length / 200, 40].min
    end
    
    def estimate_max_students(parsed_data)
      # Try to suggest a reasonable max_students based on what we found
      estimated = parsed_data.dig('estimated_total') || 25
      
      # Round up to nearest 5, cap at 40
      rounded = ((estimated.to_f / 5).ceil * 5)
      [rounded, 40].min
    end
    
    def default_metadata
      {
        name: nil,
        description: nil,
        start_date: nil,
        end_date: nil,
        location: nil,
        confidence: { name: 0.0, dates: 0.0, location: 0.0 },
        raw_dates: [],
        suggested_max_students: 25
      }
    end
  end
end