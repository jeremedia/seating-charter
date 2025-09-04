class AiRosterParser
  include HTTParty
  
  class << self
    # Main method to parse roster from uploaded file
    def parse_roster(file_path, cohort_id, user: nil, progress_callback: nil)
      raise "File not found: #{file_path}" unless File.exist?(file_path)
      
      file_extension = File.extname(file_path).downcase
      
      case file_extension
      when '.pdf'
        parse_pdf_roster(file_path, cohort_id, user: user, progress_callback: progress_callback)
      when '.xlsx', '.xls', '.csv'
        parse_excel_csv_roster(file_path, cohort_id, user: user, progress_callback: progress_callback)
      else
        raise "Unsupported file format: #{file_extension}. Supported formats: PDF, Excel (xlsx, xls), CSV"
      end
    end
    
    # Parse PDF roster using pdf-reader gem
    def parse_pdf_roster(file_path, cohort_id, user: nil, progress_callback: nil)
      progress_callback&.call("Extracting text from PDF...")
      
      begin
        # Extract text from PDF
        reader = PDF::Reader.new(file_path)
        text_content = ""
        
        reader.pages.each_with_index do |page, index|
          text_content += page.text + "\n\n"
          progress_callback&.call("Processing page #{index + 1} of #{reader.page_count}...")
        end
        
        # Clean up the extracted text
        cleaned_text = clean_extracted_text(text_content)
        
        progress_callback&.call("Analyzing text with AI...")
        
        # Send to OpenAI for parsing
        parse_with_ai(cleaned_text, cohort_id, user: user, progress_callback: progress_callback)
        
      rescue StandardError => e
        Rails.logger.error "Error parsing PDF: #{e.message}"
        raise "Failed to parse PDF: #{e.message}"
      end
    end
    
    # Parse Excel/CSV roster using roo gem
    def parse_excel_csv_roster(file_path, cohort_id, user: nil, progress_callback: nil)
      progress_callback&.call("Opening spreadsheet...")
      
      begin
        # Open spreadsheet with Roo
        case File.extname(file_path).downcase
        when '.xlsx'
          spreadsheet = Roo::Excelx.new(file_path)
        when '.xls'
          spreadsheet = Roo::Excel.new(file_path)
        when '.csv'
          spreadsheet = Roo::CSV.new(file_path)
        end
        
        # Convert to text format for AI processing
        text_content = ""
        header_row = nil
        
        spreadsheet.each_row_streaming(pad_cells: true).each_with_index do |row, index|
          row_data = row.map { |cell| cell ? cell.value.to_s.strip : "" }
          
          if index == 0
            header_row = row_data
            text_content += "Headers: #{header_row.join(' | ')}\n\n"
          else
            text_content += "Row #{index}: #{row_data.join(' | ')}\n"
          end
          
          progress_callback&.call("Processing row #{index + 1}...") if index % 10 == 0
        end
        
        progress_callback&.call("Analyzing spreadsheet data with AI...")
        
        # Send to OpenAI for parsing
        parse_with_ai(text_content, cohort_id, user: user, progress_callback: progress_callback)
        
      rescue StandardError => e
        Rails.logger.error "Error parsing Excel/CSV: #{e.message}"
        raise "Failed to parse spreadsheet: #{e.message}"
      end
    end
    
    # Core AI parsing method
    def parse_with_ai(text_content, cohort_id, user: nil, progress_callback: nil)
      cohort = Cohort.find(cohort_id)
      
      # Create extraction prompt
      prompt = build_extraction_prompt(text_content)
      
      progress_callback&.call("Sending data to AI for student extraction...")
      
      # Process in batches to manage token limits and costs
      batch_size = AiConfiguration.active_configuration&.batch_size || 5
      
      # Split the content if it's too large
      content_chunks = split_content_for_processing(text_content, batch_size)
      
      all_students = []
      
      content_chunks.each_with_index do |chunk, index|
        progress_callback&.call("Processing batch #{index + 1} of #{content_chunks.size}...")
        
        chunk_prompt = build_extraction_prompt(chunk)
        
        response = OpenaiService.call(
          chunk_prompt,
          purpose: 'roster_parsing',
          user: user
        )
        
        # Parse the AI response
        students_data = parse_ai_response(response)
        all_students.concat(students_data)
        
        # Small delay between batches
        sleep(0.5) if index < content_chunks.size - 1
      end
      
      progress_callback&.call("Creating student records...")
      
      # Create student records
      created_students = create_student_records(all_students, cohort, user)
      
      progress_callback&.call("Roster parsing completed!")
      
      {
        success: true,
        students_created: created_students.size,
        students: created_students,
        message: "Successfully parsed and created #{created_students.size} student records"
      }
    end
    
    private
    
    def clean_extracted_text(text)
      # Remove excessive whitespace and clean up common PDF extraction issues
      text.gsub(/\s+/, ' ')
          .gsub(/[^\w\s@.-]/, ' ')
          .squeeze(' ')
          .strip
    end
    
    def split_content_for_processing(content, batch_size)
      # Simple splitting - could be enhanced based on natural boundaries
      words = content.split(/\s+/)
      words_per_chunk = [words.size / batch_size, 500].max # At least 500 words per chunk
      
      chunks = []
      words.each_slice(words_per_chunk) do |chunk_words|
        chunks << chunk_words.join(' ')
      end
      
      chunks
    end
    
    def build_extraction_prompt(text_content)
      <<~PROMPT
        Please extract student information from the following text. Look for patterns that indicate student records, such as:
        - Names (first and last)
        - Titles or positions
        - Organizations or agencies
        - Locations (cities, states)
        - Email addresses
        - Any other identifying information
        
        For each student you identify, please provide the information in the following JSON format:
        {
          "students": [
            {
              "name": "Full Name",
              "title": "Job Title",
              "organization": "Agency/Organization",
              "location": "City, State",
              "additional_info": "Any other relevant information"
            }
          ]
        }
        
        Important guidelines:
        - Only include entries that clearly represent individual people/students
        - If title, organization, or location is not clearly identifiable, use null
        - Combine first and last names into the "name" field
        - Be conservative - only include entries you're confident about
        - If no students can be identified, return an empty students array
        
        Text to analyze:
        #{text_content}
        
        Please respond with valid JSON only.
      PROMPT
    end
    
    def parse_ai_response(response)
      # Clean the response to extract JSON
      json_text = response.strip
      
      # Remove any markdown code blocks
      json_text = json_text.gsub(/```json\n?/, '').gsub(/```\n?/, '')
      
      begin
        parsed = JSON.parse(json_text)
        students = parsed['students'] || []
        
        # Validate and clean student data
        students.select do |student|
          student['name'].present? && student['name'].length > 2
        end.map do |student|
          {
            name: student['name']&.strip&.titleize,
            title: student['title']&.strip,
            organization: student['organization']&.strip,
            location: student['location']&.strip,
            additional_info: student['additional_info']&.strip
          }.compact
        end
        
      rescue JSON::ParserError => e
        Rails.logger.error "Failed to parse AI response as JSON: #{e.message}"
        Rails.logger.error "Response was: #{response}"
        []
      end
    end
    
    def create_student_records(students_data, cohort, user)
      created_students = []
      
      students_data.each do |student_data|
        begin
          student = Student.create!(
            cohort: cohort,
            name: student_data[:name],
            title: student_data[:title],
            organization: student_data[:organization],
            location: student_data[:location],
            student_attributes: {
              'additional_info' => student_data[:additional_info],
              'parsed_from_roster' => true,
              'parsed_at' => Time.current.iso8601
            }.compact
          )
          
          created_students << student
          
          # Log the creation
          Rails.logger.info "Created student: #{student.name} for cohort #{cohort.id}"
          
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "Failed to create student #{student_data[:name]}: #{e.message}"
        end
      end
      
      created_students
    end
    
    # Sample data for testing
    def create_sample_data
      sample_text = <<~TEXT
        STUDENT ROSTER - CHDS COHORT 2024-A
        
        1. John Smith - Supervisory Special Agent - FBI - Washington, DC
        2. Sarah Johnson - Captain - U.S. Army - Fort Bragg, NC
        3. Michael Davis - Emergency Management Director - City of Phoenix - Phoenix, AZ
        4. Lisa Chen - Intelligence Analyst - CIA - Langley, VA
        5. Robert Wilson - Fire Chief - Miami-Dade Fire Rescue - Miami, FL
        6. Jennifer Brown - Cybersecurity Manager - DHS - Washington, DC
        7. David Martinez - Detective Lieutenant - NYPD - New York, NY
        8. Amanda Taylor - Program Manager - FEMA - Washington, DC
        9. Christopher Lee - Border Patrol Agent - CBP - El Paso, TX
        10. Maria Rodriguez - Public Health Director - CDC - Atlanta, GA
      TEXT
      
      sample_text
    end
    
    def test_with_sample_data(cohort_id, user: nil)
      sample_text = create_sample_data
      
      begin
        result = parse_with_ai(sample_text, cohort_id, user: user) do |message|
          Rails.logger.info "Sample parsing progress: #{message}"
        end
        
        {
          success: true,
          result: result,
          message: "Successfully tested roster parsing with sample data"
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