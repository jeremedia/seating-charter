class CohortsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_cohort, only: [:show, :edit, :update, :destroy]
  
  def index
    @cohorts = current_user.cohorts.includes(:students, :seating_events)
  end
  
  def show
    @students = @cohort.students.includes(:student_import_records)
    @recent_imports = @cohort.import_sessions.recent.limit(5)
    @seating_events = @cohort.seating_events.includes(:seating_arrangements)
  end
  
  def new
    @cohort = current_user.cohorts.build
  end
  
  def create
    @cohort = current_user.cohorts.build(cohort_params)
    
    if @cohort.save
      # Check if we have a stored PDF from the upload_roster step
      if session[:temp_pdf_blob_id]
        begin
          # Attach the stored PDF to the cohort
          pdf_blob = ActiveStorage::Blob.find(session[:temp_pdf_blob_id])
          @cohort.roster_pdf.attach(pdf_blob)
          
          # Import students using ALREADY EXTRACTED data (no API call needed!)
          if session[:students_cache_key].present?
            extracted_students = Rails.cache.read(session[:students_cache_key])
            if extracted_students.present?
              result = create_students_from_extracted_data(@cohort, extracted_students)
              Rails.cache.delete(session[:students_cache_key])
              session.delete(:students_cache_key)
            else
              # Cache expired or missing, fallback to parsing
              result = parse_roster_sync(@cohort)
            end
          else
            # Fallback: parse if we don't have extracted data
            result = parse_roster_sync(@cohort)
          end
          
          # Clear the session
          session.delete(:temp_pdf_blob_id)
          
          redirect_to @cohort, notice: "Cohort created successfully with #{result[:students_created]} students imported!"
          
        rescue StandardError => e
          Rails.logger.error "Error importing students during cohort creation: #{e.message}"
          # Clear the session even on error
          session.delete(:temp_pdf_blob_id)
          redirect_to @cohort, notice: 'Cohort was created, but there was an issue importing students. You can import them manually later.'
        end
      elsif @cohort.roster_pdf.attached?
        # Fallback: if PDF was uploaded via the form field (manual workflow)
        begin
          result = parse_roster_sync(@cohort)
          redirect_to @cohort, notice: "Cohort created successfully with #{result[:students_created]} students imported!"
        rescue StandardError => e
          Rails.logger.error "Error parsing roster after cohort creation: #{e.message}"
          redirect_to @cohort, notice: 'Cohort was created, but there was an issue processing the roster. You can import students manually.'
        end
      else
        redirect_to @cohort, notice: 'Cohort was successfully created.'
      end
    else
      # If cohort creation fails, clean up any stored PDF and cache
      if session[:temp_pdf_blob_id]
        begin
          ActiveStorage::Blob.find(session[:temp_pdf_blob_id]).destroy
        rescue
          # Ignore errors during cleanup
        end
        session.delete(:temp_pdf_blob_id)
      end
      if session[:students_cache_key]
        Rails.cache.delete(session[:students_cache_key])
        session.delete(:students_cache_key)
      end
      render :new, status: :unprocessable_entity
    end
  end

  # AJAX endpoint to process uploaded PDF and extract metadata
  def upload_roster
    unless params[:roster_pdf].present?
      return render json: { success: false, error: 'No file provided' }
    end

    begin
      # Save uploaded file temporarily for processing
      uploaded_file = params[:roster_pdf]
      temp_file = save_temp_file(uploaded_file)
      
      # Extract metadata using our new structured service
      result = OpenaiServiceV2.extract_roster_from_file(
        temp_file.path, 
        purpose: 'cohort_metadata_extraction',
        user: current_user
      )
      
      if result[:success]
        # Clean up any existing stored PDF from previous uploads
        if session[:temp_pdf_blob_id]
          begin
            ActiveStorage::Blob.find(session[:temp_pdf_blob_id]).destroy
          rescue
            # Ignore errors during cleanup
          end
        end
        
        # Store the PDF file in session for use during cohort creation
        # We'll save it as a temporary ActiveStorage blob
        uploaded_file.rewind  # Reset file pointer
        pdf_blob = ActiveStorage::Blob.create_and_upload!(
          io: uploaded_file,
          filename: uploaded_file.original_filename,
          content_type: uploaded_file.content_type
        )
        
        # Store the blob ID in session so we can attach it during create
        session[:temp_pdf_blob_id] = pdf_blob.id
        
        # IMPORTANT: Store the already-extracted students data in Rails cache (not session - too big!)
        # Use a unique cache key tied to the blob ID
        cache_key = "extracted_students_#{pdf_blob.id}"
        Rails.cache.write(cache_key, result[:students], expires_in: 1.hour)
        session[:students_cache_key] = cache_key
        
        # Convert structured result to expected format
        metadata = {
          name: result[:cohort_name] || "Extracted Cohort"
        }
        students_preview = {
          estimated_total: result[:students]&.size || 0,
          sample_students: result[:students]&.first(3) || []
        }
        
        render json: {
          success: true,
          metadata: metadata,
          students_preview: students_preview,
          pdf_stored: true
        }
      else
        render json: {
          success: false,
          error: result[:error] || 'Failed to extract data from PDF'
        }
      end
      
    rescue StandardError => e
      Rails.logger.error "Error processing uploaded PDF: #{e.message}"
      render json: {
        success: false,
        error: 'Error processing PDF. Please check the file and try again.'
      }
    ensure
      # Clean up temp file
      temp_file&.close
      temp_file&.unlink
    end
  end
  
  def edit
  end
  
  def update
    if @cohort.update(cohort_params)
      redirect_to @cohort, notice: 'Cohort was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @cohort.destroy
    redirect_to cohorts_path, notice: 'Cohort was successfully deleted.'
  end
  
  private
  
  def set_cohort
    @cohort = current_user.cohorts.find(params[:id])
  end
  
  def cohort_params
    params.require(:cohort).permit(:name, :description, :start_date, :end_date, :max_students, :roster_pdf)
  end

  def save_temp_file(uploaded_file)
    temp_file = Tempfile.new(['roster', '.pdf'])
    temp_file.binmode
    temp_file.write(uploaded_file.read)
    temp_file.rewind
    temp_file
  end

  def create_students_from_extracted_data(cohort, students_data)
    # Create students directly from the already-extracted data (no API call!)
    created_count = 0
    
    students_data.each do |student_data|
      # Handle both string keys and symbol keys
      name = student_data['name'] || student_data[:name]
      next unless name.present? && name.length > 2
      
      # Build inferences from the already-extracted AI data
      inferences = {}
      
      # Extract gender with confidence
      gender = student_data['gender'] || student_data[:gender]
      gender_confidence = student_data['gender_confidence'] || student_data[:gender_confidence]
      if gender.present?
        inferences['gender'] = {
          'value' => gender.to_s,
          'confidence' => gender_confidence || 0.5
        }
      end
      
      # Extract agency level with confidence
      agency_level = student_data['agency_level'] || student_data[:agency_level]
      agency_confidence = student_data['agency_level_confidence'] || student_data[:agency_level_confidence]
      if agency_level.present?
        inferences['agency_level'] = {
          'value' => agency_level.to_s,
          'confidence' => agency_confidence || 0.5
        }
      end
      
      # Extract department type with confidence
      dept_type = student_data['department_type'] || student_data[:department_type]
      dept_confidence = student_data['department_type_confidence'] || student_data[:department_type_confidence]
      if dept_type.present?
        inferences['department_type'] = {
          'value' => dept_type.to_s,
          'confidence' => dept_confidence || 0.5
        }
      end
      
      # Extract seniority level with confidence
      seniority = student_data['seniority_level'] || student_data[:seniority_level]
      seniority_confidence = student_data['seniority_level_confidence'] || student_data[:seniority_level_confidence]
      if seniority.present?
        inferences['seniority_level'] = {
          'value' => seniority.to_s,
          'confidence' => seniority_confidence || 0.5
        }
      end
      
      additional_info = (student_data['additional_info'] || student_data[:additional_info])&.strip
      
      student = cohort.students.create(
        name: (student_data['name'] || student_data[:name])&.strip&.titleize,
        title: (student_data['title'] || student_data[:title])&.strip,
        organization: (student_data['organization'] || student_data[:organization])&.strip,
        location: (student_data['location'] || student_data[:location])&.strip,
        student_attributes: additional_info.present? ? { additional_info: additional_info } : {},
        inferences: inferences.present? ? inferences : nil
      )
      
      created_count += 1 if student.persisted?
    end
    
    { students_created: created_count }
  end

  def parse_roster_sync(cohort)
    # Synchronously parse roster and return result using new structured service
    return { students_created: 0 } unless cohort.roster_pdf.attached?

    begin
      # Download the attached file to a temporary location
      temp_file = Tempfile.new(['roster', '.pdf'])
      temp_file.binmode
      cohort.roster_pdf.download do |chunk|
        temp_file.write(chunk)
      end
      temp_file.rewind

      # Parse using new AiRosterParserV2 with structured outputs
      result = AiRosterParserV2.parse_roster(
        temp_file.path,
        cohort.id,
        user: current_user
      )

      Rails.logger.info "Roster parsing completed for cohort #{cohort.id}: #{result[:students_created]} students created"
      return result
      
    rescue StandardError => e
      Rails.logger.error "Error parsing roster for cohort #{cohort.id}: #{e.message}"
      raise e
    ensure
      temp_file&.close
      temp_file&.unlink
    end
  end
  
  def parse_roster_async(cohort)
    # Legacy method - now just calls sync version
    # In a production app, this would be a background job
    parse_roster_sync(cohort)
  end
end