class ExportsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_cohort
  before_action :set_seating_event
  before_action :set_seating_arrangement, except: [:index, :bulk_export]
  
  def index
    @seating_arrangements = @seating_event.seating_arrangements.includes(:created_by, :seating_event)
                                          .order(created_at: :desc)
    @supported_formats = ExportService.supported_formats
    @recent_exports = current_user.recent_exports.limit(10) if respond_to?(:recent_exports)
  end

  def new
    @export_options = build_default_export_options
    @formats = ExportService.supported_formats
    @layout_options = layout_options_for_format
    @branding_options = default_branding_options
  end

  def create
    @format = params[:format]&.to_s&.downcase
    @export_options = build_export_options_from_params

    unless ExportService.supported_formats.include?(@format)
      return redirect_to cohort_seating_event_exports_path(@cohort, @seating_event), 
                         alert: 'Unsupported export format'
    end

    if large_export?
      # Queue background job for large exports
      job = ExportJob.perform_later(@seating_arrangement, @format, @export_options, current_user)
      
      respond_to do |format|
        format.html do
          redirect_to cohort_seating_event_exports_path(@cohort, @seating_event),
                      notice: "Export queued. You'll receive an email when it's ready."
        end
        format.json do
          render json: { 
            status: 'queued', 
            job_id: job.job_id,
            message: "Export job queued successfully"
          }
        end
      end
    else
      # Generate export immediately
      begin
        result = ExportService.export(@seating_arrangement, @format, @export_options)
        
        respond_to do |format|
          format.html do
            send_file result[:file_path], 
                      filename: result[:filename],
                      type: result[:content_type],
                      disposition: 'attachment'
          end
          format.json do
            # For AJAX requests, return download URL
            render json: { 
              status: 'ready',
              download_url: download_export_url(result),
              filename: result[:filename]
            }
          end
        end
      rescue StandardError => e
        Rails.logger.error "Export failed: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        
        respond_to do |format|
          format.html do
            redirect_to cohort_seating_event_exports_path(@cohort, @seating_event),
                        alert: "Export failed: #{e.message}"
          end
          format.json do
            render json: { 
              status: 'error', 
              message: e.message 
            }, status: :unprocessable_entity
          end
        end
      ensure
        # Clean up temporary file
        File.delete(result[:file_path]) if result&.dig(:file_path) && File.exist?(result[:file_path])
      end
    end
  end

  def bulk_export
    @arrangements = @seating_event.seating_arrangements.where(id: params[:arrangement_ids])
    @format = params[:format]&.to_s&.downcase
    @export_options = build_export_options_from_params
    
    if @arrangements.empty?
      return redirect_to cohort_seating_event_exports_path(@cohort, @seating_event),
                         alert: 'No arrangements selected for export'
    end

    # Always use background job for bulk exports
    job = BulkExportJob.perform_later(@arrangements.pluck(:id), @format, @export_options, current_user)
    
    respond_to do |format|
      format.html do
        redirect_to cohort_seating_event_exports_path(@cohort, @seating_event),
                    notice: "Bulk export queued. You'll receive an email with a ZIP file when ready."
      end
      format.json do
        render json: { 
          status: 'queued', 
          job_id: job.job_id,
          arrangements_count: @arrangements.count,
          message: "Bulk export job queued successfully"
        }
      end
    end
  end

  def preview
    @format = params[:format]&.to_s&.downcase
    @export_options = build_export_options_from_params
    
    # Generate preview data based on format
    case @format
    when 'pdf'
      @preview_data = generate_pdf_preview_data
    when 'excel'
      @preview_data = generate_excel_preview_data
    when 'csv'
      @preview_data = generate_csv_preview_data
    when 'name_tags'
      @preview_data = generate_name_tags_preview_data
    when 'powerpoint'
      @preview_data = generate_powerpoint_preview_data
    else
      @preview_data = { error: 'Unsupported format for preview' }
    end

    respond_to do |format|
      format.json { render json: @preview_data }
      format.html { render :preview }
    end
  end

  def status
    job_id = params[:job_id]
    
    if job_id.present?
      # Check background job status
      job_status = check_export_job_status(job_id)
      
      respond_to do |format|
        format.json { render json: job_status }
      end
    else
      respond_to do |format|
        format.json { render json: { status: 'not_found' }, status: :not_found }
      end
    end
  end

  def download
    # Handle direct download requests (for AJAX-generated exports)
    file_token = params[:token]
    
    # This would require implementing a secure file serving mechanism
    # For now, redirect to the standard export creation
    redirect_to new_cohort_seating_event_seating_arrangement_export_path(@cohort, @seating_event, @seating_arrangement)
  end

  def email_export
    @format = params[:format]&.to_s&.downcase
    @export_options = build_export_options_from_params
    @recipient_email = params[:recipient_email] || current_user.email

    # Queue email export job
    EmailExportJob.perform_later(@seating_arrangement, @format, @export_options, @recipient_email, current_user)
    
    respond_to do |format|
      format.html do
        redirect_to cohort_seating_event_exports_path(@cohort, @seating_event),
                    notice: "Export will be emailed to #{@recipient_email}"
      end
      format.json do
        render json: { 
          status: 'queued',
          recipient: @recipient_email,
          message: "Email export queued successfully"
        }
      end
    end
  end

  def formats
    # Return available formats and their options
    formats_data = ExportService.supported_formats.map do |format|
      {
        format: format,
        name: format.humanize,
        options: format_specific_options(format),
        description: format_description(format)
      }
    end

    respond_to do |format|
      format.json { render json: { formats: formats_data } }
    end
  end

  private

  def set_cohort
    @cohort = current_user.cohorts.find(params[:cohort_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to cohorts_path, alert: 'Cohort not found'
  end

  def set_seating_event
    @seating_event = @cohort.seating_events.find(params[:seating_event_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to cohort_path(@cohort), alert: 'Seating event not found'
  end

  def set_seating_arrangement
    @seating_arrangement = @seating_event.seating_arrangements.find(params[:seating_arrangement_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to cohort_seating_event_path(@cohort, @seating_event), alert: 'Seating arrangement not found'
  end

  def build_default_export_options
    {
      layout: 'standard',
      paper_size: 'LETTER',
      include_photos: false,
      include_explanations: true,
      include_diversity_report: true,
      include_qr_code: false,
      include_borders: true,
      color_by_table: false,
      branding: default_branding_options
    }
  end

  def build_export_options_from_params
    options = {}
    
    # Layout and formatting options
    options[:layout] = params[:layout] if params[:layout].present?
    options[:paper_size] = params[:paper_size] if params[:paper_size].present?
    
    # Content options
    options[:include_photos] = params[:include_photos] == '1'
    options[:include_explanations] = params[:include_explanations] == '1'
    options[:include_diversity_report] = params[:include_diversity_report] == '1'
    options[:include_qr_code] = params[:include_qr_code] == '1'
    options[:include_borders] = params[:include_borders] != '0' # Default true
    options[:color_by_table] = params[:color_by_table] == '1'
    
    # Format-specific options
    case params[:format]
    when 'csv'
      options[:csv_format] = params[:csv_format] if params[:csv_format].present?
    when 'name_tags'
      options[:name_tag_format] = params[:name_tag_format] if params[:name_tag_format].present?
      options[:name_tag_style] = params[:name_tag_style] if params[:name_tag_style].present?
      options[:include_table_number] = params[:include_table_number] != '0'
      options[:include_organization_on_tent] = params[:include_organization_on_tent] == '1'
    when 'powerpoint'
      options[:presentation_style] = params[:presentation_style] if params[:presentation_style].present?
      options[:detailed_table_slides] = params[:detailed_table_slides] == '1'
    end
    
    # Branding options
    if params[:branding].present?
      options[:branding] = params[:branding].permit(
        :organization_name, :primary_color, :secondary_color, 
        :header_text, :footer_text, :logo_path
      ).to_h
    end
    
    options
  end

  def default_branding_options
    {
      organization_name: ENV['CHDS_ORGANIZATION_NAME'] || 'CHDS Seating Charter',
      primary_color: '#1f2937',
      secondary_color: '#3b82f6',
      header_text: @seating_event&.name || 'Seating Arrangement',
      footer_text: "Generated on #{Date.current.strftime('%B %d, %Y')}"
    }
  end

  def large_export?
    # Determine if export should be handled by background job
    return true if params[:format] == 'powerpoint' # PowerPoint generation can be slow
    return true if @seating_arrangement.students_count > 100 # Large events
    return true if params[:include_explanations] == '1' && @seating_arrangement.has_explanations? # Complex exports
    
    false
  end

  def layout_options_for_format
    {
      'pdf' => ['standard', 'detailed', 'compact'],
      'excel' => ['full', 'summary'],
      'csv' => ['full', 'roster', 'summary', 'assignments', 'diversity'],
      'name_tags' => ['standard', 'badge', 'table_tent', 'simple'],
      'powerpoint' => ['slides', 'handout', 'speaker_notes']
    }
  end

  def format_specific_options(format)
    case format
    when 'pdf'
      {
        layouts: ['standard', 'detailed', 'compact'],
        paper_sizes: ['LETTER', 'A4', 'LEGAL']
      }
    when 'excel'
      {
        includes_multiple_worksheets: true,
        supports_formatting: true
      }
    when 'csv'
      {
        formats: ['full', 'roster', 'summary', 'assignments', 'diversity'],
        lightweight: true
      }
    when 'name_tags'
      {
        formats: ['avery_5395', 'avery_74459', 'table_tent', 'badge_large'],
        styles: ['standard', 'badge', 'table_tent', 'simple'],
        paper_sizes: ['LETTER', 'A4']
      }
    when 'powerpoint'
      {
        styles: ['slides', 'handout', 'speaker_notes'],
        interactive: true,
        output_format: 'html'
      }
    else
      {}
    end
  end

  def format_description(format)
    case format
    when 'pdf'
      'Professional seating chart with visual layout and detailed information'
    when 'excel'
      'Comprehensive spreadsheet with multiple worksheets for analysis'
    when 'csv'
      'Simple data format compatible with all spreadsheet applications'
    when 'name_tags'
      'Printable name tags and table tents for events'
    when 'powerpoint'
      'Interactive presentation slides for event introduction'
    else
      ''
    end
  end

  def generate_pdf_preview_data
    {
      format: 'pdf',
      sections: [
        { name: 'Header', description: 'Event name and organization branding' },
        { name: 'Event Details', description: 'Date, type, student count, table information' },
        { name: 'Optimization Summary', description: 'Score, strategy, and performance metrics' },
        { name: 'Seating Chart', description: 'Visual layout of all tables with student assignments' },
        (@export_options[:include_diversity_report] ? { name: 'Diversity Analysis', description: 'Distribution charts and metrics' } : nil),
        (@export_options[:include_explanations] ? { name: 'Explanations', description: 'AI-generated rationale for seating decisions' } : nil)
      ].compact,
      estimated_pages: estimate_pdf_pages,
      layout: @export_options[:layout] || 'standard'
    }
  end

  def generate_excel_preview_data
    {
      format: 'excel',
      worksheets: [
        { name: 'Seating Chart', description: 'Visual layout and basic information' },
        { name: 'Student Roster', description: 'Complete list with attributes and table assignments' },
        { name: 'Table Assignments', description: 'Detailed breakdown by table' },
        { name: 'Summary', description: 'Event overview and statistics' },
        (@export_options[:include_diversity_report] ? { name: 'Diversity Analysis', description: 'Distribution data and calculations' } : nil),
        (@export_options[:include_explanations] ? { name: 'Explanations', description: 'Seating rationale and AI insights' } : nil)
      ].compact,
      estimated_rows: @seating_arrangement.students_count + 50
    }
  end

  def generate_csv_preview_data
    csv_format = @export_options[:csv_format] || 'full'
    
    {
      format: 'csv',
      csv_format: csv_format,
      description: csv_format_description(csv_format),
      estimated_rows: estimate_csv_rows(csv_format),
      columns: csv_format_columns(csv_format)
    }
  end

  def generate_name_tags_preview_data
    format_type = @export_options[:name_tag_format] || 'avery_5395'
    style = @export_options[:name_tag_style] || 'standard'
    
    {
      format: 'name_tags',
      tag_format: format_type,
      style: style,
      estimated_pages: (@seating_arrangement.students_count.to_f / tags_per_page(format_type)).ceil,
      tags_per_page: tags_per_page(format_type)
    }
  end

  def generate_powerpoint_preview_data
    style = @export_options[:presentation_style] || 'slides'
    
    slides = [
      { title: 'Title Slide', content: 'Event name and date' },
      { title: 'Overview', content: 'Event statistics and details' },
      { title: 'Seating Chart', content: 'Visual layout of all tables' }
    ]
    
    slides << { title: 'Optimization Results', content: 'Performance metrics' } if @seating_arrangement.optimization_scores.present?
    slides << { title: 'Diversity Analysis', content: 'Distribution charts' } if @export_options[:include_diversity_report]
    slides << { title: 'Explanations', content: 'Seating rationale' } if @export_options[:include_explanations]
    slides << { title: 'Conclusion', content: 'Final slide' }
    
    if @export_options[:detailed_table_slides]
      @seating_arrangement.tables_count.times do |i|
        slides << { title: "Table #{i + 1} Details", content: 'Individual table breakdown' }
      end
    end
    
    {
      format: 'powerpoint',
      style: style,
      slides: slides,
      estimated_slides: slides.count,
      output_format: 'Interactive HTML'
    }
  end

  def csv_format_description(format)
    case format
    when 'roster'
      'Simple list of students with basic information'
    when 'summary'
      'Event overview with table summaries'
    when 'assignments'
      'Detailed table-by-table assignments'
    when 'diversity'
      'Diversity analysis and distribution data'
    else
      'Complete dataset with all available information'
    end
  end

  def csv_format_columns(format)
    case format
    when 'roster'
      ['Table Number', 'Student Name', 'Title', 'Organization', 'Location']
    when 'summary'
      ['Event Information', 'Value']
    when 'assignments'
      ['Table', 'Seat Position', 'Student Name', 'Organization', 'Title']
    when 'diversity'
      ['Category', 'Distribution', 'Percentage']
    else
      ['Table Number', 'Seat Position', 'Student Name', 'Title', 'Organization', 'Attributes...']
    end
  end

  def estimate_pdf_pages
    base_pages = 3 # Title, overview, seating chart
    base_pages += 1 if @seating_arrangement.optimization_scores.present?
    base_pages += 1 if @export_options[:include_diversity_report]
    base_pages += 1 if @export_options[:include_explanations]
    
    # Add pages based on layout and content
    case @export_options[:layout]
    when 'detailed'
      base_pages += (@seating_arrangement.tables_count.to_f / 2).ceil
    end
    
    base_pages
  end

  def estimate_csv_rows(format)
    case format
    when 'roster', 'full'
      @seating_arrangement.students_count + 1 # +1 for header
    when 'summary'
      20 # Fixed number of summary rows
    when 'assignments'
      @seating_arrangement.students_count + @seating_arrangement.tables_count + 5 # Students + table headers + spacing
    when 'diversity'
      50 # Estimated diversity analysis rows
    else
      @seating_arrangement.students_count + 1
    end
  end

  def tags_per_page(format)
    case format
    when 'avery_5395'
      30
    when 'avery_74459'
      10
    when 'table_tent'
      4
    when 'badge_large'
      8
    else
      20
    end
  end

  def check_export_job_status(job_id)
    # This would integrate with Sidekiq or ActiveJob to check job status
    # For now, return a placeholder response
    {
      status: 'processing',
      progress: 50,
      message: 'Export in progress...'
    }
  end

  def download_export_url(result)
    # Generate a secure temporary download URL
    # This would require implementing secure file serving
    "/tmp/download/#{SecureRandom.hex}"
  end
end