# Modernized AI Roster Parser using structured outputs - ALWAYS GPT-5
class AiRosterParserV2
  class << self
    # Parse roster from file path using structured outputs
    def parse_roster(file_path, cohort_id, user: nil, progress_callback: nil)
      progress_callback&.call("Starting roster parsing...")
      
      cohort = Cohort.find(cohort_id)
      
      # Determine file type and extract content
      file_extension = File.extname(file_path).downcase
      
      case file_extension
      when '.pdf'
        parse_pdf_roster(file_path, cohort, user: user, progress_callback: progress_callback)
      when '.xlsx', '.xls'
        parse_excel_roster(file_path, cohort, user: user, progress_callback: progress_callback)
      when '.csv'
        parse_csv_roster(file_path, cohort, user: user, progress_callback: progress_callback)
      else
        raise "Unsupported file format: #{file_extension}"
      end
    end

    private

    def parse_pdf_roster(file_path, cohort, user:, progress_callback:)
      progress_callback&.call("Extracting text from PDF...")
      
      # First try direct file upload to OpenAI (best for complex PDFs)
      begin
        result = OpenaiServiceV2.extract_roster_from_file(
          file_path, 
          purpose: 'roster_parsing', 
          user: user
        )
        
        if result[:success] && result[:students].present?
          progress_callback&.call("Creating student records...")
          created_students = create_student_records(result[:students], cohort, user)
          
          return {
            success: true,
            students_created: created_students.size,
            students: created_students,
            message: "Successfully parsed and created #{created_students.size} student records"
          }
        end
      rescue StandardError => e
        Rails.logger.warn "Direct file upload failed, falling back to text extraction: #{e.message}"
      end

      # Fallback: Extract text first, then send to AI
      progress_callback&.call("Converting PDF to text...")
      text_content = extract_pdf_text(file_path)
      
      if text_content.blank?
        raise "Unable to extract readable text from PDF"
      end

      progress_callback&.call("Analyzing content with AI...")
      result = OpenaiServiceV2.extract_student_roster(
        text_content, 
        purpose: 'roster_parsing', 
        user: user
      )

      if result[:success]
        progress_callback&.call("Creating student records...")
        created_students = create_student_records(result[:students], cohort, user)
        
        {
          success: true,
          students_created: created_students.size,
          students: created_students,
          message: "Successfully parsed and created #{created_students.size} student records"
        }
      else
        raise "AI extraction failed: #{result[:error]}"
      end
    end

    def parse_excel_roster(file_path, cohort, user:, progress_callback:)
      progress_callback&.call("Reading Excel file...")
      
      begin
        spreadsheet = Roo::Spreadsheet.open(file_path)
        sheet = spreadsheet.sheet(spreadsheet.sheets.first)
        
        # Convert to text representation
        text_content = ""
        sheet.each_row_streaming do |row|
          row_text = row.map { |cell| cell&.value&.to_s || "" }.join(" | ")
          text_content += row_text + "\n"
        end
        
        progress_callback&.call("Analyzing spreadsheet data with AI...")
        result = OpenaiServiceV2.extract_student_roster(
          text_content, 
          purpose: 'roster_parsing', 
          user: user
        )

        if result[:success]
          progress_callback&.call("Creating student records...")
          created_students = create_student_records(result[:students], cohort, user)
          
          {
            success: true,
            students_created: created_students.size,
            students: created_students,
            message: "Successfully parsed and created #{created_students.size} student records"
          }
        else
          raise "AI extraction failed: #{result[:error]}"
        end
        
      rescue StandardError => e
        Rails.logger.error "Error parsing Excel: #{e.message}"
        raise "Failed to parse spreadsheet: #{e.message}"
      end
    end

    def parse_csv_roster(file_path, cohort, user:, progress_callback:)
      progress_callback&.call("Reading CSV file...")
      
      begin
        text_content = File.read(file_path)
        
        progress_callback&.call("Analyzing CSV data with AI...")
        result = OpenaiServiceV2.extract_student_roster(
          text_content, 
          purpose: 'roster_parsing', 
          user: user
        )

        if result[:success]
          progress_callback&.call("Creating student records...")
          created_students = create_student_records(result[:students], cohort, user)
          
          {
            success: true,
            students_created: created_students.size,
            students: created_students,
            message: "Successfully parsed and created #{created_students.size} student records"
          }
        else
          raise "AI extraction failed: #{result[:error]}"
        end
        
      rescue StandardError => e
        Rails.logger.error "Error parsing CSV: #{e.message}"
        raise "Failed to parse CSV: #{e.message}"
      end
    end

    def extract_pdf_text(file_path)
      begin
        reader = PDF::Reader.new(file_path)
        text_content = ""
        
        reader.pages.each do |page|
          text_content += page.text + "\n"
        end
        
        # Clean up the extracted text
        clean_extracted_text(text_content)
        
      rescue StandardError => e
        Rails.logger.error "Error extracting PDF text: #{e.message}"
        ""
      end
    end

    def clean_extracted_text(text)
      # Remove excessive whitespace and clean up common PDF extraction issues
      text.gsub(/\s+/, ' ')
          .gsub(/[^\w\s@.-]/, ' ')
          .squeeze(' ')
          .strip
    end

    def create_student_records(students_data, cohort, user)
      created_students = []
      
      students_data.each do |student_data|
        # Handle both string keys and symbol keys from structured output
        name = student_data['name'] || student_data[:name]
        next unless name.present? && name.length > 2
        
        # Create the student record (handle both string and symbol keys)
        # Store additional_info in student_attributes JSONB field since it doesn't exist as a column
        additional_info = (student_data['additional_info'] || student_data[:additional_info])&.strip
        
        # Build the inferences from the AI extraction (all done in single API call now!)
        inferences = {}
        
        # Extract gender with confidence (always store, even if unsure)
        gender = student_data['gender'] || student_data[:gender]
        gender_confidence = student_data['gender_confidence'] || student_data[:gender_confidence]
        if gender.present?
          inferences['gender'] = {
            'value' => gender,
            'confidence' => gender_confidence || 0.5
          }
        end
        
        # Extract agency level with confidence (always store, even if unsure)
        agency_level = student_data['agency_level'] || student_data[:agency_level]
        agency_confidence = student_data['agency_level_confidence'] || student_data[:agency_level_confidence]
        if agency_level.present?
          inferences['agency_level'] = {
            'value' => agency_level,
            'confidence' => agency_confidence || 0.5
          }
        end
        
        # Extract department type with confidence (always store, even if unsure)
        dept_type = student_data['department_type'] || student_data[:department_type]
        dept_confidence = student_data['department_type_confidence'] || student_data[:department_type_confidence]
        if dept_type.present?
          inferences['department_type'] = {
            'value' => dept_type,
            'confidence' => dept_confidence || 0.5
          }
        end
        
        # Extract seniority level with confidence (always store, even if unsure)
        seniority = student_data['seniority_level'] || student_data[:seniority_level]
        seniority_confidence = student_data['seniority_level_confidence'] || student_data[:seniority_level_confidence]
        if seniority.present?
          inferences['seniority_level'] = {
            'value' => seniority,
            'confidence' => seniority_confidence || 0.5
          }
        end
        
        # Find existing student by name or create new one
        student_name = (student_data['name'] || student_data[:name])&.strip&.titleize
        student = cohort.students.find_or_initialize_by(name: student_name)
        
        # Update attributes (for both new and existing students)
        student.title = (student_data['title'] || student_data[:title])&.strip
        student.organization = (student_data['organization'] || student_data[:organization])&.strip
        student.location = (student_data['location'] || student_data[:location])&.strip
        student.student_attributes = additional_info.present? ? { additional_info: additional_info } : {}
        student.inferences = inferences.present? ? inferences : nil
        
        if student.save
          created_students << student
          
          # All attribute analysis already done in single API call!
          Rails.logger.info "Student created: #{student.name} with #{inferences.keys.count} inferred attributes"
        else
          Rails.logger.warn "Failed to create student: #{student.errors.full_messages.join(', ')}"
        end
      end
      
      created_students
    end

    def update_student_attributes(student, analysis)
      return unless analysis.is_a?(Hash)
      
      # Update gender if confidence is high
      if analysis['gender']&.dig('confidence').to_f > 0.7
        student.update(gender: analysis['gender']['value'])
      end
      
      # Update agency level if confidence is high  
      if analysis['agency_level']&.dig('confidence').to_f > 0.7
        student.update(agency_level: analysis['agency_level']['value'])
      end
      
      # Update department type if confidence is high
      if analysis['department_type']&.dig('confidence').to_f > 0.7
        student.update(department_type: analysis['department_type']['value'])
      end
      
      # Update seniority level if confidence is high
      if analysis['seniority_level']&.dig('confidence').to_f > 0.7
        student.update(seniority_level: analysis['seniority_level']['value'])
      end
    end
  end
end