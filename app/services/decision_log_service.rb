# frozen_string_literal: true

class DecisionLogService
  attr_reader :seating_event, :log_data, :session_id

  def initialize(seating_event)
    @seating_event = seating_event
    @session_id = SecureRandom.hex(8)
    @log_data = initialize_log_structure
  end

  # Start logging a new optimization session
  def start_optimization_session(strategy:, initial_arrangement:, parameters: {})
    @log_data[:session] = {
      session_id: @session_id,
      seating_event_id: seating_event.id,
      strategy: strategy,
      start_time: Time.current,
      parameters: parameters,
      total_students: count_students(initial_arrangement),
      total_tables: initial_arrangement.keys.count
    }
    
    @log_data[:initial_state] = {
      arrangement: serialize_arrangement(initial_arrangement),
      initial_score: calculate_initial_metrics(initial_arrangement)
    }
    
    log_decision("optimization_started", {
      strategy: strategy,
      parameters: parameters,
      initial_score: @log_data[:initial_state][:initial_score]
    })
  end

  # Log each optimization iteration
  def log_iteration(iteration:, current_arrangement:, current_score:, new_arrangement:, new_score:, accepted:, reason: nil)
    iteration_data = {
      iteration_number: iteration,
      timestamp: Time.current,
      current_score: current_score.round(4),
      proposed_score: new_score.round(4),
      score_delta: (new_score - current_score).round(4),
      accepted: accepted,
      reason: reason || (accepted ? "improvement" : "rejected"),
      arrangement_changes: calculate_arrangement_changes(current_arrangement, new_arrangement)
    }
    
    @log_data[:iterations] << iteration_data
    
    if accepted && new_score > current_score
      log_improvement(iteration, current_score, new_score, new_arrangement)
    end
  end

  # Log when an improvement is found
  def log_improvement(iteration, old_score, new_score, arrangement)
    improvement_data = {
      iteration: iteration,
      timestamp: Time.current,
      old_score: old_score.round(4),
      new_score: new_score.round(4),
      improvement: (new_score - old_score).round(4),
      improvement_percentage: (((new_score - old_score) / old_score) * 100).round(2),
      arrangement_snapshot: serialize_arrangement(arrangement),
      diversity_breakdown: calculate_diversity_breakdown(arrangement)
    }
    
    @log_data[:improvements] << improvement_data
    
    log_decision("improvement_found", improvement_data)
  end

  # Log constraint violations and resolutions
  def log_constraint_evaluation(arrangement, violations, resolutions = [])
    constraint_data = {
      timestamp: Time.current,
      total_violations: violations.count,
      violation_breakdown: group_violations_by_severity(violations),
      violations: violations.map { |v| serialize_violation(v) },
      resolutions: resolutions.map { |r| serialize_resolution(r) },
      constraint_satisfaction_score: calculate_constraint_satisfaction_score(violations)
    }
    
    @log_data[:constraint_evaluations] << constraint_data
    
    if violations.any?
      log_decision("constraint_violations_found", {
        violation_count: violations.count,
        severities: constraint_data[:violation_breakdown]
      })
    end
    
    resolutions.each do |resolution|
      log_decision("constraint_resolution_applied", resolution)
    end
  end

  # Log diversity improvements per iteration
  def log_diversity_analysis(arrangement, metrics, comparison_to_previous = nil)
    diversity_data = {
      timestamp: Time.current,
      overall_metrics: metrics,
      table_level_metrics: calculate_table_level_diversity(arrangement, metrics),
      diversity_trends: comparison_to_previous ? calculate_diversity_trends(metrics, comparison_to_previous) : {}
    }
    
    @log_data[:diversity_analyses] << diversity_data
    
    # Log significant diversity changes
    if comparison_to_previous
      significant_changes = identify_significant_diversity_changes(metrics, comparison_to_previous)
      significant_changes.each do |change|
        log_decision("diversity_change", change)
      end
    end
  end

  # Log final arrangement and reasoning
  def finalize_optimization(final_arrangement:, final_score:, final_metrics:, total_iterations:, runtime:)
    @log_data[:final_state] = {
      arrangement: serialize_arrangement(final_arrangement),
      final_score: final_score.round(4),
      final_metrics: final_metrics,
      total_iterations: total_iterations,
      runtime_seconds: runtime.round(2),
      end_time: Time.current
    }
    
    # Calculate overall statistics
    @log_data[:statistics] = calculate_session_statistics
    
    # Generate final reasoning
    @log_data[:final_reasoning] = generate_final_reasoning(final_arrangement, final_score, final_metrics)
    
    log_decision("optimization_completed", {
      final_score: final_score,
      total_iterations: total_iterations,
      runtime: runtime,
      total_improvements: @log_data[:improvements].count
    })
  end

  # Log a specific decision with context
  def log_decision(decision_type, context = {})
    decision_entry = {
      timestamp: Time.current,
      type: decision_type,
      context: context,
      session_id: @session_id
    }
    
    @log_data[:decisions] << decision_entry
  end

  # Log trade-offs made during optimization
  def log_trade_off(trade_off_type, description, impact_analysis)
    trade_off_data = {
      timestamp: Time.current,
      type: trade_off_type,
      description: description,
      impact_analysis: impact_analysis,
      reasoning: generate_trade_off_reasoning(trade_off_type, impact_analysis)
    }
    
    @log_data[:trade_offs] << trade_off_data
    
    log_decision("trade_off_made", trade_off_data.except(:reasoning))
  end

  # Get complete log data
  def get_complete_log
    @log_data
  end

  # Get log summary for storage
  def get_log_summary
    {
      session_summary: @log_data[:session],
      optimization_summary: {
        total_iterations: @log_data[:iterations].count,
        total_improvements: @log_data[:improvements].count,
        final_score: @log_data[:final_state]&.dig(:final_score),
        runtime: @log_data[:final_state]&.dig(:runtime_seconds)
      },
      constraint_summary: {
        total_evaluations: @log_data[:constraint_evaluations].count,
        total_violations_found: @log_data[:constraint_evaluations].sum { |ce| ce[:total_violations] },
        most_common_violations: identify_most_common_violations
      },
      decision_summary: {
        total_decisions: @log_data[:decisions].count,
        decision_types: @log_data[:decisions].group_by { |d| d[:type] }.transform_values(&:count),
        key_decisions: extract_key_decisions
      },
      trade_off_summary: {
        total_trade_offs: @log_data[:trade_offs].count,
        trade_off_types: @log_data[:trade_offs].group_by { |t| t[:type] }.transform_values(&:count)
      }
    }
  end

  # Export detailed log for analysis
  def export_detailed_log(format: :json)
    case format
    when :json
      @log_data.to_json
    when :csv
      convert_log_to_csv
    when :summary
      generate_human_readable_summary
    else
      raise ArgumentError, "Unsupported format: #{format}"
    end
  end

  private

  def initialize_log_structure
    {
      session: {},
      initial_state: {},
      final_state: {},
      iterations: [],
      improvements: [],
      constraint_evaluations: [],
      diversity_analyses: [],
      decisions: [],
      trade_offs: [],
      statistics: {}
    }
  end

  def count_students(arrangement)
    arrangement.values.flatten.count
  end

  def serialize_arrangement(arrangement)
    arrangement.transform_values { |students| students.map(&:id) }
  end

  def calculate_initial_metrics(arrangement)
    calculator = DiversityCalculator.new
    {
      total_score: calculator.calculate_total_score(arrangement, seating_event).round(4),
      diversity_metrics: calculator.calculate_detailed_metrics(arrangement, seating_event)
    }
  end

  def calculate_arrangement_changes(old_arrangement, new_arrangement)
    changes = []
    
    # Find students who moved tables
    old_positions = create_position_mapping(old_arrangement)
    new_positions = create_position_mapping(new_arrangement)
    
    old_positions.each do |student_id, old_table|
      new_table = new_positions[student_id]
      if new_table && new_table != old_table
        changes << {
          student_id: student_id,
          from_table: old_table,
          to_table: new_table,
          type: 'table_change'
        }
      end
    end
    
    changes
  end

  def create_position_mapping(arrangement)
    mapping = {}
    arrangement.each do |table_number, students|
      students.each do |student|
        mapping[student.id] = table_number
      end
    end
    mapping
  end

  def calculate_diversity_breakdown(arrangement)
    calculator = DiversityCalculator.new
    calculator.calculate_detailed_metrics(arrangement, seating_event)
  end

  def group_violations_by_severity(violations)
    violations.group_by { |v| v[:severity] }.transform_values(&:count)
  end

  def serialize_violation(violation)
    {
      type: violation[:type],
      severity: violation[:severity],
      description: violation[:description],
      affected_students: violation[:affected_students]&.map(&:id),
      affected_tables: violation[:affected_tables]
    }
  end

  def serialize_resolution(resolution)
    {
      resolution_type: resolution[:type],
      description: resolution[:description],
      students_moved: resolution[:students_moved]&.map(&:id),
      tables_affected: resolution[:tables_affected],
      success: resolution[:success]
    }
  end

  def calculate_constraint_satisfaction_score(violations)
    return 1.0 if violations.empty?
    
    total_penalty = violations.sum do |violation|
      case violation[:severity]
      when :hard
        10.0
      when :soft
        1.0
      else
        5.0
      end
    end
    
    # Normalize to a 0-1 scale (assuming max penalty of 100)
    [1.0 - (total_penalty / 100.0), 0.0].max
  end

  def calculate_table_level_diversity(arrangement, overall_metrics)
    table_metrics = {}
    calculator = DiversityCalculator.new
    
    arrangement.each do |table_number, students|
      next if students.empty?
      
      table_arrangement = { table_number => students }
      table_metrics[table_number] = calculator.calculate_detailed_metrics(table_arrangement, seating_event)
    end
    
    table_metrics
  end

  def calculate_diversity_trends(current_metrics, previous_metrics)
    trends = {}
    
    current_metrics.each do |metric, current_value|
      previous_value = previous_metrics[metric]
      if previous_value
        # Extract numeric score from hash if needed
        current_score = current_value.is_a?(Hash) ? (current_value[:score] || 0.0) : current_value
        previous_score = previous_value.is_a?(Hash) ? (previous_value[:score] || 0.0) : previous_value
        
        change = current_score.to_f - previous_score.to_f
        trends[metric] = {
          current: current_score,
          previous: previous_score,
          change: change.round(4),
          trend: change > 0.01 ? 'improving' : (change < -0.01 ? 'declining' : 'stable')
        }
      end
    end
    
    trends
  end

  def identify_significant_diversity_changes(current_metrics, previous_metrics)
    significant_changes = []
    threshold = 0.05 # 5% change is considered significant
    
    current_metrics.each do |metric, current_value|
      previous_value = previous_metrics[metric]
      if previous_value
        # Extract numeric score from hash if needed
        current_score = current_value.is_a?(Hash) ? (current_value[:score] || 0.0) : current_value
        previous_score = previous_value.is_a?(Hash) ? (previous_value[:score] || 0.0) : previous_value
        
        change = (current_score.to_f - previous_score.to_f).abs
        if change >= threshold
          significant_changes << {
            metric: metric,
            change_magnitude: change.round(4),
            direction: current_score.to_f > previous_score.to_f ? 'improvement' : 'decline',
            significance: 'high'
          }
        end
      end
    end
    
    significant_changes
  end

  def calculate_session_statistics
    return {} if @log_data[:iterations].empty?
    
    scores = @log_data[:iterations].map { |i| i[:current_score] }
    improvements = @log_data[:improvements]
    
    {
      iteration_statistics: {
        total_iterations: @log_data[:iterations].count,
        acceptance_rate: calculate_acceptance_rate,
        average_score: (scores.sum / scores.count.to_f).round(4),
        score_variance: calculate_variance(scores).round(4),
        best_iteration: find_best_iteration
      },
      improvement_statistics: {
        total_improvements: improvements.count,
        largest_improvement: improvements.max_by { |i| i[:improvement] }&.dig(:improvement) || 0,
        average_improvement: improvements.empty? ? 0 : (improvements.sum { |i| i[:improvement] } / improvements.count.to_f).round(4),
        improvement_frequency: improvements.empty? ? 0 : (@log_data[:iterations].count / improvements.count.to_f).round(2)
      },
      convergence_analysis: analyze_convergence_pattern
    }
  end

  def calculate_acceptance_rate
    accepted_count = @log_data[:iterations].count { |i| i[:accepted] }
    total_count = @log_data[:iterations].count
    return 0.0 if total_count.zero?
    
    (accepted_count / total_count.to_f).round(4)
  end

  def calculate_variance(values)
    return 0.0 if values.count < 2
    
    mean = values.sum / values.count.to_f
    sum_squared_deviations = values.sum { |value| (value - mean) ** 2 }
    sum_squared_deviations / (values.count - 1).to_f
  end

  def find_best_iteration
    best = @log_data[:iterations].max_by { |i| i[:current_score] }
    best ? best[:iteration_number] : nil
  end

  def analyze_convergence_pattern
    return { pattern: 'insufficient_data' } if @log_data[:improvements].count < 3
    
    recent_improvements = @log_data[:improvements].last(5)
    improvement_trend = recent_improvements.map { |i| i[:improvement] }
    
    if improvement_trend.each_cons(2).all? { |a, b| b <= a }
      { pattern: 'converging', description: 'Improvements are getting smaller over time' }
    elsif improvement_trend.last < 0.01
      { pattern: 'converged', description: 'Recent improvements are very small' }
    else
      { pattern: 'still_improving', description: 'Still finding meaningful improvements' }
    end
  end

  def generate_final_reasoning(final_arrangement, final_score, final_metrics)
    reasoning = {
      overall_assessment: assess_final_result(final_score),
      key_achievements: identify_key_achievements(final_metrics),
      optimization_efficiency: assess_optimization_efficiency,
      trade_offs_made: summarize_trade_offs,
      confidence_level: calculate_solution_confidence(final_score, final_metrics)
    }
    
    reasoning[:narrative] = generate_reasoning_narrative(reasoning)
    reasoning
  end

  def assess_final_result(final_score)
    case final_score
    when 0.9..1.0
      'Excellent - achieved very high diversity across all metrics'
    when 0.8..0.9
      'Good - strong diversity with minor areas for improvement'
    when 0.7..0.8
      'Satisfactory - decent diversity but some optimization opportunities remain'
    when 0.6..0.7
      'Fair - basic diversity achieved but significant room for improvement'
    else
      'Needs improvement - low diversity scores indicate suboptimal arrangement'
    end
  end

  def identify_key_achievements(final_metrics)
    achievements = []
    
    final_metrics.each do |metric, metric_data|
      # Extract numeric score from hash if needed
      score = metric_data.is_a?(Hash) ? (metric_data[:score] || 0.0) : metric_data
      if score.to_f >= 0.8
        achievements << "Strong #{metric.humanize.downcase} (#{(score.to_f * 100).round(1)}%)"
      end
    end
    
    achievements << "Balanced overall composition" if achievements.count >= 2
    achievements
  end

  def assess_optimization_efficiency
    return 'Unknown' unless @log_data[:session][:start_time] && @log_data[:final_state][:end_time]
    
    runtime = @log_data[:final_state][:runtime_seconds] || 0
    improvements = @log_data[:improvements].count
    iterations = @log_data[:iterations].count
    
    case
    when runtime < 10 && improvements > 5
      'Very efficient - quick optimization with good results'
    when runtime < 30 && improvements > 3
      'Efficient - reasonable time with solid improvements'
    when runtime < 60
      'Moderate - took some time but found improvements'
    else
      'Intensive - required significant computation time'
    end
  end

  def summarize_trade_offs
    return [] if @log_data[:trade_offs].empty?
    
    @log_data[:trade_offs].map { |trade_off| trade_off[:description] }.uniq
  end

  def calculate_solution_confidence(final_score, final_metrics)
    base_confidence = final_score.to_f
    
    # Adjust based on various factors
    improvements = @log_data[:improvements].count
    runtime = @log_data[:final_state][:runtime_seconds] || 0
    
    # Boost confidence with more improvements
    improvement_boost = [improvements * 0.02, 0.1].min
    
    # Slight penalty for very short runtimes (might not have explored enough)
    runtime_factor = runtime < 5 ? 0.95 : 1.0
    
    confidence = (base_confidence + improvement_boost) * runtime_factor
    [confidence, 1.0].min
  end

  def generate_reasoning_narrative(reasoning)
    narrative_parts = []
    
    narrative_parts << "The optimization process #{reasoning[:overall_assessment].downcase}."
    
    if reasoning[:key_achievements].any?
      narrative_parts << "Key strengths include: #{reasoning[:key_achievements].join(', ')}."
    end
    
    narrative_parts << "The process was #{reasoning[:optimization_efficiency].downcase}."
    
    if reasoning[:trade_offs_made].any?
      narrative_parts << "Trade-offs included: #{reasoning[:trade_offs_made].join(', ')}."
    end
    
    confidence_text = case reasoning[:confidence_level]
                     when 0.9..1.0
                       "very high confidence"
                     when 0.8..0.9
                       "high confidence" 
                     when 0.7..0.8
                       "moderate confidence"
                     else
                       "low confidence"
                     end
    
    narrative_parts << "Overall, this solution has #{confidence_text} (#{(reasoning[:confidence_level] * 100).round(1)}%)."
    
    narrative_parts.join(' ')
  end

  def generate_trade_off_reasoning(trade_off_type, impact_analysis)
    case trade_off_type.to_s
    when 'diversity_vs_constraints'
      "Balanced diversity goals against specific seating constraints, prioritizing #{impact_analysis[:priority] || 'overall optimization'}."
    when 'gender_vs_experience'
      "Chose to optimize for #{impact_analysis[:chosen_focus] || 'balanced distribution'} over other diversity factors."
    when 'table_balance_vs_preferences'
      "Maintained even table distribution while accommodating seating preferences where possible."
    else
      "Made optimization trade-off: #{impact_analysis[:description] || 'balanced competing objectives'}."
    end
  end

  def identify_most_common_violations
    all_violations = @log_data[:constraint_evaluations].flat_map { |ce| ce[:violations] }
    return [] if all_violations.empty?
    
    violation_counts = all_violations.group_by { |v| v[:type] }.transform_values(&:count)
    violation_counts.sort_by { |_, count| -count }.first(3).to_h
  end

  def extract_key_decisions
    important_types = ['optimization_started', 'improvement_found', 'constraint_violations_found', 'optimization_completed']
    @log_data[:decisions].select { |d| important_types.include?(d[:type]) }.last(10)
  end

  def convert_log_to_csv
    # This would convert log data to CSV format
    # Implementation would depend on specific CSV requirements
    "CSV export not yet implemented"
  end

  def generate_human_readable_summary
    summary = []
    
    if @log_data[:session].any?
      session = @log_data[:session]
      summary << "Optimization Session Summary"
      summary << "=" * 30
      summary << "Strategy: #{session[:strategy]&.humanize}"
      summary << "Students: #{session[:total_students]}"
      summary << "Tables: #{session[:total_tables]}"
      summary << ""
    end
    
    if @log_data[:statistics].any?
      stats = @log_data[:statistics][:iteration_statistics] || {}
      summary << "Performance Metrics:"
      summary << "- Total Iterations: #{stats[:total_iterations]}"
      summary << "- Acceptance Rate: #{(stats[:acceptance_rate] * 100).round(1)}%" if stats[:acceptance_rate]
      summary << "- Best Score: #{stats[:average_score]}" if stats[:average_score]
      summary << ""
    end
    
    if @log_data[:improvements].any?
      summary << "Improvements Found: #{@log_data[:improvements].count}"
      best_improvement = @log_data[:improvements].max_by { |i| i[:improvement] }
      summary << "Best Single Improvement: #{best_improvement[:improvement].round(4)}" if best_improvement
      summary << ""
    end
    
    if @log_data[:final_reasoning]
      reasoning = @log_data[:final_reasoning]
      summary << "Final Assessment:"
      summary << reasoning[:narrative] if reasoning[:narrative]
    end
    
    summary.join("\n")
  end
end