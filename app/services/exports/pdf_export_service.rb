require 'prawn'
require 'prawn/table'

module Exports
  class PdfExportService < ExportService
    def generate
      pdf = Prawn::Document.new(page_size: page_size_for_prawn, margin: 50)
      
      # Add header
      add_header(pdf)
      
      # Add event details
      add_event_details(pdf)
      
      # Add optimization summary
      add_optimization_summary(pdf) if optimization_scores.present?
      
      # Add seating chart
      add_seating_chart(pdf)
      
      # Add diversity report if requested
      add_diversity_report(pdf) if include_diversity_report?
      
      # Add explanations if available and requested
      add_explanations_section(pdf) if include_explanations?
      
      # Add QR code if requested
      add_qr_code(pdf) if @export_options[:include_qr_code]
      
      # Add footer
      add_footer(pdf)
      
      # Generate and return the PDF
      temp_path = temp_file_path('pdf')
      pdf.render_file(temp_path)
      
      {
        file_path: temp_path,
        filename: export_filename('pdf'),
        content_type: 'application/pdf'
      }
    end

    private

    def page_size_for_prawn
      case paper_size.upcase
      when 'A4'
        'A4'
      when 'LEGAL'
        'LEGAL'
      else
        'LETTER'
      end
    end

    def add_header(pdf)
      branding = branding_options
      
      # Organization name and logo space
      pdf.fill_color branding[:primary_color] || '1f2937'
      pdf.font 'Helvetica', style: :bold, size: 20
      pdf.text branding[:organization_name] || 'CHDS Seating Charter', align: :center
      
      pdf.move_down 10
      pdf.stroke_horizontal_rule
      pdf.move_down 20
      
      # Event title
      pdf.fill_color '000000'
      pdf.font 'Helvetica', style: :bold, size: 16
      pdf.text branding[:header_text] || seating_event.name, align: :center
      
      if @seating_arrangement.multi_day?
        pdf.move_down 5
        pdf.font 'Helvetica', size: 12
        pdf.text @seating_arrangement.day_name, align: :center
      end
      
      pdf.move_down 20
    end

    def add_event_details(pdf)
      pdf.font 'Helvetica', style: :bold, size: 12
      pdf.text "Event Details", color: branding_options[:primary_color] || '1f2937'
      pdf.move_down 8
      
      details = [
        ["Date:", seating_event.event_date.strftime("%B %d, %Y")],
        ["Type:", seating_event.event_type.humanize],
        ["Tables:", "#{tables_data.count} tables"],
        ["Students:", "#{students.count} students"],
        ["Table Size:", "#{seating_event.table_size} students per table"],
        ["Utilization:", "#{seating_event.utilization_percentage}%"]
      ]
      
      if @seating_arrangement.multi_day?
        details << ["Day:", @seating_arrangement.day_name]
        details << ["Series:", "Day #{@seating_arrangement.day_number} of #{seating_event.seating_arrangements.multi_day.count}"]
      end
      
      pdf.font 'Helvetica', size: 10
      pdf.table(details, 
                cell_style: { borders: [], padding: [2, 8, 2, 0] },
                column_widths: [80, 200]) do |table|
        table.column(0).font_style = :bold
      end
      
      pdf.move_down 20
    end

    def add_optimization_summary(pdf)
      pdf.font 'Helvetica', style: :bold, size: 12
      pdf.text "Optimization Summary", color: branding_options[:primary_color] || '1f2937'
      pdf.move_down 8
      
      summary_data = [
        ["Overall Score:", @seating_arrangement.formatted_score],
        ["Strategy:", @seating_arrangement.optimization_strategy],
        ["Runtime:", "#{@seating_arrangement.runtime_seconds.round(2)} seconds"],
        ["Improvements:", @seating_arrangement.total_improvements.to_s]
      ]
      
      if @seating_arrangement.overall_confidence > 0
        summary_data << ["Confidence:", "#{(@seating_arrangement.overall_confidence * 100).round(1)}%"]
      end
      
      pdf.font 'Helvetica', size: 10
      pdf.table(summary_data,
                cell_style: { borders: [], padding: [2, 8, 2, 0] },
                column_widths: [100, 150]) do |table|
        table.column(0).font_style = :bold
        # Color code the score
        if @seating_arrangement.overall_score >= 0.8
          table.row(0).column(1).text_color = '16a34a' # green
        elsif @seating_arrangement.overall_score >= 0.6
          table.row(0).column(1).text_color = 'ea580c' # orange
        else
          table.row(0).column(1).text_color = 'dc2626' # red
        end
      end
      
      pdf.move_down 20
    end

    def add_seating_chart(pdf)
      pdf.font 'Helvetica', style: :bold, size: 12
      pdf.text "Seating Arrangement", color: branding_options[:primary_color] || '1f2937'
      pdf.move_down 10
      
      case layout_option
      when 'detailed'
        add_detailed_seating_chart(pdf)
      when 'compact'
        add_compact_seating_chart(pdf)
      else
        add_standard_seating_chart(pdf)
      end
    end

    def add_standard_seating_chart(pdf)
      tables_per_row = calculate_tables_per_row
      current_row = 0
      
      tables_data.each_slice(tables_per_row) do |row_tables|
        row_tables.each_with_index do |table_data, index|
          x_offset = index * 180
          y_position = pdf.cursor - (current_row * 140)
          
          add_table_box(pdf, table_data[1], x_offset, y_position)
        end
        
        current_row += 1
        pdf.move_down 150 if current_row * 150 < pdf.cursor
      end
    end

    def add_table_box(pdf, table_info, x_offset, y_position)
      table_number = table_info[:number]
      students_at_table = table_info[:students]
      
      # Draw table border
      pdf.stroke_rectangle([x_offset, y_position], 160, 120)
      
      # Table number
      pdf.fill_color branding_options[:secondary_color] || '3b82f6'
      pdf.font 'Helvetica', style: :bold, size: 12
      pdf.text_box "Table #{table_number}", 
                   at: [x_offset + 5, y_position - 5],
                   width: 150, height: 15, align: :center
      
      # Students list
      pdf.fill_color '000000'
      pdf.font 'Helvetica', size: 9
      y_student = y_position - 25
      
      students_at_table.each_with_index do |student, idx|
        break if idx >= 6 # Limit to 6 students visible per table
        
        student_text = format_student_name(student)
        if student.organization.present? && layout_option != 'names_only'
          student_text += " (#{student.organization[0..15]}#{'...' if student.organization.length > 15})"
        end
        
        pdf.text_box student_text,
                     at: [x_offset + 5, y_student],
                     width: 150, height: 12,
                     overflow: :truncate, single_line: true
        y_student -= 15
      end
      
      # Show count if more students than displayed
      if students_at_table.count > 6
        pdf.font 'Helvetica', style: :italic, size: 8
        pdf.text_box "+ #{students_at_table.count - 6} more",
                     at: [x_offset + 5, y_student],
                     width: 150, height: 12
      end
    end

    def add_detailed_seating_chart(pdf)
      tables_data.each do |table_number, table_info|
        if pdf.cursor < 200
          pdf.start_new_page
        end
        
        add_detailed_table_section(pdf, table_info)
        pdf.move_down 20
      end
    end

    def add_detailed_table_section(pdf, table_info)
      table_number = table_info[:number]
      students_at_table = table_info[:students]
      
      # Table header
      pdf.fill_color branding_options[:secondary_color] || '3b82f6'
      pdf.font 'Helvetica', style: :bold, size: 14
      pdf.text "Table #{table_number}"
      pdf.move_down 8
      
      # Students table
      student_data = students_at_table.map do |student|
        row = [
          format_student_name(student),
          format_student_organization(student),
          format_student_title(student)
        ]
        
        if include_explanations? && table_info[:explanation]
          student_explanation = @seating_arrangement.student_explanation(student)
          row << (student_explanation ? student_explanation[0..50] + "..." : "")
        end
        
        row
      end
      
      headers = ["Name", "Organization", "Title"]
      headers << "Explanation" if include_explanations?
      
      pdf.fill_color '000000'
      pdf.font 'Helvetica', size: 9
      pdf.table([headers] + student_data,
                header: true,
                row_colors: ["FFFFFF", "F9FAFB"],
                width: pdf.bounds.width) do |table|
        table.header = true
        table.row(0).font_style = :bold
        table.row(0).background_color = 'E5E7EB'
      end
      
      # Table explanation if available
      if include_explanations? && table_info[:explanation]
        pdf.move_down 8
        pdf.font 'Helvetica', size: 8, style: :italic
        pdf.text "Table Rationale: #{table_info[:explanation]}"
      end
    end

    def add_compact_seating_chart(pdf)
      # Simple list format
      all_students = students.includes(:table_assignments)
                           .joins(:table_assignments)
                           .where(table_assignments: { seating_arrangement: @seating_arrangement })
                           .order('table_assignments.table_number')
      
      current_table = nil
      
      all_students.each do |student|
        assignment = student.table_assignments.find { |ta| ta.seating_arrangement == @seating_arrangement }
        
        if current_table != assignment.table_number
          current_table = assignment.table_number
          pdf.move_down 10 if current_table > 1
          
          pdf.font 'Helvetica', style: :bold, size: 12
          pdf.fill_color branding_options[:secondary_color] || '3b82f6'
          pdf.text "Table #{current_table}"
          pdf.move_down 5
        end
        
        pdf.fill_color '000000'
        pdf.font 'Helvetica', size: 10
        pdf.text "  • #{format_student_name(student)} - #{format_student_organization(student)}"
      end
    end

    def add_diversity_report(pdf)
      return unless formatted_diversity_data.present?
      
      pdf.start_new_page
      pdf.font 'Helvetica', style: :bold, size: 12
      pdf.text "Diversity Analysis", color: branding_options[:primary_color] || '1f2937'
      pdf.move_down 10
      
      diversity_data = formatted_diversity_data
      
      # Gender distribution
      if diversity_data[:gender_distribution].present?
        add_diversity_section(pdf, "Gender Distribution", diversity_data[:gender_distribution])
      end
      
      # Agency level distribution
      if diversity_data[:agency_level_distribution].present?
        add_diversity_section(pdf, "Agency Level Distribution", diversity_data[:agency_level_distribution])
      end
      
      # Department type distribution
      if diversity_data[:department_type_distribution].present?
        add_diversity_section(pdf, "Department Type Distribution", diversity_data[:department_type_distribution])
      end
      
      # Seniority level distribution
      if diversity_data[:seniority_level_distribution].present?
        add_diversity_section(pdf, "Seniority Level Distribution", diversity_data[:seniority_level_distribution])
      end
      
      # Diversity scores
      pdf.move_down 15
      pdf.font 'Helvetica', style: :bold, size: 11
      pdf.text "Diversity Scores"
      pdf.move_down 5
      
      scores_data = [
        ["Interaction Diversity:", "#{(diversity_data[:interaction_diversity_score] * 100).round(1)}%"],
        ["Cross-functional Score:", "#{(diversity_data[:cross_functional_score] * 100).round(1)}%"]
      ]
      
      pdf.font 'Helvetica', size: 10
      pdf.table(scores_data,
                cell_style: { borders: [], padding: [2, 8, 2, 0] },
                column_widths: [150, 100]) do |table|
        table.column(0).font_style = :bold
      end
    end

    def add_diversity_section(pdf, title, distribution_data)
      pdf.font 'Helvetica', style: :bold, size: 11
      pdf.text title
      pdf.move_down 5
      
      table_data = distribution_data.map do |key, value|
        percentage = value.is_a?(Hash) ? value['percentage'] : value
        count = value.is_a?(Hash) ? value['count'] : nil
        
        row = [key.to_s.humanize, "#{percentage.round(1)}%"]
        row << "(#{count})" if count
        row
      end
      
      pdf.font 'Helvetica', size: 10
      pdf.table(table_data,
                cell_style: { borders: [], padding: [2, 8, 2, 0] },
                column_widths: [120, 60, 40])
      pdf.move_down 10
    end

    def add_explanations_section(pdf)
      return unless @seating_arrangement.has_explanations?
      
      pdf.start_new_page
      pdf.font 'Helvetica', style: :bold, size: 12
      pdf.text "Seating Explanations", color: branding_options[:primary_color] || '1f2937'
      pdf.move_down 10
      
      # Overall summary
      if @seating_arrangement.explanation_summary
        pdf.font 'Helvetica', style: :bold, size: 11
        pdf.text "Overall Summary"
        pdf.move_down 5
        pdf.font 'Helvetica', size: 10
        pdf.text @seating_arrangement.explanation_summary
        pdf.move_down 15
      end
      
      # Diversity explanation
      if @seating_arrangement.diversity_explanation
        pdf.font 'Helvetica', style: :bold, size: 11
        pdf.text "Diversity Analysis"
        pdf.move_down 5
        pdf.font 'Helvetica', size: 10
        pdf.text @seating_arrangement.diversity_explanation
        pdf.move_down 15
      end
      
      # Constraint explanation
      if @seating_arrangement.constraint_explanation
        pdf.font 'Helvetica', style: :bold, size: 11
        pdf.text "Constraints Applied"
        pdf.move_down 5
        pdf.font 'Helvetica', size: 10
        pdf.text @seating_arrangement.constraint_explanation
        pdf.move_down 15
      end
      
      # Optimization explanation
      if @seating_arrangement.optimization_explanation
        pdf.font 'Helvetica', style: :bold, size: 11
        pdf.text "Optimization Details"
        pdf.move_down 5
        pdf.font 'Helvetica', size: 10
        pdf.text @seating_arrangement.optimization_explanation
      end
    end

    def add_qr_code(pdf)
      qr_url = qr_code_url
      return unless qr_url
      
      # Move to bottom right corner
      pdf.bounding_box([pdf.bounds.right - 100, 100], width: 80, height: 80) do
        pdf.text "Scan for online chart:", size: 8, align: :center
        pdf.move_down 5
        
        # Placeholder for QR code - would need rqrcode gem
        pdf.stroke_rectangle([10, pdf.cursor], 60, 60)
        pdf.text_box "QR Code", at: [25, pdf.cursor - 30], width: 50, align: :center, size: 8
      end
    end

    def add_footer(pdf)
      pdf.repeat :all do
        pdf.bounding_box([pdf.bounds.left, pdf.bounds.bottom + 25], 
                         width: pdf.bounds.width, height: 20) do
          pdf.font 'Helvetica', size: 8
          pdf.fill_color '666666'
          pdf.text branding_options[:footer_text] || "Generated on #{Date.current.strftime('%B %d, %Y')}", 
                   align: :center
          
          # Page numbers
          pdf.text "Page #{pdf.page_number}", align: :right
        end
      end
    end

    def calculate_tables_per_row
      case page_size.upcase
      when 'A4'
        3
      when 'LEGAL'
        3
      else
        3 # LETTER
      end
    end
  end
end