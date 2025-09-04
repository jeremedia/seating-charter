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
          
          # Import students immediately using the same PDF
          result = parse_roster_sync(@cohort)
          
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
      # If cohort creation fails, clean up any stored PDF
      if session[:temp_pdf_blob_id]
        begin
          ActiveStorage::Blob.find(session[:temp_pdf_blob_id]).destroy
        rescue
          # Ignore errors during cleanup
        end
        session.delete(:temp_pdf_blob_id)
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
      
      # Extract metadata using our service
      result = PdfCohortExtractorService.extract_cohort_metadata(
        temp_file.path, 
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
        
        render json: {
          success: true,
          metadata: result[:metadata],
          students_preview: result[:students_preview],
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

  def parse_roster_sync(cohort)
    # Synchronously parse roster and return result
    return { students_created: 0 } unless cohort.roster_pdf.attached?

    begin
      # Download the attached file to a temporary location
      temp_file = Tempfile.new(['roster', '.pdf'])
      temp_file.binmode
      cohort.roster_pdf.download do |chunk|
        temp_file.write(chunk)
      end
      temp_file.rewind

      # Parse using existing AiRosterParser
      result = AiRosterParser.parse_roster(
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