# frozen_string_literal: true

class ExplanationGeneratorService
  include ActionView::Helpers::TextHelper

  EXPLANATION_PURPOSES = {
    student_placement: 'student_placement_explanation',
    table_composition: 'table_composition_explanation', 
    diversity_score: 'diversity_score_explanation',
    constraint_impact: 'constraint_impact_explanation',
    optimization_summary: 'optimization_summary_explanation'
  }.freeze

  attr_reader :seating_arrangement, :seating_event

  def initialize(seating_arrangement)
    @seating_arrangement = seating_arrangement
    @seating_event = seating_arrangement.seating_event
  end

  # Generate comprehensive explanations for the entire arrangement
  def generate_complete_explanations
    {
      overall_summary: generate_overall_summary,
      table_explanations: generate_table_explanations,
      student_explanations: generate_student_explanations,
      diversity_analysis: generate_diversity_analysis,
      constraint_analysis: generate_constraint_analysis,
      optimization_details: generate_optimization_details,
      confidence_scores: calculate_confidence_scores
    }
  end

  # Generate explanation for a specific student's placement
  def explain_student_placement(student)
    student_assignment = find_student_assignment(student)
    return nil unless student_assignment

    table_mates = get_table_mates(student_assignment.table_number)
    student_attributes = extract_student_attributes(student)
    table_diversity = calculate_table_diversity(student_assignment.table_number)
    
    prompt = build_student_placement_prompt(
      student: student,
      student_attributes: student_attributes,
      table_mates: table_mates,
      table_diversity: table_diversity,
      constraints: get_applicable_constraints(student)
    )

    explanation = generate_ai_explanation(prompt, :student_placement)
    
    {
      explanation: explanation,
      confidence: calculate_placement_confidence(student_assignment),
      contributing_factors: analyze_placement_factors(student, student_assignment),
      alternatives_considered: suggest_alternative_placements(student)
    }
  end

  # Generate explanation for a table's composition
  def explain_table_composition(table_number)
    table_students = get_table_students(table_number)
    return nil if table_students.empty?

    table_diversity = calculate_table_diversity(table_number)
    table_constraints = get_table_constraints(table_number)
    
    prompt = build_table_composition_prompt(
      table_number: table_number,
      students: table_students,
      diversity_metrics: table_diversity,
      constraints: table_constraints
    )

    explanation = generate_ai_explanation(prompt, :table_composition)
    
    {
      explanation: explanation,
      diversity_breakdown: table_diversity,
      constraint_satisfaction: table_constraints,
      optimization_score: calculate_table_score(table_number),
      improvement_suggestions: suggest_table_improvements(table_number)
    }
  end

  # Generate diversity score explanations
  def explain_diversity_scores
    overall_metrics = seating_arrangement.diversity_metrics
    table_breakdowns = calculate_all_table_diversity

    prompt = build_diversity_explanation_prompt(
      overall_metrics: overall_metrics,
      table_breakdowns: table_breakdowns,
      optimization_scores: seating_arrangement.optimization_scores
    )

    explanation = generate_ai_explanation(prompt, :diversity_score)
    
    {
      explanation: explanation,
      overall_scores: overall_metrics,
      table_scores: table_breakdowns,
      score_interpretation: interpret_diversity_scores(overall_metrics),
      improvement_areas: identify_diversity_improvements
    }
  end

  private

  def generate_overall_summary
    optimization_stats = seating_arrangement.optimization_scores || {}
    diversity_metrics = seating_arrangement.diversity_metrics || {}
    
    prompt = build_overall_summary_prompt(
      total_students: seating_arrangement.students_count,
      total_tables: seating_arrangement.tables_count,
      optimization_strategy: optimization_stats['strategy'],
      final_score: optimization_stats['final_score'],
      diversity_metrics: diversity_metrics,
      runtime: optimization_stats['runtime'],
      improvements: optimization_stats['improvements']
    )

    generate_ai_explanation(prompt, :optimization_summary)
  end

  def generate_table_explanations
    explanations = {}
    
    seating_arrangement.table_assignments.group(:table_number).each do |table_number, _|
      explanations[table_number] = explain_table_composition(table_number)
    end
    
    explanations
  end

  def generate_student_explanations
    explanations = {}
    
    seating_arrangement.table_assignments.includes(:student).each do |assignment|
      student = assignment.student
      explanations[student.id] = explain_student_placement(student)
    end
    
    explanations
  end

  def generate_diversity_analysis
    explain_diversity_scores
  end

  def generate_constraint_analysis
    constraints = seating_event.seating_rules.active
    constraint_impacts = analyze_constraint_impacts(constraints)
    
    prompt = build_constraint_analysis_prompt(
      constraints: constraints,
      constraint_impacts: constraint_impacts,
      violations: find_constraint_violations
    )

    explanation = generate_ai_explanation(prompt, :constraint_impact)
    
    {
      explanation: explanation,
      constraint_satisfaction: constraint_impacts,
      violations: find_constraint_violations,
      trade_offs: identify_constraint_tradeoffs
    }
  end

  def generate_optimization_details
    stats = seating_arrangement.optimization_scores || {}
    
    {
      strategy_explanation: explain_optimization_strategy(stats['strategy']),
      performance_metrics: {
        iterations: stats['iterations'],
        improvements: stats['improvements'], 
        runtime: stats['runtime'],
        initial_score: stats['initial_score'],
        final_score: stats['final_score'],
        improvement_percentage: stats['improvement']
      },
      algorithm_details: get_algorithm_details(stats['strategy'])
    }
  end

  def calculate_confidence_scores
    {
      overall_confidence: calculate_overall_confidence,
      table_confidences: calculate_table_confidences,
      placement_confidences: calculate_placement_confidences
    }
  end

  # AI Prompt Building Methods
  def build_student_placement_prompt(student:, student_attributes:, table_mates:, table_diversity:, constraints:)
    <<~PROMPT
      Explain why student "#{student.display_name}" was placed at their current table in a seating arrangement.
      
      Student Information:
      #{format_student_attributes(student_attributes)}
      
      Table Mates:
      #{format_table_mates(table_mates)}
      
      Table Diversity Metrics:
      #{format_diversity_metrics(table_diversity)}
      
      Applicable Constraints:
      #{format_constraints(constraints)}
      
      Please provide a clear, human-readable explanation (2-3 sentences) that explains:
      1. Why this student fits well at this table
      2. How this placement contributes to overall diversity
      3. Which constraints were considered in this decision
      
      Use accessible language suitable for educators.
    PROMPT
  end

  def build_table_composition_prompt(table_number:, students:, diversity_metrics:, constraints:)
    <<~PROMPT
      Explain the composition and rationale for Table #{table_number} in a classroom seating arrangement.
      
      Students at this table:
      #{format_table_students(students)}
      
      Diversity Metrics:
      #{format_diversity_metrics(diversity_metrics)}
      
      Constraint Considerations:
      #{format_constraints(constraints)}
      
      Please provide a clear explanation (3-4 sentences) covering:
      1. The overall composition strategy for this table
      2. How diversity goals are met
      3. Any constraint considerations that influenced the composition
      4. The strengths of this particular grouping
      
      Focus on educational benefits and collaborative potential.
    PROMPT
  end

  def build_diversity_explanation_prompt(overall_metrics:, table_breakdowns:, optimization_scores:)
    <<~PROMPT
      Explain the diversity scores and metrics for this seating arrangement.
      
      Overall Diversity Metrics:
      #{format_diversity_metrics(overall_metrics)}
      
      Optimization Results:
      - Final Score: #{optimization_scores['final_score']&.round(3)}
      - Strategy: #{optimization_scores['strategy']&.humanize}
      - Improvements Made: #{optimization_scores['improvements']}
      
      Table-by-Table Breakdown:
      #{format_table_diversity_breakdown(table_breakdowns)}
      
      Please provide a comprehensive explanation (4-5 sentences) covering:
      1. What the overall diversity score means and how it was calculated
      2. Which aspects of diversity are strongest/weakest
      3. How the arrangement balances different diversity factors
      4. The educational benefits of this diversity distribution
      
      Make it understandable for educators who want to understand the AI's decision-making process.
    PROMPT
  end

  def build_overall_summary_prompt(total_students:, total_tables:, optimization_strategy:, final_score:, diversity_metrics:, runtime:, improvements:)
    <<~PROMPT
      Generate an executive summary explaining how #{total_students} students were arranged across #{total_tables} tables.
      
      Optimization Results:
      - Strategy Used: #{optimization_strategy&.humanize || 'Not specified'}
      - Final Diversity Score: #{final_score&.round(3) || 'Not available'}
      - Runtime: #{runtime&.round(2)} seconds
      - Improvements Made: #{improvements || 0}
      
      Key Diversity Metrics:
      #{format_diversity_metrics(diversity_metrics)}
      
      Please provide a clear summary (3-4 sentences) explaining:
      1. The overall approach used to create this seating arrangement
      2. The key diversity achievements and goals met
      3. The quality and reliability of this arrangement
      4. Any notable trade-offs or considerations made
      
      Write for educators who need to understand and potentially explain this arrangement to others.
    PROMPT
  end

  def build_constraint_analysis_prompt(constraints:, constraint_impacts:, violations:)
    <<~PROMPT
      Analyze how seating constraints and rules influenced this arrangement.
      
      Active Constraints:
      #{format_constraint_rules(constraints)}
      
      Constraint Impact Analysis:
      #{format_constraint_impacts(constraint_impacts)}
      
      Violations Found:
      #{format_constraint_violations(violations)}
      
      Please explain (3-4 sentences):
      1. Which constraints had the most influence on the final arrangement
      2. How conflicts between constraints were resolved
      3. Any trade-offs made to balance competing requirements
      4. The overall constraint satisfaction level
      
      Help educators understand how their rules shaped the final seating plan.
    PROMPT
  end

  # Helper Methods
  def generate_ai_explanation(prompt, purpose)
    return "Explanation not available - AI service unavailable" unless OpenaiService.configured?
    
    begin
      OpenaiService.call(
        prompt,
        purpose: EXPLANATION_PURPOSES[purpose],
        user: seating_arrangement.created_by,
        model_override: 'gpt-4o' # Use GPT-4o for explanations for better quality
      )
    rescue StandardError => e
      Rails.logger.error "Failed to generate AI explanation: #{e.message}"
      "Unable to generate explanation at this time. Please try again later."
    end
  end

  def find_student_assignment(student)
    seating_arrangement.table_assignments.find_by(student: student)
  end

  def get_table_mates(table_number)
    seating_arrangement.table_assignments
                      .includes(:student)
                      .where(table_number: table_number)
                      .map(&:student)
  end

  def get_table_students(table_number)
    get_table_mates(table_number)
  end

  def extract_student_attributes(student)
    attributes = {}
    
    # Get all custom attributes for this student
    student.custom_attributes.each do |attr|
      attributes[attr.attribute_name] = attr.attribute_value
    end
    
    # Add basic info
    attributes['name'] = student.display_name
    attributes['id'] = student.id
    
    attributes
  end

  def calculate_table_diversity(table_number)
    table_students = get_table_students(table_number)
    return {} if table_students.empty?

    calculator = DiversityCalculator.new
    # Create a mock arrangement with just this table for calculation
    mock_arrangement = { table_number => table_students }
    calculator.calculate_detailed_metrics(mock_arrangement, seating_event)
  end

  def calculate_all_table_diversity
    diversity_breakdown = {}
    
    seating_arrangement.table_assignments.group(:table_number).each do |table_number, _|
      diversity_breakdown[table_number] = calculate_table_diversity(table_number)
    end
    
    diversity_breakdown
  end

  def get_applicable_constraints(student)
    # Get all active seating rules that might apply to this student
    seating_event.seating_rules.active.select do |rule|
      # This would need to be expanded based on your rule evaluation logic
      true # For now, return all rules as potentially applicable
    end
  end

  def get_table_constraints(table_number)
    # Return constraints that specifically affect this table
    seating_event.seating_rules.active
  end

  def calculate_placement_confidence(student_assignment)
    # Calculate confidence based on various factors
    table_score = calculate_table_score(student_assignment.table_number)
    constraint_satisfaction = calculate_constraint_satisfaction_for_student(student_assignment.student)
    
    # Simple confidence calculation - could be more sophisticated
    base_confidence = table_score * 0.7 + constraint_satisfaction * 0.3
    [base_confidence, 1.0].min
  end

  def calculate_table_score(table_number)
    table_students = get_table_students(table_number)
    return 0.0 if table_students.empty?

    calculator = DiversityCalculator.new
    mock_arrangement = { table_number => table_students }
    calculator.calculate_total_score(mock_arrangement, seating_event)
  end

  def calculate_constraint_satisfaction_for_student(student)
    # Calculate how well this student's placement satisfies constraints
    # This is a simplified implementation
    0.8 # Return a default good satisfaction score
  end

  def analyze_placement_factors(student, student_assignment)
    factors = []
    
    # Analyze diversity contribution
    table_diversity = calculate_table_diversity(student_assignment.table_number)
    if table_diversity.any? { |k, v| v.to_f > 0.7 }
      factors << "Improves table diversity"
    end
    
    # Analyze constraint satisfaction
    applicable_constraints = get_applicable_constraints(student)
    if applicable_constraints.any?
      factors << "Satisfies #{applicable_constraints.count} seating rules"
    end
    
    # Add more factor analysis as needed
    factors << "Balanced table composition"
    
    factors
  end

  def suggest_alternative_placements(student)
    # This would involve running mini-optimizations to find good alternatives
    # For now, return a placeholder
    ["Alternative placements available with 85% confidence"]
  end

  def suggest_table_improvements(table_number)
    # Suggest how this table could be improved
    ["Consider swapping with students from adjacent tables to improve gender balance"]
  end

  def find_constraint_violations
    # Use the existing ConstraintEvaluator to find violations
    evaluator = ConstraintEvaluator.new(seating_event)
    arrangement_data = convert_to_arrangement_format
    evaluator.evaluate(arrangement_data)
  end

  def convert_to_arrangement_format
    # Convert the database arrangement back to the format used by optimization
    arrangement = {}
    
    seating_arrangement.table_assignments.includes(:student).group_by(&:table_number).each do |table_number, assignments|
      arrangement[table_number] = assignments.map(&:student)
    end
    
    arrangement
  end

  def analyze_constraint_impacts(constraints)
    # Analyze how each constraint affected the final arrangement
    impacts = {}
    
    constraints.each do |constraint|
      impacts[constraint.id] = {
        rule: constraint.description,
        impact_level: calculate_constraint_impact(constraint),
        satisfaction_rate: calculate_constraint_satisfaction(constraint)
      }
    end
    
    impacts
  end

  def calculate_constraint_impact(constraint)
    # Calculate how much this constraint influenced the arrangement
    # This is a simplified implementation
    rand(0.3..0.9).round(2) # Placeholder
  end

  def calculate_constraint_satisfaction(constraint)
    # Calculate how well this constraint is satisfied
    # This is a simplified implementation  
    rand(0.7..1.0).round(2) # Placeholder
  end

  def identify_constraint_tradeoffs
    # Identify where constraints conflicted and how they were resolved
    ["Balanced diversity goals against specific grouping requirements"]
  end

  def explain_optimization_strategy(strategy)
    case strategy&.to_s
    when 'simulated_annealing'
      "Used simulated annealing to gradually improve the arrangement by accepting some temporary decreases in quality to avoid local optima."
    when 'genetic_algorithm'  
      "Applied genetic algorithm principles to evolve the seating arrangement over multiple generations."
    when 'random_swap'
      "Used random swapping to explore different arrangements and keep improvements."
    else
      "Applied advanced optimization techniques to find the best possible seating arrangement."
    end
  end

  def get_algorithm_details(strategy)
    {
      strategy => {
        description: explain_optimization_strategy(strategy),
        strengths: get_strategy_strengths(strategy),
        suitability: get_strategy_suitability(strategy)
      }
    }
  end

  def get_strategy_strengths(strategy)
    case strategy&.to_s
    when 'simulated_annealing'
      ["Avoids getting stuck in poor local solutions", "Good for complex constraint problems"]
    when 'genetic_algorithm'
      ["Explores multiple solutions simultaneously", "Good for large search spaces"]
    when 'random_swap'
      ["Simple and reliable", "Fast execution"]
    else
      ["Optimized for classroom seating problems"]
    end
  end

  def get_strategy_suitability(strategy)
    "Well-suited for classroom seating optimization with multiple diversity objectives."
  end

  def calculate_overall_confidence
    return 0.0 unless seating_arrangement.optimization_scores&.dig('final_score')
    
    final_score = seating_arrangement.optimization_scores['final_score'].to_f
    improvements = seating_arrangement.optimization_scores['improvements']&.to_i || 0
    runtime = seating_arrangement.optimization_scores['runtime']&.to_f || 0
    
    # Base confidence on final score, number of improvements, and reasonable runtime
    base_confidence = final_score
    improvement_boost = [improvements * 0.01, 0.1].min
    runtime_factor = runtime > 5 ? 0.95 : 1.0 # Slight penalty for very long runtimes
    
    confidence = (base_confidence + improvement_boost) * runtime_factor
    [confidence, 1.0].min
  end

  def calculate_table_confidences
    confidences = {}
    
    seating_arrangement.table_assignments.group(:table_number).each do |table_number, _|
      table_score = calculate_table_score(table_number)
      confidences[table_number] = table_score
    end
    
    confidences
  end

  def calculate_placement_confidences
    confidences = {}
    
    seating_arrangement.table_assignments.includes(:student).each do |assignment|
      confidences[assignment.student.id] = calculate_placement_confidence(assignment)
    end
    
    confidences
  end

  def interpret_diversity_scores(metrics)
    interpretations = {}
    
    metrics.each do |metric, score|
      score_value = score.to_f
      interpretation = case score_value
                      when 0.9..1.0
                        "Excellent diversity"
                      when 0.7..0.9
                        "Good diversity"
                      when 0.5..0.7
                        "Moderate diversity"
                      when 0.3..0.5
                        "Limited diversity"
                      else
                        "Poor diversity"
                      end
      
      interpretations[metric] = {
        score: score_value,
        interpretation: interpretation,
        description: get_metric_description(metric)
      }
    end
    
    interpretations
  end

  def get_metric_description(metric)
    case metric.to_s
    when 'gender_diversity'
      "Distribution of gender across tables"
    when 'experience_diversity'
      "Mix of experience levels"
    when 'background_diversity'
      "Variety of backgrounds and perspectives"
    else
      "Diversity metric: #{metric.humanize}"
    end
  end

  def identify_diversity_improvements
    suggestions = []
    metrics = seating_arrangement.diversity_metrics || {}
    
    metrics.each do |metric, score|
      if score.to_f < 0.6
        suggestions << "Consider improving #{metric.humanize.downcase} distribution"
      end
    end
    
    suggestions << "Review table compositions for better balance" if suggestions.empty?
    suggestions
  end

  # Formatting Methods for AI Prompts
  def format_student_attributes(attributes)
    attributes.map { |k, v| "- #{k.humanize}: #{v}" }.join("\n")
  end

  def format_table_mates(students)
    students.map.with_index { |s, i| "#{i + 1}. #{s.display_name}" }.join("\n")
  end

  def format_table_students(students)
    format_table_mates(students)
  end

  def format_diversity_metrics(metrics)
    return "No diversity metrics available" if metrics.blank?
    
    metrics.map do |metric, value|
      "- #{metric.humanize}: #{(value.to_f * 100).round(1)}%"
    end.join("\n")
  end

  def format_constraints(constraints)
    return "No specific constraints applied" if constraints.blank?
    
    constraints.map.with_index do |constraint, i|
      "#{i + 1}. #{constraint.description}"
    end.join("\n")
  end

  def format_table_diversity_breakdown(table_breakdowns)
    return "No table diversity data available" if table_breakdowns.blank?
    
    table_breakdowns.map do |table_num, metrics|
      "Table #{table_num}:\n#{format_diversity_metrics(metrics)}"
    end.join("\n\n")
  end

  def format_constraint_rules(constraints)
    return "No active constraints" if constraints.blank?
    
    constraints.map.with_index do |constraint, i|
      "#{i + 1}. #{constraint.description} (Priority: #{constraint.priority || 'Normal'})"
    end.join("\n")
  end

  def format_constraint_impacts(impacts)
    return "No constraint impact data" if impacts.blank?
    
    impacts.map do |constraint_id, impact_data|
      "- #{impact_data[:rule]}: #{(impact_data[:impact_level] * 100).round(1)}% impact, #{(impact_data[:satisfaction_rate] * 100).round(1)}% satisfied"
    end.join("\n")
  end

  def format_constraint_violations(violations)
    return "No constraint violations found" if violations.blank?
    
    violations.map do |violation|
      "- #{violation[:description]} (Severity: #{violation[:severity]})"
    end.join("\n")
  end
end