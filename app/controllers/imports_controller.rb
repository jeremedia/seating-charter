class ImportsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_cohort, only: [:new, :create, :show]
  before_action :set_import_session, only: [:show]
  
  def new
    @import_session = @cohort.import_sessions.build
  end
  
  def create
    @import_session = @cohort.import_sessions.build(import_session_params)
    @import_session.user = current_user
    @import_session.status = :pending
    
    uploaded_file = params[:import_session][:file]
    
    if uploaded_file.nil?
      @import_session.errors.add(:file, "can't be blank")
      render :new, status: :unprocessable_entity
      return
    end
    
    # Validate file type
    allowed_extensions = %w[.pdf .xlsx .xls .csv]
    file_extension = File.extname(uploaded_file.original_filename).downcase
    
    unless allowed_extensions.include?(file_extension)
      @import_session.errors.add(:file, "must be a PDF, Excel, or CSV file")
      render :new, status: :unprocessable_entity
      return
    end
    
    # Set file metadata
    @import_session.file_name = uploaded_file.original_filename
    @import_session.file_size = uploaded_file.size
    
    if @import_session.save
      # Save uploaded file temporarily
      temp_file_path = Rails.root.join('tmp', 'imports', "#{@import_session.id}_#{uploaded_file.original_filename}")
      FileUtils.mkdir_p(File.dirname(temp_file_path))
      File.open(temp_file_path, 'wb') do |file|
        file.write(uploaded_file.read)
      end
      
      # Process import in background
      ProcessImportJob.perform_later(@import_session.id, temp_file_path.to_s)
      
      redirect_to cohort_import_path(@cohort, @import_session), 
                  notice: 'File uploaded successfully. Processing import...'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def show
    respond_to do |format|
      format.html
      format.json { render json: import_status_json }
    end
  end
  
  private
  
  def set_cohort
    @cohort = Cohort.find(params[:cohort_id])
    authorize_cohort_access
  end
  
  def set_import_session
    @import_session = @cohort.import_sessions.find(params[:id])
  end
  
  def import_session_params
    params.require(:import_session).permit(:description)
  end
  
  def authorize_cohort_access
    unless @cohort.user == current_user || current_user.admin?
      redirect_to dashboard_path, alert: 'Access denied.'
    end
  end
  
  def import_status_json
    {
      id: @import_session.id,
      status: @import_session.status,
      file_name: @import_session.file_name,
      students_imported: @import_session.students_imported,
      processed_at: @import_session.processed_at,
      errors: @import_session.errors.full_messages,
      can_proceed_to_review: @import_session.completed? && @import_session.students_imported > 0
    }
  end
end