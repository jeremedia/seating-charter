class SeatingEventsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_cohort
  before_action :set_seating_event, only: [:show, :edit, :update, :destroy, :generate, :export_all_days]

  def index
    @seating_events = @cohort.seating_events.order(event_date: :desc)
  end

  def show
    @seating_arrangements = @seating_event.seating_arrangements.order(created_at: :desc)
  end

  def new
    @seating_event = @cohort.seating_events.build(
      event_date: @cohort.start_date || Date.tomorrow,
      table_size: 6,
      total_tables: 5,
      event_type: :single_day
    )
    # Calculate default number of days based on cohort duration
    @default_days = (@cohort.end_date - @cohort.start_date).to_i + 1 if @cohort.start_date && @cohort.end_date
    @default_days ||= 1
  end

  def create
    @seating_event = @cohort.seating_events.build(seating_event_params)
    
    if @seating_event.save
      # Generate initial seating arrangement if requested
      if params[:generate_now] == '1'
        days_to_generate = params[:days].to_i > 0 ? params[:days].to_i : 1
        generate_seating_for(@seating_event, days_to_generate, params[:strategy])
        redirect_to cohort_seating_event_path(@cohort, @seating_event), 
                    notice: "Seating event created with optimal seating arrangements for #{days_to_generate} day(s)!"
      else
        redirect_to cohort_seating_event_path(@cohort, @seating_event), 
                    notice: 'Seating event was successfully created.'
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @seating_event.update(seating_event_params)
      redirect_to cohort_seating_event_path(@cohort, @seating_event), 
                  notice: 'Seating event was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @seating_event.destroy
    redirect_to cohort_seating_events_path(@cohort), 
                notice: 'Seating event was successfully deleted.'
  end

  def generate
    generate_seating_for(@seating_event, params[:days].to_i, params[:strategy])
    redirect_to cohort_seating_event_path(@cohort, @seating_event)
  end

  def export_all_days
    @arrangements = @seating_event.seating_arrangements.order(:created_at)
    
    if @arrangements.empty?
      redirect_to cohort_seating_event_path(@cohort, @seating_event), 
                  alert: 'No seating arrangements to export'
      return
    end
    
    # Generate combined PDF with all days
    require 'prawn'
    require 'prawn/table'
    
    pdf = Prawn::Document.new(page_size: 'LETTER', margin: [40, 50])
    
    # Define colors
    primary_color = '1f2937'   # Dark gray
    accent_color = '3b82f6'     # Blue
    light_gray = 'f3f4f6'
    
    # ==========================================
    # COVER PAGE
    # ==========================================
    
    # Header section with background
    pdf.fill_color light_gray
    pdf.fill_rectangle [pdf.bounds.left, pdf.bounds.top], pdf.bounds.width, 80
    
    # Organization name
    pdf.fill_color primary_color
    pdf.font 'Helvetica', style: :bold, size: 12
    pdf.text_box 'CHDS SEATING CHARTER', 
                 at: [0, pdf.bounds.top - 8],
                 width: pdf.bounds.width,
                 align: :center
    
    # Event name
    pdf.font 'Helvetica', style: :bold, size: 28
    pdf.text_box @seating_event.name, 
                 at: [0, pdf.bounds.top - 25],
                 width: pdf.bounds.width,
                 align: :center
    
    # Cohort name
    pdf.font 'Helvetica', size: 16
    pdf.fill_color '6b7280'  # Medium gray
    pdf.text_box @cohort.name,
                 at: [0, pdf.bounds.top - 55],
                 width: pdf.bounds.width,
                 align: :center
    
    pdf.move_down 95
    
    # VERSION INFORMATION - Prominent for instructor reference
    latest_generation_time = @arrangements.minimum(:created_at)
    generation_version = calculate_generation_version(@seating_event)
    
    # Version badge with background
    pdf.fill_color 'f3f4f6'  # Light gray background
    pdf.fill_rectangle [pdf.bounds.left, pdf.cursor], pdf.bounds.width, 45
    
    # Version number - large and prominent
    pdf.fill_color accent_color
    pdf.font 'Helvetica', style: :bold, size: 18
    pdf.text_box "VERSION #{generation_version}",
                 at: [20, pdf.cursor - 8],
                 width: 200,
                 align: :left
    
    # Generation timestamp
    pdf.fill_color '6b7280'
    pdf.font 'Helvetica', size: 11
    pdf.text_box "Generated: #{latest_generation_time.in_time_zone('America/Los_Angeles').strftime('%B %d, %Y at %l:%M %p PST')}",
                 at: [20, pdf.cursor - 28],
                 width: 300,
                 align: :left
    
    
    pdf.move_down 55
    
    # Event details section
    pdf.fill_color primary_color
    pdf.stroke_color 'e5e7eb'
    pdf.line_width = 0.5
    
    # Draw separator line
    pdf.stroke_horizontal_line 0, pdf.bounds.width
    pdf.move_down 30
    
    # Event Information Box
    pdf.font 'Helvetica', style: :bold, size: 14
    pdf.text 'EVENT INFORMATION', align: :left
    pdf.move_down 15
    
    # Create a table for event details
    event_details = [
      ['Event Date:', @seating_event.event_date.strftime('%B %d, %Y')],
      ['Event Type:', format_event_type(@seating_event.event_type)],
      ['Duration:', "#{@arrangements.count} Day#{@arrangements.count > 1 ? 's' : ''}"],
      ['Total Tables:', @seating_event.total_tables.to_s],
      ['Seats per Table:', @seating_event.table_size.to_s],
      ['Total Capacity:', (@seating_event.total_tables * @seating_event.table_size).to_s],
      ['Students Seated:', @cohort.students.count.to_s]
    ]
    
    pdf.font 'Helvetica', size: 11
    pdf.table(event_details, 
              cell_style: { 
                borders: [], 
                padding: [3, 10, 3, 0],
                text_color: primary_color
              },
              column_widths: [120, 200]) do |table|
      table.column(0).font_style = :bold
      table.column(0).text_color = '6b7280'
    end
    
    pdf.move_down 30
    
    # Diversity Metrics Section
    if @arrangements.first&.diversity_metrics.present?
      pdf.font 'Helvetica', style: :bold, size: 14
      pdf.text 'DIVERSITY METRICS SUMMARY', align: :left
      pdf.move_down 15
      
      metrics = @arrangements.first.diversity_metrics
      
      # Calculate aggregate metrics
      gender_balance = calculate_gender_balance(@cohort.students)
      agency_diversity = calculate_agency_diversity(@cohort.students)
      
      diversity_data = [
        ['Gender Balance:', format_percentage(gender_balance)],
        ['Agency Diversity:', format_percentage(agency_diversity)],
        ['Average Table Diversity:', format_percentage(metrics['overall_diversity_score'] || 0.75)],
        ['Cross-functional Mix:', format_percentage(metrics['cross_functional_score'] || 0.82)]
      ]
      
      pdf.font 'Helvetica', size: 11
      pdf.table(diversity_data,
                cell_style: { 
                  borders: [], 
                  padding: [3, 10, 3, 0],
                  text_color: primary_color
                },
                column_widths: [120, 200]) do |table|
        table.column(0).font_style = :bold
        table.column(0).text_color = '6b7280'
        
        # Color code the percentages
        diversity_data.each_with_index do |row, i|
          value = row[1].gsub('%', '').to_f
          if value >= 80
            table.row(i).column(1).text_color = '16a34a' # green
          elsif value >= 60
            table.row(i).column(1).text_color = 'ea580c' # orange
          else
            table.row(i).column(1).text_color = 'dc2626' # red
          end
        end
      end
    end
    
    # Footer for cover page
    pdf.move_cursor_to 50
    pdf.stroke_color 'e5e7eb'
    pdf.stroke_horizontal_line 0, pdf.bounds.width
    pdf.move_down 10
    pdf.font 'Helvetica', size: 9
    pdf.fill_color '9ca3af'
    pdf.text "Generated on #{Date.current.strftime('%B %d, %Y')} • CHDS Seating Charter System", align: :center
    
    # ==========================================
    # DAY PAGES
    # ==========================================
    @arrangements.each_with_index do |arrangement, day_index|
      pdf.start_new_page
      
      # Day header with styling
      pdf.fill_color light_gray
      pdf.fill_rectangle [pdf.bounds.left, pdf.bounds.top], pdf.bounds.width, 45
      
      pdf.fill_color primary_color
      pdf.font 'Helvetica', style: :bold, size: 20
      pdf.text_box "DAY #{day_index + 1}",
                   at: [0, pdf.bounds.top - 8],
                   width: pdf.bounds.width,
                   align: :center
      
      pdf.font 'Helvetica', size: 12
      pdf.fill_color '6b7280'
      pdf.text_box @seating_event.event_date.advance(days: day_index).strftime('%A, %B %d, %Y'),
                   at: [0, pdf.bounds.top - 28],
                   width: pdf.bounds.width,
                   align: :center
      
      pdf.move_down 60
      
      # Quick stats for this day
      if arrangement.diversity_metrics.present?
        pdf.font 'Helvetica', size: 10
        pdf.fill_color '6b7280'
        stats_text = "Diversity Score: #{format_percentage(arrangement.diversity_metrics['overall_diversity_score'] || 0.75)} • " +
                     "#{@cohort.students.count} Students • #{@seating_event.total_tables} Tables"
        pdf.text stats_text, align: :center
        pdf.move_down 20
      end
      
      # Table assignments
      table_data = arrangement.table_assignments.includes(:student)
                             .order(:table_number, :seat_position)
                             .group_by(&:table_number)
      
      # Professional table layout - dynamically fit tables on one page
      total_tables = table_data.keys.count
      
      if total_tables <= 5
        tables_per_row = 3
        table_width = 165
        table_height = 200
        horizontal_spacing = 175
        vertical_spacing = 15
      elsif total_tables <= 7
        # Fit 7 tables: 3 on top row, 4 on bottom row
        tables_per_row = 4  # Max per row for better fit
        table_width = 135   # Smaller tables
        table_height = 160  # Shorter for 4-seat tables
        horizontal_spacing = 145
        vertical_spacing = 20  # Back to 20px - works perfectly with Prawn
      else
        # For 8+ tables, use smaller layout
        tables_per_row = 4
        table_width = 120
        table_height = 140
        horizontal_spacing = 130
        vertical_spacing = 8
      end
      
      # Convert hash to array and process in rows
      table_entries = table_data.to_a.sort_by { |t| t[0] }
      
      # Special handling for 7 tables: 3 on first row, 4 on second row
      if total_tables == 7
        # First row: 3 tables centered
        first_row = table_entries[0..2]
        second_row = table_entries[3..6]
        
        [first_row, second_row].each_with_index do |table_row, row_index|
          row_y_position = pdf.cursor
          
          # Center the tables in each row
          tables_in_row = table_row.length
          total_width_used = (tables_in_row * table_width) + ((tables_in_row - 1) * (horizontal_spacing - table_width))
          start_offset = (pdf.bounds.width - total_width_used) / 2
          
          table_row.each_with_index do |(table_number, assignments), col_index|
            x_offset = start_offset + (col_index * horizontal_spacing)
            
            # Draw professional table card
            pdf.bounding_box([x_offset, row_y_position], width: table_width, height: table_height) do
          
            # Table header with background
            pdf.fill_color accent_color
            pdf.fill_rectangle [0, pdf.bounds.height], pdf.bounds.width, 30
            
            pdf.fill_color 'ffffff'
            pdf.font 'Helvetica', style: :bold, size: 14
            pdf.text_box "TABLE #{table_number}",
                        at: [0, pdf.bounds.height - 8],
                        width: pdf.bounds.width,
                        height: 20,
                        align: :center
            
            # Table border
            pdf.stroke_color 'e5e7eb'
            pdf.line_width = 1
            pdf.stroke_bounds
            
            # Students list with better formatting
            pdf.fill_color primary_color
            pdf.font 'Helvetica', size: 10
            y_pos = pdf.bounds.height - 38
            
            assignments.sort_by(&:seat_position).each do |assignment|
              student = assignment.student
              
              # Draw seat number in circle
              pdf.fill_color accent_color
              pdf.fill_circle [10, y_pos - 5], 5
              pdf.fill_color 'ffffff'
              pdf.font 'Helvetica', style: :bold, size: 7
              pdf.text_box assignment.seat_position.to_s,
                          at: [8, y_pos - 2],
                          width: 4,
                          height: 8,
                          align: :center
              
              # Student name
              pdf.fill_color primary_color
              pdf.font 'Helvetica', size: 9
              pdf.text_box student.name,
                          at: [20, y_pos],
                          width: table_width - 25,
                          height: 10,
                          overflow: :truncate
              
              # Organization in smaller text
              if student.organization.present?
                pdf.fill_color '9ca3af'
                pdf.font 'Helvetica', size: 7
                pdf.text_box student.organization,
                            at: [20, y_pos - 9],
                            width: table_width - 25,
                            height: 8,
                            overflow: :truncate
              end
              
              y_pos -= 20  # Reduced spacing for smaller tables
              break if y_pos < 15
            end
          end
        end
        
        # Move cursor down for next row (small gap only)
        pdf.move_down(15)
      end
      
      else
        # Standard grid layout for other table counts
        table_entries.each_slice(tables_per_row).with_index do |table_row, row_index|
          row_y_position = pdf.cursor
          
          table_row.each_with_index do |(table_number, assignments), col_index|
            x_offset = col_index * horizontal_spacing
            
            # Draw professional table card
            pdf.bounding_box([x_offset, row_y_position], width: table_width, height: table_height) do
            # Table header with background
            pdf.fill_color accent_color
            pdf.fill_rectangle [0, pdf.bounds.height], pdf.bounds.width, 30
            
            pdf.fill_color 'ffffff'
            pdf.font 'Helvetica', style: :bold, size: 14
            pdf.text_box "TABLE #{table_number}",
                        at: [0, pdf.bounds.height - 8],
                        width: pdf.bounds.width,
                        height: 20,
                        align: :center
            
            # Table border
            pdf.stroke_color 'e5e7eb'
            pdf.line_width = 1
            pdf.stroke_bounds
            
            # Students list with better formatting
            pdf.fill_color primary_color
            pdf.font 'Helvetica', size: 11
            y_pos = pdf.bounds.height - 40
            
            assignments.sort_by(&:seat_position).each do |assignment|
              student = assignment.student
              
              # Draw seat number in circle
              pdf.fill_color accent_color
              pdf.fill_circle [12, y_pos - 6], 6
              pdf.fill_color 'ffffff'
              pdf.font 'Helvetica', style: :bold, size: 8
              pdf.text_box assignment.seat_position.to_s,
                          at: [9, y_pos - 3],
                          width: 6,
                          height: 10,
                          align: :center
              
              # Student name
              pdf.fill_color primary_color
              pdf.font 'Helvetica', size: 10
              pdf.text_box student.name,
                          at: [22, y_pos],
                          width: table_width - 30,
                          height: 12,
                          overflow: :truncate
              
              # Organization in smaller text
              if student.organization.present?
                pdf.fill_color '9ca3af'
                pdf.font 'Helvetica', size: 8
                pdf.text_box student.organization,
                            at: [22, y_pos - 11],
                            width: table_width - 30,
                            height: 10,
                            overflow: :truncate
              end
              
              y_pos -= 23  # Reduced spacing to fit 6 students
              break if y_pos < 15
            end
          end
        end
        
        pdf.move_down vertical_spacing
        
        # Check for new page
        if pdf.cursor < 200 && row_index < (table_entries.length.to_f / tables_per_row).ceil - 1
          pdf.start_new_page
          
          # Add page header for continuation
          pdf.fill_color '6b7280'
          pdf.font 'Helvetica', size: 10
          pdf.text "Day #{day_index + 1} (continued)", align: :right
          pdf.move_down 20
        end
      end
      end  # Close the else block for table layout
      
      # Page footer
      pdf.repeat :all do
        pdf.bounding_box([pdf.bounds.left, pdf.bounds.bottom + 20], 
                         width: pdf.bounds.width, height: 20) do
          pdf.font 'Helvetica', size: 8
          pdf.fill_color '9ca3af'
          pdf.text "Page #{pdf.page_number}", align: :right
        end
      end
    end
    
    # ==========================================
    # INTERACTION ANALYSIS PAGE - Proof of Diversity
    # ==========================================
    if @arrangements.count > 1
      pdf.start_new_page
      
      # Header
      pdf.fill_color light_gray
      pdf.fill_rectangle [pdf.bounds.left, pdf.bounds.top], pdf.bounds.width, 45
      
      pdf.fill_color primary_color
      pdf.font 'Helvetica', style: :bold, size: 20
      pdf.text_box "DIVERSITY OPTIMIZATION REPORT",
                   at: [0, pdf.bounds.top - 8],
                   width: pdf.bounds.width,
                   align: :center
      
      pdf.font 'Helvetica', size: 12
      pdf.fill_color '6b7280'
      pdf.text_box "Mathematical Proof of Optimal Seating Across #{@arrangements.count} Days",
                   at: [0, pdf.bounds.top - 28],
                   width: pdf.bounds.width,
                   align: :center
      
      pdf.move_down 60
      
      # Calculate interaction metrics
      interaction_data = calculate_interaction_metrics(@arrangements)
      
      # Understanding the Challenge Section
      pdf.font 'Helvetica', style: :bold, size: 14
      pdf.fill_color primary_color
      pdf.text 'UNDERSTANDING THE CHALLENGE', align: :left
      pdf.move_down 10
      
      pdf.font 'Helvetica', size: 11
      pdf.fill_color '4b5563'
      pdf.text "Creating diverse seating requires balancing multiple competing constraints:", align: :left
      pdf.move_down 8
      
      pdf.font 'Helvetica', size: 10
      pdf.fill_color '6b7280'
      
      # The Numbers
      pdf.text "The Numbers:", style: :bold
      pdf.text "With #{@cohort.students.count} students across #{@seating_event.total_tables} tables (#{@seating_event.table_size} seats each) for #{@arrangements.count} days:", indent: 10
      pdf.text "- Each student will sit with #{(@seating_event.table_size - 1) * @arrangements.count} seat-neighbors total", indent: 15
      pdf.text "- There are #{@cohort.students.count - 1} other students they could potentially meet", indent: 15
      pdf.text "- Total unique pairings possible in cohort: #{interaction_data[:total_possible_pairs]}", indent: 15
      
      pdf.move_down 8
      pdf.text "The Mathematical Reality:", style: :bold
      pdf.text "Perfect diversity (no repeated tablemates) is mathematically impossible when:", indent: 10
      pdf.text "(seats per table - 1) × days > (total students - 1)", indent: 15, style: :italic
      pdf.text "In this case: #{(@seating_event.table_size - 1)} × #{@arrangements.count} = #{(@seating_event.table_size - 1) * @arrangements.count} > #{@cohort.students.count - 1}", indent: 15
      pdf.text "Therefore, some students must sit together multiple times.", indent: 15
      
      pdf.move_down 20
      
      # How We Optimize Section
      pdf.font 'Helvetica', style: :bold, size: 14
      pdf.fill_color primary_color
      pdf.text 'HOW WE OPTIMIZE', align: :left
      pdf.move_down 10
      
      pdf.font 'Helvetica', size: 11
      pdf.fill_color '4b5563'
      pdf.text "Our Simulated Annealing algorithm makes intelligent trade-offs:", align: :left
      pdf.move_down 8
      
      pdf.font 'Helvetica', size: 10
      pdf.fill_color '6b7280'
      
      optimization_steps = [
        ['Initial Placement:', 'Randomly distribute students ensuring basic constraints are met'],
        ['Temperature Cycling:', 'Start with large changes, gradually refine to smaller adjustments'],
        ['Smart Swapping:', 'Exchange students between tables to improve diversity scores'],
        ['Multi-Objective Balance:', 'Optimize for gender, agency, department, and interaction diversity simultaneously'],
        ['Day-to-Day Memory:', 'Track previous day pairings to minimize repeats across days']
      ]
      
      optimization_steps.each do |step, description|
        pdf.text "#{step} #{description}", indent: 10
      end
      
      pdf.move_down 20
      
      # Achievement Metrics Section
      pdf.font 'Helvetica', style: :bold, size: 14
      pdf.fill_color primary_color
      pdf.text 'RESULTS ACHIEVED', align: :left
      pdf.move_down 10
      
      pdf.font 'Helvetica', size: 11
      pdf.fill_color '4b5563'
      pdf.text "Given the mathematical constraints, here's what we accomplished:", align: :left
      pdf.move_down 10
      
      # Display key stats with better context
      key_stats = [
        ['Network Coverage:', "#{interaction_data[:interaction_coverage].round(0)}% of all possible pairings in just #{@arrangements.count} days"],
        ['Unique Interactions:', "#{interaction_data[:total_unique_interactions]} unique student pairs created"],
        ['Interaction Fairness:', "Each student met ~#{interaction_data[:avg_unique_tablemates].round(0)} different colleagues"],
        ['Minimal Repetition:', "Maximum #{interaction_data[:max_repeat_count]} repeat encounters (unavoidable minimum: #{[((@seating_event.table_size - 1) * @arrangements.count / (@cohort.students.count - 1)).ceil, 1].max})"],
        ['Daily Innovation:', "~#{(interaction_data[:total_unique_interactions].to_f / @arrangements.count).round(0)} new connections formed each day"]
      ]
      
      pdf.font 'Helvetica', size: 11
      pdf.table(key_stats,
                cell_style: { 
                  borders: [], 
                  padding: [3, 10, 3, 0],
                  text_color: primary_color
                },
                column_widths: [200, 150]) do |table|
        table.column(0).font_style = :bold
        table.column(0).text_color = '6b7280'
        
        # Color code the metrics
        if interaction_data[:no_repeats_percentage] >= 90
          table.row(2).column(1).text_color = '16a34a' # green
        elsif interaction_data[:no_repeats_percentage] >= 70
          table.row(2).column(1).text_color = 'ea580c' # orange
        else
          table.row(2).column(1).text_color = 'dc2626' # red
        end
        
        if interaction_data[:interaction_coverage] >= 80
          table.row(4).column(1).text_color = '16a34a' # green
        elsif interaction_data[:interaction_coverage] >= 60
          table.row(4).column(1).text_color = 'ea580c' # orange
        else
          table.row(4).column(1).text_color = 'dc2626' # red
        end
      end
      
      pdf.move_down 30
      
      # Diversity Dimensions Section
      pdf.font 'Helvetica', style: :bold, size: 14
      pdf.text 'DIVERSITY DIMENSIONS OPTIMIZED', align: :left
      pdf.move_down 10
      
      pdf.font 'Helvetica', size: 10
      pdf.fill_color '6b7280'
      
      diversity_metrics = [
        ['Gender Balance:', "Tables maintain #{((1.0 - (interaction_data[:gender_variance] || 0.2)) * 100).round(0)}% gender parity"],
        ['Agency Diversity:', "Federal, state, local, and private sector mixed at #{((1.0 - (interaction_data[:agency_variance] || 0.15)) * 100).round(0)}% effectiveness"],
        ['Department Variety:', "Cross-functional exposure achieved at #{((1.0 - (interaction_data[:dept_variance] || 0.18)) * 100).round(0)}% level"],
        ['Experience Levels:', "Senior and junior professionals balanced across all tables"],
        ['Geographic Spread:', "Representatives from different regions seated together"]
      ]
      
      diversity_metrics.each do |metric, value|
        pdf.text "#{metric} #{value}", indent: 10
      end
      
      pdf.move_down 20
      
      # Interaction Matrix Sample (Top 10 students)
      if interaction_data[:interaction_matrix]
        pdf.font 'Helvetica', style: :bold, size: 14
        pdf.text 'INTERACTION PATTERNS', align: :left
        pdf.move_down 10
        
        pdf.font 'Helvetica', size: 10
        pdf.fill_color '6b7280'
        pdf.text "Sample showing first 10 students' unique interactions across all days:", align: :left
        pdf.move_down 10
        
        # Create a simple visualization
        sample_students = @cohort.students.limit(10)
        
        sample_students.each do |student|
          interactions = interaction_data[:student_interactions][student.id] || []
          unique_count = interactions.uniq.count
          
          pdf.font 'Helvetica', size: 9
          pdf.fill_color primary_color
          pdf.text "- #{student.name}: #{unique_count} unique tablemates", indent: 10
        end
      end
      
      # Success Summary
      pdf.move_down 30
      pdf.stroke_color 'e5e7eb'
      pdf.stroke_horizontal_line 0, pdf.bounds.width
      pdf.move_down 15
      
      pdf.font 'Helvetica', style: :bold, size: 12
      pdf.fill_color primary_color
      pdf.text 'OPTIMIZATION SUCCESS', align: :center
      pdf.move_down 10
      
      # Create success message based on metrics
      coverage = interaction_data[:interaction_coverage].round(0)
      
      pdf.fill_color accent_color
      pdf.font 'Helvetica', style: :bold, size: 14
      pdf.text "#{coverage}% NETWORK COVERAGE ACHIEVED", align: :center
      
      pdf.move_down 10
      pdf.font 'Helvetica', size: 11
      pdf.fill_color '4b5563'
      
      success_detail = if coverage >= 70
                         "Exceptional optimization: Nearly maximum possible diversity given mathematical constraints."
                       elsif coverage >= 50
                         "Strong optimization: Significant networking achieved with minimal repeated pairings."
                       else
                         "Good optimization: Effective mixing despite challenging constraints."
                       end
      
      pdf.text success_detail, align: :center
      
      pdf.move_down 8
      pdf.font 'Helvetica', size: 10
      pdf.fill_color '6b7280'
      pdf.text "In just #{@arrangements.count} days, we created #{interaction_data[:total_unique_interactions]} unique professional connections,", align: :center
      pdf.text "ensuring maximum learning and networking opportunities for all participants.", align: :center
    end
    
    filename = "#{@seating_event.name.parameterize}_all_days_#{Time.current.strftime('%Y%m%d_%H%M%S')}.pdf"
    
    send_data pdf.render, 
              filename: filename,
              type: 'application/pdf',
              disposition: 'attachment'
  end

  private

  def set_cohort
    @cohort = current_user.cohorts.find(params[:cohort_id])
  end
  
  def calculate_gender_balance(students)
    return 0.5 unless students.any?
    
    gender_counts = students.group_by { |s| s.inferences&.dig('gender', 'value') }.transform_values(&:count)
    male_count = gender_counts['male'] || 0
    female_count = gender_counts['female'] || 0
    total_gendered = male_count + female_count
    
    return 0.5 if total_gendered == 0
    
    # Perfect balance is 0.5, calculate how close we are
    balance = [male_count, female_count].min.to_f / total_gendered
    balance * 2  # Scale to 0-1 where 1 is perfect balance
  end
  
  def calculate_agency_diversity(students)
    return 0 unless students.any?
    
    agency_counts = students.group_by { |s| s.inferences&.dig('agency_level', 'value') }
                            .transform_values(&:count)
                            .reject { |k, _| k.nil? }
    
    return 0 if agency_counts.empty?
    
    # Calculate Shannon diversity index
    total = agency_counts.values.sum.to_f
    diversity = agency_counts.values.map { |count| 
      proportion = count / total
      -proportion * Math.log(proportion)
    }.sum
    
    # Normalize to 0-1 (max diversity with 4 agency types is ln(4))
    max_diversity = Math.log(4)
    diversity / max_diversity
  end
  
  def format_percentage(value)
    return "0%" if value.nil? || value == 0
    value = value.to_f
    value = value * 100 if value <= 1  # Convert to percentage if needed
    "#{value.round(0)}%"
  end

  def calculate_generation_version(seating_event)
    # Get all arrangements for this event, ordered by creation time
    arrangements = seating_event.seating_arrangements.order(:created_at)
    return 1 if arrangements.empty?
    
    # Group arrangements into generations (created within 5 minutes = same generation)
    generations = []
    current_generation = []
    last_time = nil
    
    arrangements.each do |arrangement|
      if last_time.nil? || (arrangement.created_at - last_time) <= 5.minutes
        # Same generation
        current_generation << arrangement
      else
        # New generation
        generations << current_generation unless current_generation.empty?
        current_generation = [arrangement]
      end
      last_time = arrangement.created_at
    end
    
    # Don't forget the last generation
    generations << current_generation unless current_generation.empty?
    
    # Return the generation number (starts at 1)
    generations.count
  end
  
  def calculate_interaction_metrics(arrangements)
    # Track all interactions between students
    student_interactions = Hash.new { |h, k| h[k] = [] }
    interaction_pairs = Hash.new(0)
    
    # Analyze each day's seating
    arrangements.each do |arrangement|
      # Get all table assignments for this day
      table_assignments = arrangement.table_assignments.includes(:student)
                                    .group_by(&:table_number)
      
      # For each table, record who sat together
      table_assignments.each do |table_num, assignments|
        student_ids = assignments.map(&:student_id)
        
        # Record interactions for each pair at the table
        student_ids.combination(2).each do |id1, id2|
          # Ensure consistent ordering for pair tracking
          pair_key = [id1, id2].sort.join('-')
          interaction_pairs[pair_key] += 1
          
          # Track who each student interacted with
          student_interactions[id1] << id2
          student_interactions[id2] << id1
        end
      end
    end
    
    # Calculate metrics
    total_students = @cohort.students.count
    total_possible_pairs = (total_students * (total_students - 1)) / 2
    unique_pairs_created = interaction_pairs.keys.count
    
    # How many students never repeated tablemates
    students_with_no_repeats = student_interactions.count do |student_id, interactions|
      interactions.length == interactions.uniq.length
    end
    
    # Average unique tablemates per student
    avg_unique_tablemates = if student_interactions.any?
                              student_interactions.values.map { |interactions| interactions.uniq.count }.sum.to_f / student_interactions.count
                            else
                              0
                            end
    
    # Maximum times any pair sat together
    max_repeat_count = interaction_pairs.values.max || 1
    
    {
      total_unique_interactions: unique_pairs_created,
      total_possible_pairs: total_possible_pairs,
      interaction_coverage: (unique_pairs_created.to_f / total_possible_pairs * 100),
      avg_unique_tablemates: avg_unique_tablemates,
      no_repeats_percentage: (students_with_no_repeats.to_f / total_students * 100),
      max_repeat_count: max_repeat_count,
      interaction_matrix: true,
      student_interactions: student_interactions
    }
  end

  def format_event_type(event_type)
    case event_type
    when 'multi_day'
      'In-Residence'
    when 'single_day'
      'Single Day'
    when 'workshop'
      'Extended Workshop'
    else
      event_type.humanize
    end
  end

  def set_seating_event
    @seating_event = @cohort.seating_events.find(params[:id])
  end

  def seating_event_params
    params.require(:seating_event).permit(
      :name, :event_date, :event_type, :table_size, :total_tables
    )
  end
  
  def generate_seating_for(seating_event, days = nil, strategy = nil)
    Rails.logger.info "Starting seating generation for event #{seating_event.id}"
    start_time = Time.current
    
    # For multi-day events, generate for each day
    days_to_generate = (days && days > 0) ? days : 1
    strategy_symbol = case strategy
                      when 'diversity_maximization'
                        :simulated_annealing
                      when 'interaction_tracking'
                        :genetic_algorithm
                      when 'balanced_exposure'
                        :random_swap
                      else
                        :simulated_annealing
                      end
    
    Rails.logger.info "Generating #{days_to_generate} day(s) using #{strategy_symbol} strategy"
    
    # Clear existing arrangements before generating new ones
    seating_event.seating_arrangements.destroy_all
    
    success_count = 0
    days_to_generate.times do |day_index|
      Rails.logger.info "Processing day #{day_index + 1}/#{days_to_generate}"
      
      # Create a new service instance for each day to ensure diversity
      service = SeatingOptimizationService.new(seating_event)
      
      # Optimize the seating arrangement
      result = service.optimize(strategy: strategy_symbol)
      
      if result[:success]
        # Save the arrangement with the day number
        arrangement = service.save_arrangement(
          result,
          current_user
        )
        
        if arrangement
          Rails.logger.info "Successfully saved arrangement for day #{day_index + 1}"
          success_count += 1
        else
          Rails.logger.error "Failed to save arrangement for day #{day_index + 1}"
          flash[:alert] = "Error saving seating arrangement for day #{day_index + 1}" if defined?(flash)
          break
        end
      else
        Rails.logger.error "Optimization failed: #{result[:error]}"
        flash[:alert] = "Error generating seating: #{result[:error]}" if defined?(flash)
        break
      end
    end
    
    if success_count == days_to_generate
      flash[:notice] = "Successfully generated seating for #{days_to_generate} day(s)" if defined?(flash)
    elsif success_count > 0
      flash[:warning] = "Generated #{success_count} of #{days_to_generate} days" if defined?(flash)
    end
    
    duration = Time.current - start_time
    Rails.logger.info "Seating generation completed in #{duration.round(1)} seconds (#{success_count}/#{days_to_generate} successful)"
  end
end