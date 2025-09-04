class ExportService
  attr_reader :seating_arrangement, :export_options

  def initialize(seating_arrangement, export_options = {})
    @seating_arrangement = seating_arrangement
    @export_options = export_options
  end

  def self.supported_formats
    %w[pdf excel csv name_tags powerpoint]
  end

  def self.export(seating_arrangement, format, options = {})
    service_class = "Exports::#{format.to_s.camelize}ExportService".constantize
    service = service_class.new(seating_arrangement, options)
    service.generate
  end

  def generate
    raise NotImplementedError, "Subclasses must implement #generate"
  end

  protected

  def seating_event
    @seating_arrangement.seating_event
  end

  def cohort
    seating_event.cohort
  end

  def students
    @students ||= load_students_with_assignments
  end

  def table_assignments
    @table_assignments ||= @seating_arrangement.table_assignments.includes(:student)
  end

  def tables_data
    @tables_data ||= organize_students_by_table
  end

  def export_filename(extension)
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    safe_event_name = seating_event.name.parameterize
    
    if @seating_arrangement.multi_day?
      "#{safe_event_name}_day#{@seating_arrangement.day_number}_#{timestamp}.#{extension}"
    else
      "#{safe_event_name}_seating_#{timestamp}.#{extension}"
    end
  end

  def branding_options
    @export_options[:branding] || default_branding
  end

  def include_photos?
    @export_options[:include_photos] != false
  end

  def include_explanations?
    @export_options[:include_explanations] != false && @seating_arrangement.has_explanations?
  end

  def include_diversity_report?
    @export_options[:include_diversity_report] != false
  end

  def paper_size
    @export_options[:paper_size] || 'LETTER'
  end

  def layout_option
    @export_options[:layout] || 'standard'
  end

  private

  def load_students_with_assignments
    Student.joins(:table_assignments)
           .where(table_assignments: { seating_arrangement: @seating_arrangement })
           .includes(:cohort, :table_assignments)
           .order('table_assignments.table_number, table_assignments.seat_position')
  end

  def organize_students_by_table
    assignments = table_assignments.group_by(&:table_number)
    tables = {}
    
    assignments.each do |table_num, assignments_for_table|
      tables[table_num] = {
        number: table_num,
        students: assignments_for_table.map(&:student),
        assignments: assignments_for_table,
        explanation: @seating_arrangement.table_explanation(table_num)
      }
    end
    
    tables
  end

  def default_branding
    {
      logo_path: nil,
      organization_name: 'CHDS Seating Charter',
      primary_color: '#1f2937',
      secondary_color: '#3b82f6',
      header_text: seating_event.name,
      footer_text: "Generated on #{Date.current.strftime('%B %d, %Y')}"
    }
  end

  def diversity_metrics
    @seating_arrangement.diversity_metrics || {}
  end

  def optimization_scores
    @seating_arrangement.optimization_scores || {}
  end

  def formatted_diversity_data
    return {} unless diversity_metrics.present?

    {
      gender_distribution: diversity_metrics['gender_distribution'] || {},
      agency_level_distribution: diversity_metrics['agency_level_distribution'] || {},
      department_type_distribution: diversity_metrics['department_type_distribution'] || {},
      seniority_level_distribution: diversity_metrics['seniority_level_distribution'] || {},
      interaction_diversity_score: diversity_metrics['interaction_diversity_score'] || 0.0,
      cross_functional_score: diversity_metrics['cross_functional_score'] || 0.0
    }
  end

  def qr_code_url
    return nil unless @export_options[:include_qr_code]
    
    # This would be the URL to the online seating chart
    Rails.application.routes.url_helpers.cohort_seating_event_seating_arrangement_url(
      cohort, seating_event, @seating_arrangement,
      host: Rails.application.config.force_ssl ? 'https://' : 'http://' + 
            (Rails.application.config.action_mailer.default_url_options[:host] || 'localhost:3000')
    )
  rescue
    nil
  end

  def generate_qr_code(url)
    return nil unless url
    
    # This would require adding 'rqrcode' gem to Gemfile
    # For now, return a placeholder
    nil
  end

  def safe_filename_string(str)
    str.gsub(/[^0-9A-Za-z.\-]/, '_').squeeze('_')
  end

  def format_student_name(student)
    student.name || "Unknown Student"
  end

  def format_student_title(student)
    student.title.present? ? student.title : "No title provided"
  end

  def format_student_organization(student)
    student.display_organization
  end

  def format_student_attributes(student)
    attributes = []
    
    if student.gender.present?
      confidence = student.gender_confidence
      attributes << "Gender: #{student.gender} (#{(confidence * 100).round}%)"
    end
    
    if student.agency_level.present?
      confidence = student.agency_level_confidence
      attributes << "Level: #{student.agency_level} (#{(confidence * 100).round}%)"
    end
    
    if student.department_type.present?
      confidence = student.department_type_confidence
      attributes << "Dept: #{student.department_type} (#{(confidence * 100).round}%)"
    end
    
    if student.seniority_level.present?
      confidence = student.seniority_level_confidence
      attributes << "Seniority: #{student.seniority_level} (#{(confidence * 100).round}%)"
    end
    
    attributes
  end

  def temp_file_path(extension)
    Rails.root.join('tmp', "export_#{SecureRandom.hex(8)}.#{extension}")
  end

  def cleanup_temp_file(file_path)
    File.delete(file_path) if File.exist?(file_path)
  rescue Errno::ENOENT
    # File already deleted, ignore
  end
end