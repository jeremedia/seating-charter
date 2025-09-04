require 'caxlsx'

module Exports
  class ExcelExportService < ExportService
    def generate
      package = Caxlsx::Package.new
      
      # Create main seating chart worksheet
      add_seating_chart_worksheet(package)
      
      # Add student roster worksheet
      add_student_roster_worksheet(package)
      
      # Add diversity analysis worksheet if requested
      add_diversity_worksheet(package) if include_diversity_report?
      
      # Add explanations worksheet if available
      add_explanations_worksheet(package) if include_explanations?
      
      # Add table assignments worksheet (detailed view)
      add_table_assignments_worksheet(package)
      
      # Add summary worksheet
      add_summary_worksheet(package)
      
      # Generate and return the Excel file
      temp_path = temp_file_path('xlsx')
      package.serialize(temp_path)
      
      {
        file_path: temp_path,
        filename: export_filename('xlsx'),
        content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      }
    end

    private

    def add_seating_chart_worksheet(package)
      package.workbook.add_worksheet(name: "Seating Chart") do |sheet|
        # Title and header information
        add_excel_header(sheet)
        
        # Event details
        sheet.add_row []
        sheet.add_row ["Event Details"], style: header_style(package)
        sheet.add_row ["Event Name:", seating_event.name]
        sheet.add_row ["Date:", seating_event.event_date.strftime("%B %d, %Y")]
        sheet.add_row ["Type:", seating_event.event_type.humanize]
        sheet.add_row ["Tables:", "#{tables_data.count} tables"]
        sheet.add_row ["Students:", "#{students.count} students"]
        sheet.add_row ["Table Size:", "#{seating_event.table_size} students per table"]
        
        if @seating_arrangement.multi_day?
          sheet.add_row ["Day:", @seating_arrangement.day_name]
        end
        
        # Visual seating chart representation
        sheet.add_row []
        sheet.add_row ["Seating Layout"], style: header_style(package)
        
        add_visual_seating_layout(sheet, package)
        
        # Apply column widths
        sheet.column_widths 15, 25, 25, 25, 25, 25, 25
      end
    end

    def add_visual_seating_layout(sheet, package)
      # Create a visual representation of tables
      tables_per_row = 4
      max_table_number = tables_data.keys.max
      rows_needed = (max_table_number / tables_per_row.to_f).ceil
      
      # Add column headers for visual layout
      headers = [""] + (1..tables_per_row).map { |i| "Table Position #{i}" }
      sheet.add_row headers, style: subheader_style(package)
      
      (0...rows_needed).each do |row|
        row_data = ["Row #{row + 1}"]
        
        (1..tables_per_row).each do |col|
          table_number = row * tables_per_row + col
          if table_number <= max_table_number && tables_data[table_number]
            table_info = tables_data[table_number]
            students_names = table_info[:students].map { |s| format_student_name(s) }
            cell_content = "Table #{table_number}\n#{students_names.join("\n")}"
            row_data << cell_content
          else
            row_data << ""
          end
        end
        
        sheet.add_row row_data
        # Set row height for multi-line content
        sheet.rows.last.height = 80
      end
    end

    def add_student_roster_worksheet(package)
      package.workbook.add_worksheet(name: "Student Roster") do |sheet|
        # Headers
        headers = [
          "Table #",
          "Seat Position", 
          "Student Name",
          "Title",
          "Organization",
          "Location"
        ]
        
        # Add attribute columns if they exist
        if students.any? { |s| s.gender.present? }
          headers += ["Gender", "Gender Confidence"]
        end
        
        if students.any? { |s| s.agency_level.present? }
          headers += ["Agency Level", "Level Confidence"]
        end
        
        if students.any? { |s| s.department_type.present? }
          headers += ["Department Type", "Dept Confidence"]
        end
        
        if students.any? { |s| s.seniority_level.present? }
          headers += ["Seniority Level", "Seniority Confidence"]
        end
        
        if include_explanations?
          headers << "Placement Explanation"
        end
        
        sheet.add_row headers, style: header_style(package)
        
        # Add student data
        table_assignments.order(:table_number, :seat_position).each do |assignment|
          student = assignment.student
          row_data = [
            assignment.table_number,
            assignment.seat_position || "",
            format_student_name(student),
            format_student_title(student),
            format_student_organization(student),
            student.location || ""
          ]
          
          # Add attribute data
          if students.any? { |s| s.gender.present? }
            row_data += [
              student.gender || "",
              student.gender_confidence > 0 ? "#{(student.gender_confidence * 100).round(1)}%" : ""
            ]
          end
          
          if students.any? { |s| s.agency_level.present? }
            row_data += [
              student.agency_level || "",
              student.agency_level_confidence > 0 ? "#{(student.agency_level_confidence * 100).round(1)}%" : ""
            ]
          end
          
          if students.any? { |s| s.department_type.present? }
            row_data += [
              student.department_type || "",
              student.department_type_confidence > 0 ? "#{(student.department_type_confidence * 100).round(1)}%" : ""
            ]
          end
          
          if students.any? { |s| s.seniority_level.present? }
            row_data += [
              student.seniority_level || "",
              student.seniority_level_confidence > 0 ? "#{(student.seniority_level_confidence * 100).round(1)}%" : ""
            ]
          end
          
          if include_explanations?
            explanation = @seating_arrangement.student_explanation(student)
            row_data << (explanation || "")
          end
          
          sheet.add_row row_data
        end
        
        # Auto-fit columns
        sheet.column_widths nil, nil, 20, 25, 25, 15, 12, 8, 15, 8, 15, 8, 15, 8, 40
      end
    end

    def add_diversity_worksheet(package)
      return unless formatted_diversity_data.present?
      
      package.workbook.add_worksheet(name: "Diversity Analysis") do |sheet|
        sheet.add_row ["Diversity Analysis Report"], style: header_style(package)
        sheet.add_row []
        
        diversity_data = formatted_diversity_data
        
        # Gender distribution
        if diversity_data[:gender_distribution].present?
          add_diversity_section_to_sheet(sheet, package, "Gender Distribution", diversity_data[:gender_distribution])
        end
        
        # Agency level distribution
        if diversity_data[:agency_level_distribution].present?
          add_diversity_section_to_sheet(sheet, package, "Agency Level Distribution", diversity_data[:agency_level_distribution])
        end
        
        # Department type distribution
        if diversity_data[:department_type_distribution].present?
          add_diversity_section_to_sheet(sheet, package, "Department Type Distribution", diversity_data[:department_type_distribution])
        end
        
        # Seniority level distribution
        if diversity_data[:seniority_level_distribution].present?
          add_diversity_section_to_sheet(sheet, package, "Seniority Level Distribution", diversity_data[:seniority_level_distribution])
        end
        
        # Overall diversity scores
        sheet.add_row []
        sheet.add_row ["Overall Diversity Scores"], style: subheader_style(package)
        sheet.add_row ["Metric", "Score"], style: header_style(package)
        sheet.add_row ["Interaction Diversity Score", "#{(diversity_data[:interaction_diversity_score] * 100).round(1)}%"]
        sheet.add_row ["Cross-functional Score", "#{(diversity_data[:cross_functional_score] * 100).round(1)}%"]
        
        # Table-by-table diversity breakdown
        sheet.add_row []
        sheet.add_row ["Table-by-Table Diversity"], style: subheader_style(package)
        
        table_headers = ["Table #", "Students Count"]
        
        # Add headers for each diversity metric that has data
        if diversity_data[:gender_distribution].present?
          table_headers << "Gender Diversity"
        end
        if diversity_data[:agency_level_distribution].present?
          table_headers << "Level Diversity"
        end
        if diversity_data[:department_type_distribution].present?
          table_headers << "Dept Diversity"
        end
        if diversity_data[:seniority_level_distribution].present?
          table_headers << "Seniority Diversity"
        end
        
        sheet.add_row table_headers, style: header_style(package)
        
        # Add table diversity data
        tables_data.each do |table_number, table_info|
          table_students = table_info[:students]
          row_data = [table_number, table_students.count]
          
          # Calculate diversity for each metric
          if diversity_data[:gender_distribution].present?
            gender_diversity = calculate_table_diversity(table_students, :gender)
            row_data << "#{(gender_diversity * 100).round(1)}%"
          end
          
          if diversity_data[:agency_level_distribution].present?
            level_diversity = calculate_table_diversity(table_students, :agency_level)
            row_data << "#{(level_diversity * 100).round(1)}%"
          end
          
          if diversity_data[:department_type_distribution].present?
            dept_diversity = calculate_table_diversity(table_students, :department_type)
            row_data << "#{(dept_diversity * 100).round(1)}%"
          end
          
          if diversity_data[:seniority_level_distribution].present?
            seniority_diversity = calculate_table_diversity(table_students, :seniority_level)
            row_data << "#{(seniority_diversity * 100).round(1)}%"
          end
          
          sheet.add_row row_data
        end
        
        sheet.column_widths 15, 15, 18, 18, 18, 18
      end
    end

    def add_diversity_section_to_sheet(sheet, package, title, distribution_data)
      sheet.add_row [title], style: subheader_style(package)
      sheet.add_row ["Category", "Percentage", "Count"], style: header_style(package)
      
      distribution_data.each do |key, value|
        percentage = value.is_a?(Hash) ? value['percentage'] : value
        count = value.is_a?(Hash) ? value['count'] : nil
        
        row_data = [key.to_s.humanize, "#{percentage.round(1)}%"]
        row_data << count if count
        
        sheet.add_row row_data
      end
      
      sheet.add_row []
    end

    def add_explanations_worksheet(package)
      return unless @seating_arrangement.has_explanations?
      
      package.workbook.add_worksheet(name: "Explanations") do |sheet|
        sheet.add_row ["Seating Explanations"], style: header_style(package)
        sheet.add_row []
        
        # Overall summary
        if @seating_arrangement.explanation_summary
          sheet.add_row ["Overall Summary"], style: subheader_style(package)
          sheet.add_row [@seating_arrangement.explanation_summary]
          sheet.add_row []
        end
        
        # Table explanations
        sheet.add_row ["Table Explanations"], style: subheader_style(package)
        sheet.add_row ["Table #", "Explanation"], style: header_style(package)
        
        tables_data.each do |table_number, table_info|
          explanation = table_info[:explanation] || "No explanation available"
          sheet.add_row [table_number, explanation]
        end
        
        sheet.add_row []
        
        # Student-specific explanations
        sheet.add_row ["Student Placement Explanations"], style: subheader_style(package)
        sheet.add_row ["Student Name", "Table #", "Explanation"], style: header_style(package)
        
        students.each do |student|
          assignment = student.table_assignments.find { |ta| ta.seating_arrangement == @seating_arrangement }
          explanation = @seating_arrangement.student_explanation(student) || "No specific explanation"
          sheet.add_row [format_student_name(student), assignment.table_number, explanation]
        end
        
        # Set column widths for readability
        sheet.column_widths 25, 60, nil
      end
    end

    def add_table_assignments_worksheet(package)
      package.workbook.add_worksheet(name: "Table Assignments") do |sheet|
        tables_data.each_with_index do |(table_number, table_info), index|
          if index > 0
            sheet.add_row [] # Add spacing between tables
          end
          
          sheet.add_row ["Table #{table_number}"], style: header_style(package)
          
          # Table headers
          headers = ["Seat Position", "Student Name", "Organization", "Title"]
          sheet.add_row headers, style: subheader_style(package)
          
          # Student data for this table
          table_info[:assignments].sort_by { |a| a.seat_position || 0 }.each do |assignment|
            student = assignment.student
            sheet.add_row [
              assignment.seat_position || "",
              format_student_name(student),
              format_student_organization(student),
              format_student_title(student)
            ]
          end
          
          # Table explanation if available
          if include_explanations? && table_info[:explanation]
            sheet.add_row []
            sheet.add_row ["Table Rationale:", table_info[:explanation]]
          end
        end
        
        sheet.column_widths 15, 25, 25, 30
      end
    end

    def add_summary_worksheet(package)
      package.workbook.add_worksheet(name: "Summary") do |sheet|
        sheet.add_row ["Seating Arrangement Summary"], style: header_style(package)
        sheet.add_row []
        
        # Event information
        sheet.add_row ["Event Information"], style: subheader_style(package)
        sheet.add_row ["Event Name", seating_event.name]
        sheet.add_row ["Date", seating_event.event_date.strftime("%B %d, %Y")]
        sheet.add_row ["Type", seating_event.event_type.humanize]
        
        if @seating_arrangement.multi_day?
          sheet.add_row ["Day", @seating_arrangement.day_name]
          sheet.add_row ["Day Number", @seating_arrangement.day_number]
        end
        
        sheet.add_row []
        
        # Arrangement statistics
        sheet.add_row ["Arrangement Statistics"], style: subheader_style(package)
        sheet.add_row ["Total Students", students.count]
        sheet.add_row ["Total Tables", tables_data.count]
        sheet.add_row ["Students per Table", seating_event.table_size]
        sheet.add_row ["Utilization", "#{seating_event.utilization_percentage}%"]
        
        sheet.add_row []
        
        # Optimization results
        if optimization_scores.present?
          sheet.add_row ["Optimization Results"], style: subheader_style(package)
          sheet.add_row ["Overall Score", @seating_arrangement.formatted_score]
          sheet.add_row ["Strategy Used", @seating_arrangement.optimization_strategy]
          sheet.add_row ["Runtime", "#{@seating_arrangement.runtime_seconds.round(2)} seconds"]
          sheet.add_row ["Total Improvements", @seating_arrangement.total_improvements]
          
          if @seating_arrangement.overall_confidence > 0
            sheet.add_row ["Confidence Level", "#{(@seating_arrangement.overall_confidence * 100).round(1)}%"]
          end
        end
        
        sheet.add_row []
        
        # Table summary
        sheet.add_row ["Table Summary"], style: subheader_style(package)
        sheet.add_row ["Table #", "Students Count", "Student Names"], style: header_style(package)
        
        tables_data.each do |table_number, table_info|
          student_names = table_info[:students].map { |s| format_student_name(s) }.join(", ")
          sheet.add_row [table_number, table_info[:students].count, student_names]
        end
        
        sheet.column_widths 20, 15, 60
      end
    end

    def add_excel_header(sheet)
      branding = branding_options
      sheet.add_row [branding[:organization_name] || 'CHDS Seating Charter'], 
                   style: title_style(sheet.workbook)
      sheet.add_row [branding[:header_text] || seating_event.name]
      
      if @seating_arrangement.multi_day?
        sheet.add_row [@seating_arrangement.day_name]
      end
      
      sheet.add_row [branding[:footer_text] || "Generated on #{Date.current.strftime('%B %d, %Y')}"]
    end

    def calculate_table_diversity(table_students, attribute)
      return 0.0 if table_students.empty?
      
      values = table_students.map { |s| s.send(attribute) }.compact
      return 0.0 if values.empty?
      
      unique_values = values.uniq.count
      total_values = values.count
      
      return 0.0 if total_values <= 1
      
      # Simple diversity metric: unique values / total possible pairs
      unique_values.to_f / total_values
    end

    # Styling methods
    def title_style(workbook)
      workbook.styles.add_style sz: 16, b: true, alignment: { horizontal: :center }
    end

    def header_style(package)
      package.workbook.styles.add_style b: true, 
                                        bg_color: "E5E7EB", 
                                        border: { style: :thin, color: "000000" }
    end

    def subheader_style(package)
      package.workbook.styles.add_style b: true, sz: 12, bg_color: "F3F4F6"
    end
  end
end