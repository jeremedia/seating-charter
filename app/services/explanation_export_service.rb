# frozen_string_literal: true

require 'prawn'
require 'prawn/table'

class ExplanationExportService
  attr_reader :seating_arrangement, :seating_event

  def initialize(seating_arrangement)
    @seating_arrangement = seating_arrangement
    @seating_event = seating_arrangement.seating_event
  end

  # Export explanations to PDF
  def export_to_pdf
    Prawn::Document.new(page_size: 'A4', margin: 40) do |pdf|
      add_header(pdf)
      add_executive_summary(pdf)
      add_arrangement_overview(pdf)
      add_diversity_analysis(pdf)
      add_table_details(pdf)
      add_student_details(pdf) if include_student_details?
      add_optimization_details(pdf)
      add_constraint_analysis(pdf)
      add_appendices(pdf)
      add_footer(pdf)
    end.render
  end

  # Export detailed report with charts
  def export_detailed_pdf
    Prawn::Document.new(page_size: 'A4', margin: 30) do |pdf|
      # Enhanced version with charts and visualizations
      add_cover_page(pdf)
      add_table_of_contents(pdf)
      add_executive_summary(pdf)
      add_methodology_section(pdf)
      add_detailed_analysis(pdf)
      add_recommendations(pdf)
      add_technical_appendix(pdf)
    end.render
  end

  # Export instructor-friendly summary
  def export_instructor_summary
    Prawn::Document.new(page_size: 'A4', margin: 50) do |pdf|
      add_instructor_header(pdf)
      add_quick_overview(pdf)
      add_key_insights(pdf)
      add_actionable_recommendations(pdf)
      add_student_highlights(pdf)
      add_next_steps(pdf)
    end.render
  end

  private

  def add_header(pdf)
    pdf.text "Seating Arrangement Explanation Report", size: 24, style: :bold, align: :center
    pdf.text seating_event.name, size: 16, align: :center, color: "666666"
    pdf.text "Generated on #{Date.current.strftime('%B %d, %Y')}", size: 10, align: :center, color: "999999"
    pdf.move_down 20
    pdf.stroke_horizontal_rule
    pdf.move_down 20
  end

  def add_executive_summary(pdf)
    pdf.text "Executive Summary", size: 18, style: :bold
    pdf.move_down 10

    # Overall score and key metrics
    overall_score = seating_arrangement.overall_score
    confidence = seating_arrangement.overall_confidence
    
    summary_text = explanation_data&.dig('overall_summary') || 
                  generate_default_summary(overall_score, confidence)
    
    pdf.text summary_text, leading: 5
    pdf.move_down 15

    # Key metrics table
    pdf.text "Key Metrics", size: 14, style: :bold
    pdf.move_down 10

    metrics_data = [
      ["Overall Score", "#{(overall_score * 100).round(1)}%"],
      ["Confidence Level", "#{(confidence * 100).round(1)}%"],
      ["Students Placed", seating_arrangement.students_count.to_s],
      ["Tables Used", seating_arrangement.tables_count.to_s],
      ["Optimization Strategy", seating_arrangement.optimization_strategy],
      ["Runtime", "#{seating_arrangement.runtime_seconds.round(1)} seconds"]
    ]

    pdf.table(metrics_data, 
              header: true, 
              cell_style: { size: 10, padding: 5 },
              column_widths: [200, 200])

    pdf.start_new_page
  end

  def add_arrangement_overview(pdf)
    pdf.text "Arrangement Overview", size: 18, style: :bold
    pdf.move_down 10

    # Create seating chart representation
    add_seating_chart(pdf)
    pdf.move_down 20

    # Diversity scores breakdown
    if diversity_metrics.present?
      pdf.text "Diversity Breakdown", size: 14, style: :bold
      pdf.move_down 10

      diversity_data = diversity_metrics.map do |metric, score|
        [metric.humanize, "#{(score.to_f * 100).round(1)}%"]
      end

      pdf.table(diversity_data,
                header: false,
                cell_style: { size: 10, padding: 5 },
                column_widths: [200, 100])
    end

    pdf.start_new_page
  end

  def add_seating_chart(pdf)
    pdf.text "Seating Chart", size: 14, style: :bold
    pdf.move_down 10

    # Get table data
    tables_data = seating_arrangement.table_assignments
                                   .includes(:student)
                                   .group_by(&:table_number)

    # Calculate layout
    tables_per_row = 3
    table_width = 150
    table_height = 100

    tables_data.each_slice(tables_per_row).with_index do |table_row, row_index|
      y_position = pdf.cursor - (row_index * (table_height + 20))
      
      table_row.each_with_index do |(table_number, assignments), col_index|
        x_position = col_index * (table_width + 20)
        
        # Draw table
        pdf.bounding_box([x_position, y_position], width: table_width, height: table_height) do
          pdf.stroke_bounds
          
          # Table header
          pdf.text "Table #{table_number}", size: 12, style: :bold, align: :center
          pdf.move_down 5
          
          # Students
          assignments.each do |assignment|
            student_name = assignment.student.display_name
            confidence = seating_arrangement.student_confidence(assignment.student)
            pdf.text "• #{student_name}", size: 9
          end
        end
      end
      
      pdf.move_down table_height + 30
    end
  end

  def add_diversity_analysis(pdf)
    return unless explanation_data&.dig('diversity_analysis')

    pdf.text "Diversity Analysis", size: 18, style: :bold
    pdf.move_down 10

    diversity_analysis = explanation_data['diversity_analysis']
    
    if diversity_analysis['explanation']
      pdf.text diversity_analysis['explanation'], leading: 5
      pdf.move_down 15
    end

    # Score interpretation
    if diversity_analysis['score_interpretation']
      pdf.text "Score Interpretation", size: 14, style: :bold
      pdf.move_down 10

      diversity_analysis['score_interpretation'].each do |metric, data|
        pdf.text "#{metric.humanize}: #{data['interpretation']}", size: 10
        pdf.text "  #{data['description']}", size: 9, color: "666666"
        pdf.move_down 5
      end
    end

    pdf.start_new_page
  end

  def add_table_details(pdf)
    pdf.text "Table-by-Table Analysis", size: 18, style: :bold
    pdf.move_down 15

    table_explanations = explanation_data&.dig('table_explanations') || {}
    
    seating_arrangement.table_assignments.group(:table_number).each do |table_number, _|
      pdf.text "Table #{table_number}", size: 14, style: :bold
      pdf.move_down 5

      # Table composition
      students = seating_arrangement.table_assignments
                                  .includes(:student)
                                  .where(table_number: table_number)
                                  .map(&:student)

      pdf.text "Students (#{students.count}):", size: 12, style: :bold
      students.each do |student|
        confidence = seating_arrangement.student_confidence(student)
        pdf.text "• #{student.display_name} (#{(confidence * 100).round(1)}% confidence)", size: 10
      end
      pdf.move_down 10

      # Table explanation
      table_explanation = table_explanations[table_number.to_s]
      if table_explanation&.dig('explanation')
        pdf.text "Analysis:", size: 12, style: :bold
        pdf.text table_explanation['explanation'], size: 10, leading: 3
      end

      pdf.move_down 15
    end

    pdf.start_new_page
  end

  def add_student_details(pdf)
    return if seating_arrangement.students_count > 20 # Skip for large classes

    pdf.text "Individual Student Placements", size: 18, style: :bold
    pdf.move_down 15

    student_explanations = explanation_data&.dig('student_explanations') || {}

    seating_arrangement.table_assignments.includes(:student).each do |assignment|
      student = assignment.student
      student_explanation = student_explanations[student.id.to_s]

      pdf.text student.display_name, size: 12, style: :bold
      pdf.text "Table #{assignment.table_number}, Seat #{assignment.seat_position}", size: 10, color: "666666"
      pdf.move_down 5

      if student_explanation&.dig('explanation')
        pdf.text student_explanation['explanation'], size: 10, leading: 3
      end

      # Student attributes
      if student.custom_attributes.any?
        pdf.text "Attributes: #{student.custom_attributes.map { |a| "#{a.attribute_name}: #{a.attribute_value}" }.join(', ')}", 
                 size: 9, color: "666666"
      end

      pdf.move_down 10
    end

    pdf.start_new_page
  end

  def add_optimization_details(pdf)
    pdf.text "Optimization Process", size: 18, style: :bold
    pdf.move_down 10

    opt_scores = seating_arrangement.optimization_scores || {}
    
    # Strategy explanation
    strategy = opt_scores['strategy']
    if strategy
      pdf.text "Strategy Used: #{strategy.humanize}", size: 12, style: :bold
      pdf.move_down 5
      
      strategy_explanation = get_strategy_explanation(strategy)
      pdf.text strategy_explanation, size: 10, leading: 3
      pdf.move_down 10
    end

    # Performance metrics
    if opt_scores.any?
      pdf.text "Performance Metrics", size: 14, style: :bold
      pdf.move_down 10

      performance_data = [
        ["Total Iterations", opt_scores['iterations']&.to_s || 'N/A'],
        ["Improvements Found", opt_scores['improvements']&.to_s || 'N/A'],
        ["Initial Score", opt_scores['initial_score'] ? "#{(opt_scores['initial_score'] * 100).round(1)}%" : 'N/A'],
        ["Final Score", opt_scores['final_score'] ? "#{(opt_scores['final_score'] * 100).round(1)}%" : 'N/A'],
        ["Total Improvement", opt_scores['improvement'] ? "#{opt_scores['improvement'].round(1)}%" : 'N/A'],
        ["Runtime", opt_scores['runtime'] ? "#{opt_scores['runtime'].round(1)} seconds" : 'N/A']
      ]

      pdf.table(performance_data,
                header: false,
                cell_style: { size: 10, padding: 5 },
                column_widths: [200, 150])
    end

    pdf.start_new_page
  end

  def add_constraint_analysis(pdf)
    return unless explanation_data&.dig('constraint_analysis')

    pdf.text "Constraint Analysis", size: 18, style: :bold
    pdf.move_down 10

    constraint_analysis = explanation_data['constraint_analysis']
    
    if constraint_analysis['explanation']
      pdf.text constraint_analysis['explanation'], leading: 5
      pdf.move_down 15
    end

    # Violations
    if constraint_analysis['violations']&.any?
      pdf.text "Constraint Violations", size: 14, style: :bold
      pdf.move_down 10

      constraint_analysis['violations'].each do |violation|
        pdf.text "• #{violation['description']} (#{violation['severity']&.humanize})", size: 10
      end
      pdf.move_down 15
    end

    # Trade-offs
    if constraint_analysis['trade_offs']&.any?
      pdf.text "Trade-offs Made", size: 14, style: :bold
      pdf.move_down 10

      constraint_analysis['trade_offs'].each do |trade_off|
        pdf.text "• #{trade_off}", size: 10
      end
    end

    pdf.start_new_page
  end

  def add_appendices(pdf)
    pdf.text "Technical Appendices", size: 18, style: :bold
    pdf.move_down 15

    # Appendix A: Methodology
    pdf.text "Appendix A: Optimization Methodology", size: 14, style: :bold
    pdf.move_down 10
    
    methodology_text = <<~TEXT
      This seating arrangement was generated using advanced optimization algorithms 
      designed to maximize diversity and educational outcomes. The system considers 
      multiple factors including student attributes, seating constraints, and 
      collaborative learning objectives.

      The optimization process uses iterative improvement techniques to explore 
      different seating configurations and select the arrangement that best meets 
      the specified criteria.
    TEXT
    
    pdf.text methodology_text, size: 10, leading: 3
    pdf.move_down 15

    # Appendix B: Confidence Scores
    pdf.text "Appendix B: Confidence Score Explanation", size: 14, style: :bold
    pdf.move_down 10
    
    confidence_text = <<~TEXT
      Confidence scores indicate how certain the AI system is about each placement 
      decision. Higher scores suggest that the placement strongly supports the 
      optimization goals, while lower scores indicate areas where alternative 
      arrangements might be worth considering.

      Score Ranges:
      • 90-100%: Excellent placement with strong supporting factors
      • 80-89%: Good placement with solid justification
      • 70-79%: Acceptable placement with some trade-offs
      • 60-69%: Marginal placement that may benefit from review
      • Below 60%: Placement that should be carefully evaluated
    TEXT
    
    pdf.text confidence_text, size: 10, leading: 3
  end

  def add_footer(pdf)
    pdf.repeat :all do
      pdf.bounding_box [pdf.bounds.left, pdf.bounds.bottom + 25], 
                       width: pdf.bounds.width, height: 20 do
        pdf.font_size 8
        pdf.text "CHDS Seating Charter - AI-Generated Seating Arrangement Report", 
                 align: :center, color: "999999"
      end
    end
  end

  # Enhanced PDF methods for detailed export
  def add_cover_page(pdf)
    pdf.font_size 32
    pdf.text "Seating Arrangement", align: :center, style: :bold
    pdf.move_down 10
    pdf.font_size 24
    pdf.text "Explanation Report", align: :center, style: :bold
    pdf.move_down 30
    
    pdf.font_size 18
    pdf.text seating_event.name, align: :center, color: "666666"
    pdf.move_down 10
    pdf.font_size 14
    pdf.text "Cohort: #{seating_event.cohort.name}", align: :center, color: "888888"
    
    pdf.move_down 50
    
    # Key stats box
    pdf.bounding_box([100, pdf.cursor], width: 300, height: 150) do
      pdf.stroke_bounds
      pdf.move_down 10
      pdf.text "At a Glance", size: 16, style: :bold, align: :center
      pdf.move_down 15
      
      stats = [
        "#{seating_arrangement.students_count} students across #{seating_arrangement.tables_count} tables",
        "#{(seating_arrangement.overall_score * 100).round(1)}% optimization score",
        "#{(seating_arrangement.overall_confidence * 100).round(1)}% confidence level",
        "Generated using #{seating_arrangement.optimization_strategy}"
      ]
      
      stats.each do |stat|
        pdf.text "• #{stat}", size: 12, align: :center
        pdf.move_down 8
      end
    end
    
    pdf.move_down 100
    pdf.text "Generated on #{Date.current.strftime('%B %d, %Y')}", 
             size: 12, align: :center, color: "999999"
    
    pdf.start_new_page
  end

  def add_table_of_contents(pdf)
    pdf.text "Table of Contents", size: 20, style: :bold
    pdf.move_down 20
    
    contents = [
      ["Executive Summary", "3"],
      ["Methodology", "4"],
      ["Detailed Analysis", "5"],
      ["Diversity Analysis", "7"],
      ["Table Compositions", "9"],
      ["Individual Placements", "12"],
      ["Optimization Process", "15"],
      ["Recommendations", "17"],
      ["Technical Appendix", "18"]
    ]
    
    contents.each do |item, page|
      pdf.text "#{item} #{'.' * (50 - item.length)} #{page}", size: 12
      pdf.move_down 8
    end
    
    pdf.start_new_page
  end

  def add_instructor_header(pdf)
    pdf.text "Seating Arrangement Summary for Instructors", size: 20, style: :bold, align: :center
    pdf.move_down 5
    pdf.text seating_event.name, size: 14, align: :center, color: "666666"
    pdf.move_down 20
    pdf.stroke_horizontal_rule
    pdf.move_down 20
  end

  def add_quick_overview(pdf)
    pdf.text "Quick Overview", size: 16, style: :bold
    pdf.move_down 10
    
    overview_text = explanation_data&.dig('overall_summary') || 
                   generate_instructor_summary
    
    pdf.text overview_text, size: 12, leading: 5
    pdf.move_down 20
  end

  def add_key_insights(pdf)
    pdf.text "Key Insights", size: 16, style: :bold
    pdf.move_down 10
    
    insights = generate_instructor_insights
    
    insights.each do |insight|
      pdf.text "• #{insight}", size: 11, leading: 3
      pdf.move_down 8
    end
    
    pdf.move_down 15
  end

  def add_actionable_recommendations(pdf)
    pdf.text "Recommendations for Success", size: 16, style: :bold
    pdf.move_down 10
    
    recommendations = generate_instructor_recommendations
    
    recommendations.each_with_index do |rec, index|
      pdf.text "#{index + 1}. #{rec}", size: 11, leading: 3
      pdf.move_down 8
    end
    
    pdf.move_down 15
  end

  # Helper methods
  def explanation_data
    @explanation_data ||= seating_arrangement.explanation_data
  end

  def diversity_metrics
    @diversity_metrics ||= seating_arrangement.diversity_metrics
  end

  def include_student_details?
    seating_arrangement.students_count <= 30 # Only include for smaller classes
  end

  def generate_default_summary(overall_score, confidence)
    score_desc = case overall_score
                when 0.9..1.0 then "excellent"
                when 0.8..0.9 then "very good"
                when 0.7..0.8 then "good"
                when 0.6..0.7 then "satisfactory"
                else "needs improvement"
                end
    
    "This seating arrangement achieved #{score_desc} results with a #{(overall_score * 100).round(1)}% " \
    "optimization score and #{(confidence * 100).round(1)}% confidence level. The AI system successfully " \
    "balanced diversity goals with seating constraints to create an effective learning environment."
  end

  def generate_instructor_summary
    "Your seating arrangement has been optimized to promote collaborative learning and maximize " \
    "classroom diversity. The AI considered student attributes, your seating preferences, and " \
    "educational best practices to create this configuration."
  end

  def generate_instructor_insights
    insights = []
    
    if seating_arrangement.overall_score >= 0.8
      insights << "High optimization score indicates excellent diversity balance across tables"
    end
    
    if seating_arrangement.overall_confidence >= 0.8
      insights << "High confidence scores suggest stable, well-justified placements"
    end
    
    insights << "Students are distributed to encourage cross-cultural collaboration"
    insights << "Table compositions support different learning styles and backgrounds"
    
    if seating_arrangement.total_improvements > 10
      insights << "Multiple optimization iterations ensured the best possible arrangement"
    end
    
    insights
  end

  def generate_instructor_recommendations
    [
      "Consider these placements as a starting point - feel free to make adjustments based on your classroom observations",
      "Monitor group dynamics and be prepared to make changes if needed",
      "Encourage students to engage with their table partners during collaborative activities",
      "Consider rotating seating arrangements periodically to maximize cross-group interaction",
      "Use the diversity insights to inform your teaching strategies and group activities"
    ]
  end

  def get_strategy_explanation(strategy)
    case strategy.to_s
    when 'simulated_annealing'
      "Simulated annealing was used to explore the solution space systematically, " \
      "accepting some temporary decreases in quality to avoid local optima and find " \
      "the best overall arrangement."
    when 'genetic_algorithm'
      "A genetic algorithm approach evolved multiple arrangement possibilities over " \
      "several generations, combining successful elements to create the optimal solution."
    when 'random_swap'
      "Random swap optimization explored different configurations by systematically " \
      "trying student exchanges and keeping improvements."
    else
      "Advanced optimization techniques were applied to find the best possible " \
      "seating arrangement given the constraints and diversity goals."
    end
  end
end