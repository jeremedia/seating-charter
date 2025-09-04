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
      # If roster PDF was uploaded, parse students after cohort creation
      if @cohort.roster_pdf.attached?
        begin
          parse_roster_async(@cohort)
          redirect_to @cohort, notice: 'Cohort was successfully created. Processing student roster...'
        rescue StandardError => e
          Rails.logger.error "Error parsing roster after cohort creation: #{e.message}"
          redirect_to @cohort, notice: 'Cohort was created, but there was an issue processing the roster. You can import students manually.'
        end
      else
        redirect_to @cohort, notice: 'Cohort was successfully created.'
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  # AJAX endpoint to process uploaded PDF and extract metadata
  def upload_roster
    unless params[:roster_pdf].present?
      return render json: { success: false, error: 'No file provided' }
    end

    begin
      # Save uploaded file temporarily
      uploaded_file = params[:roster_pdf]
      temp_file = save_temp_file(uploaded_file)
      
      # Extract metadata using our service
      result = PdfCohortExtractorService.extract_cohort_metadata(
        temp_file.path, 
        user: current_user
      )
      
      if result[:success]
        render json: {
          success: true,
          metadata: result[:metadata],
          students_preview: result[:students_preview]
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

  def parse_roster_async(cohort)
    # In a production app, this would be a background job
    # For now, we'll process it synchronously but could be moved to Sidekiq later
    return unless cohort.roster_pdf.attached?

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
      
    rescue StandardError => e
      Rails.logger.error "Error parsing roster for cohort #{cohort.id}: #{e.message}"
      raise e
    ensure
      temp_file&.close
      temp_file&.unlink
    end
  end
end