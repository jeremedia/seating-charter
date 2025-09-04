require 'csv'

module Exports
  class CsvExportService < ExportService
    def generate
      case @export_options[:csv_format] || 'full'
      when 'roster'
        generate_roster_csv
      when 'summary' 
        generate_summary_csv
      when 'assignments'
        generate_assignments_csv
      when 'diversity'
        generate_diversity_csv
      else
        generate_full_csv
      end
    end

    private

    def generate_full_csv
      temp_path = temp_file_path('csv')
      
      CSV.open(temp_path, 'w', write_headers: true) do |csv|
        # Headers
        headers = build_full_headers
        csv << headers
        
        # Data rows
        table_assignments.order(:table_number, :seat_position).each do |assignment|
          csv << build_full_row(assignment)
        end
      end
      
      {
        file_path: temp_path,
        filename: export_filename('csv'),
        content_type: 'text/csv'
      }
    end

    def generate_roster_csv
      temp_path = temp_file_path('csv')
      
      CSV.open(temp_path, 'w', write_headers: true) do |csv|
        # Simple roster format
        csv << [
          "Table Number",
          "Student Name", 
          "Title",
          "Organization",
          "Location"
        ]
        
        table_assignments.order(:table_number, :seat_position).each do |assignment|
          student = assignment.student
          csv << [
            assignment.table_number,
            format_student_name(student),
            format_student_title(student),
            format_student_organization(student),
            student.location || ""
          ]
        end
      end
      
      {
        file_path: temp_path,
        filename: export_filename('csv').sub('.csv', '_roster.csv'),
        content_type: 'text/csv'
      }
    end

    def generate_summary_csv
      temp_path = temp_file_path('csv')
      
      CSV.open(temp_path, 'w', write_headers: true) do |csv|
        # Event summary information
        csv << ["Event Information", ""]
        csv << ["Event Name", seating_event.name]
        csv << ["Date", seating_event.event_date.strftime("%B %d, %Y")]
        csv << ["Type", seating_event.event_type.humanize]
        
        if @seating_arrangement.multi_day?
          csv << ["Day", @seating_arrangement.day_name]
          csv << ["Day Number", @seating_arrangement.day_number]
        end
        
        csv << []
        
        # Arrangement statistics
        csv << ["Arrangement Statistics", ""]
        csv << ["Total Students", students.count]
        csv << ["Total Tables", tables_data.count]
        csv << ["Students per Table", seating_event.table_size]
        csv << ["Utilization", "#{seating_event.utilization_percentage}%"]
        
        csv << []
        
        # Optimization results
        if optimization_scores.present?
          csv << ["Optimization Results", ""]
          csv << ["Overall Score", @seating_arrangement.formatted_score]
          csv << ["Strategy Used", @seating_arrangement.optimization_strategy]
          csv << ["Runtime", "#{@seating_arrangement.runtime_seconds.round(2)} seconds"]
          csv << ["Total Improvements", @seating_arrangement.total_improvements]
          
          if @seating_arrangement.overall_confidence > 0
            csv << ["Confidence Level", "#{(@seating_arrangement.overall_confidence * 100).round(1)}%"]
          end
        end
        
        csv << []
        
        # Table summary
        csv << ["Table Summary", "", ""]
        csv << ["Table Number", "Students Count", "Student Names"]
        
        tables_data.each do |table_number, table_info|
          student_names = table_info[:students].map { |s| format_student_name(s) }.join("; ")
          csv << [table_number, table_info[:students].count, student_names]
        end
      end
      
      {
        file_path: temp_path,
        filename: export_filename('csv').sub('.csv', '_summary.csv'),
        content_type: 'text/csv'
      }
    end

    def generate_assignments_csv
      temp_path = temp_file_path('csv')
      
      CSV.open(temp_path, 'w', write_headers: true) do |csv|
        # Table-by-table format
        tables_data.each_with_index do |(table_number, table_info), index|
          # Add separator between tables
          csv << [] if index > 0
          
          # Table header
          csv << ["Table #{table_number}", "", "", ""]
          csv << ["Seat Position", "Student Name", "Organization", "Title"]
          
          # Student assignments for this table
          table_info[:assignments].sort_by { |a| a.seat_position || 0 }.each do |assignment|
            student = assignment.student
            csv << [
              assignment.seat_position || "",
              format_student_name(student),
              format_student_organization(student),
              format_student_title(student)
            ]
          end
          
          # Table explanation if available
          if include_explanations? && table_info[:explanation]
            csv << []
            csv << ["Table Rationale:", table_info[:explanation], "", ""]
          end
        end
      end
      
      {
        file_path: temp_path,
        filename: export_filename('csv').sub('.csv', '_assignments.csv'),
        content_type: 'text/csv'
      }
    end

    def generate_diversity_csv
      return generate_full_csv unless formatted_diversity_data.present?
      
      temp_path = temp_file_path('csv')
      
      CSV.open(temp_path, 'w', write_headers: true) do |csv|
        diversity_data = formatted_diversity_data
        
        # Overall diversity scores
        csv << ["Diversity Analysis Report", ""]
        csv << ["Generated on", Date.current.strftime('%B %d, %Y')]
        csv << []
        
        csv << ["Overall Diversity Scores", ""]
        csv << ["Metric", "Score"]
        csv << ["Interaction Diversity Score", "#{(diversity_data[:interaction_diversity_score] * 100).round(1)}%"]
        csv << ["Cross-functional Score", "#{(diversity_data[:cross_functional_score] * 100).round(1)}%"]
        
        csv << []
        
        # Gender distribution
        if diversity_data[:gender_distribution].present?
          add_diversity_distribution_to_csv(csv, "Gender Distribution", diversity_data[:gender_distribution])
        end
        
        # Agency level distribution
        if diversity_data[:agency_level_distribution].present?
          add_diversity_distribution_to_csv(csv, "Agency Level Distribution", diversity_data[:agency_level_distribution])
        end
        
        # Department type distribution  
        if diversity_data[:department_type_distribution].present?
          add_diversity_distribution_to_csv(csv, "Department Type Distribution", diversity_data[:department_type_distribution])
        end
        
        # Seniority level distribution
        if diversity_data[:seniority_level_distribution].present?
          add_diversity_distribution_to_csv(csv, "Seniority Level Distribution", diversity_data[:seniority_level_distribution])
        end
        
        # Table-by-table diversity
        csv << ["Table-by-Table Diversity Analysis", "", "", "", ""]
        
        table_headers = ["Table #", "Students Count"]
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
        
        csv << table_headers
        
        tables_data.each do |table_number, table_info|
          table_students = table_info[:students]
          row_data = [table_number, table_students.count]
          
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
          
          csv << row_data
        end
      end
      
      {
        file_path: temp_path,
        filename: export_filename('csv').sub('.csv', '_diversity.csv'),
        content_type: 'text/csv'
      }
    end

    def add_diversity_distribution_to_csv(csv, title, distribution_data)
      csv << [title, "", ""]
      csv << ["Category", "Percentage", "Count"]
      
      distribution_data.each do |key, value|
        percentage = value.is_a?(Hash) ? value['percentage'] : value
        count = value.is_a?(Hash) ? value['count'] : nil
        
        row_data = [key.to_s.humanize, "#{percentage.round(1)}%"]
        row_data << count if count
        
        csv << row_data
      end
      
      csv << []
    end

    def build_full_headers
      headers = [
        "Table Number",
        "Seat Position",
        "Student Name",
        "Title", 
        "Organization",
        "Location"
      ]
      
      # Add attribute columns if they exist
      if students.any? { |s| s.gender.present? }
        headers += ["Gender", "Gender Confidence %"]
      end
      
      if students.any? { |s| s.agency_level.present? }
        headers += ["Agency Level", "Level Confidence %"]
      end
      
      if students.any? { |s| s.department_type.present? }
        headers += ["Department Type", "Dept Confidence %"]
      end
      
      if students.any? { |s| s.seniority_level.present? }
        headers += ["Seniority Level", "Seniority Confidence %"]
      end
      
      if include_explanations?
        headers << "Placement Explanation"
      end
      
      if @seating_arrangement.multi_day?
        headers += ["Previous Interactions", "New Interactions"]
      end
      
      headers
    end

    def build_full_row(assignment)
      student = assignment.student
      
      row = [
        assignment.table_number,
        assignment.seat_position || "",
        format_student_name(student),
        format_student_title(student),
        format_student_organization(student),
        student.location || ""
      ]
      
      # Add attribute data
      if students.any? { |s| s.gender.present? }
        row += [
          student.gender || "",
          student.gender_confidence > 0 ? (student.gender_confidence * 100).round(1) : ""
        ]
      end
      
      if students.any? { |s| s.agency_level.present? }
        row += [
          student.agency_level || "",
          student.agency_level_confidence > 0 ? (student.agency_level_confidence * 100).round(1) : ""
        ]
      end
      
      if students.any? { |s| s.department_type.present? }
        row += [
          student.department_type || "",
          student.department_type_confidence > 0 ? (student.department_type_confidence * 100).round(1) : ""
        ]
      end
      
      if students.any? { |s| s.seniority_level.present? }
        row += [
          student.seniority_level || "",
          student.seniority_level_confidence > 0 ? (student.seniority_level_confidence * 100).round(1) : ""
        ]
      end
      
      if include_explanations?
        explanation = @seating_arrangement.student_explanation(student)
        row << (explanation || "")
      end
      
      if @seating_arrangement.multi_day?
        # Add interaction data for multi-day arrangements
        previous_interactions = calculate_previous_interactions(student)
        new_interactions = calculate_new_interactions(student, assignment)
        row += [previous_interactions, new_interactions]
      end
      
      row
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

    def calculate_previous_interactions(student)
      return 0 unless @seating_arrangement.multi_day?
      
      # Count interactions from previous days in the series
      previous_arrangements = seating_event.seating_arrangements
                                           .where('day_number < ?', @seating_arrangement.day_number)
      
      interaction_count = 0
      previous_arrangements.each do |prev_arrangement|
        prev_assignment = student.table_assignments.find { |ta| ta.seating_arrangement == prev_arrangement }
        next unless prev_assignment
        
        prev_table_students = Student.joins(:table_assignments)
                                    .where(table_assignments: { 
                                      seating_arrangement: prev_arrangement,
                                      table_number: prev_assignment.table_number 
                                    })
                                    .where.not(id: student.id)
        
        interaction_count += prev_table_students.count
      end
      
      interaction_count
    end

    def calculate_new_interactions(student, current_assignment)
      return 0 unless @seating_arrangement.multi_day?
      
      # Find students at current table
      current_table_students = Student.joins(:table_assignments)
                                     .where(table_assignments: { 
                                       seating_arrangement: @seating_arrangement,
                                       table_number: current_assignment.table_number 
                                     })
                                     .where.not(id: student.id)
      
      # Count how many are new interactions
      new_interaction_count = 0
      previous_arrangements = seating_event.seating_arrangements
                                           .where('day_number < ?', @seating_arrangement.day_number)
      
      current_table_students.each do |table_mate|
        # Check if they've interacted before
        has_previous_interaction = false
        
        previous_arrangements.each do |prev_arrangement|
          student_prev_assignment = student.table_assignments.find { |ta| ta.seating_arrangement == prev_arrangement }
          mate_prev_assignment = table_mate.table_assignments.find { |ta| ta.seating_arrangement == prev_arrangement }
          
          if student_prev_assignment && mate_prev_assignment && 
             student_prev_assignment.table_number == mate_prev_assignment.table_number
            has_previous_interaction = true
            break
          end
        end
        
        new_interaction_count += 1 unless has_previous_interaction
      end
      
      new_interaction_count
    end
  end
end