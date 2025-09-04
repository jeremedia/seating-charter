# frozen_string_literal: true

class MultiDayAnalyticsService
  attr_reader :seating_event, :optimization_result

  def initialize(seating_event, optimization_result = nil)
    @seating_event = seating_event
    @optimization_result = optimization_result
  end

  def generate_comprehensive_report
    {
      event_summary: generate_event_summary,
      interaction_analysis: analyze_interactions,
      diversity_analysis: analyze_diversity_patterns,
      network_analysis: perform_network_analysis,
      optimization_performance: analyze_optimization_performance,
      student_insights: generate_student_insights,
      recommendations: generate_recommendations,
      comparison_analysis: compare_with_alternatives,
      temporal_analysis: analyze_temporal_patterns
    }
  end

  def generate_interaction_coverage_report
    students = seating_event.cohort.students
    total_possible_pairs = students.count * (students.count - 1) / 2
    
    interaction_matrix = InteractionTracking.interaction_matrix_for_event(seating_event)
    actual_interactions = interaction_matrix.keys.count
    
    coverage_by_strength = {
      high: interaction_matrix.values.count { |data| data[:strength] == :high },
      medium: interaction_matrix.values.count { |data| data[:strength] == :medium },
      low: interaction_matrix.values.count { |data| data[:strength] == :low },
      none: total_possible_pairs - actual_interactions
    }
    
    {
      total_possible_pairs: total_possible_pairs,
      actual_interactions: actual_interactions,
      coverage_percentage: (actual_interactions.to_f / total_possible_pairs * 100).round(2),
      coverage_by_strength: coverage_by_strength,
      interaction_distribution: calculate_interaction_distribution(interaction_matrix),
      coverage_efficiency: calculate_coverage_efficiency(interaction_matrix, total_possible_pairs)
    }
  end

  def analyze_diversity_trends
    return {} unless optimization_result

    daily_metrics = optimization_result[:daily_metrics] || {}
    daily_scores = daily_metrics.map do |day, metrics|
      {
        day: day,
        overall_score: metrics[:overall_score] || 0,
        diversity_dimensions: extract_diversity_dimensions(metrics)
      }
    end

    {
      daily_scores: daily_scores,
      trend_analysis: calculate_trend_statistics(daily_scores),
      diversity_consistency: calculate_diversity_consistency(daily_scores),
      improvement_opportunities: identify_improvement_opportunities(daily_scores)
    }
  end

  def generate_social_network_insights
    interaction_matrix = InteractionTracking.interaction_matrix_for_event(seating_event)
    students = seating_event.cohort.students
    
    # Calculate network metrics for each student
    student_metrics = students.map do |student|
      connections = get_student_connections(student, interaction_matrix)
      
      {
        student: student,
        total_connections: connections.count,
        strong_connections: connections.count { |c| c[:strength] == :high },
        connection_strength_avg: calculate_avg_connection_strength(connections),
        centrality_score: calculate_centrality_score(student, interaction_matrix, students),
        cluster_membership: identify_student_clusters(student, interaction_matrix)
      }
    end

    # Identify network patterns
    clusters = identify_community_clusters(interaction_matrix, students)
    bridges = identify_bridge_students(student_metrics)
    isolates = identify_isolated_students(student_metrics)

    {
      student_metrics: student_metrics.sort_by { |m| -m[:total_connections] },
      network_density: calculate_network_density(interaction_matrix, students.count),
      clusters: clusters,
      bridge_students: bridges,
      isolated_students: isolates,
      network_health_score: calculate_network_health_score(student_metrics, clusters)
    }
  end

  def analyze_rotation_effectiveness
    return {} unless optimization_result

    daily_arrangements = optimization_result[:daily_arrangements] || {}
    rotation_strategy = optimization_result.dig(:optimization_stats, :rotation_strategy)

    effectiveness_metrics = {
      strategy_used: rotation_strategy,
      interaction_novelty: calculate_interaction_novelty(daily_arrangements),
      rotation_balance: calculate_rotation_balance(daily_arrangements),
      student_exposure: calculate_student_exposure_metrics(daily_arrangements),
      clustering_avoidance: calculate_clustering_avoidance(daily_arrangements)
    }

    # Compare with alternative strategies (theoretical)
    alternative_analysis = analyze_alternative_strategies(daily_arrangements)

    {
      effectiveness_metrics: effectiveness_metrics,
      strategy_comparison: alternative_analysis,
      optimization_success_rate: calculate_optimization_success_rate(effectiveness_metrics),
      recommendations: generate_rotation_recommendations(effectiveness_metrics)
    }
  end

  def generate_attendance_impact_analysis
    return {} unless optimization_result

    daily_arrangements = optimization_result[:daily_arrangements] || {}
    
    attendance_patterns = daily_arrangements.map do |day, arrangement|
      students_present = arrangement.values.flatten.count
      tables_used = arrangement.keys.count
      avg_table_size = students_present.to_f / tables_used
      
      {
        day: day,
        students_present: students_present,
        tables_used: tables_used,
        avg_table_size: avg_table_size,
        utilization: (students_present.to_f / (seating_event.total_tables * seating_event.table_size) * 100).round(1)
      }
    end

    {
      attendance_patterns: attendance_patterns,
      attendance_stability: calculate_attendance_stability(attendance_patterns),
      impact_on_optimization: assess_attendance_impact_on_optimization(attendance_patterns),
      adaptive_recommendations: generate_attendance_adaptations(attendance_patterns)
    }
  end

  private

  def generate_event_summary
    total_days = optimization_result ? optimization_result[:daily_arrangements].keys.count : 0
    total_students = seating_event.cohort.students.count
    
    {
      event_name: seating_event.name,
      event_type: seating_event.event_type.humanize,
      total_days: total_days,
      total_students: total_students,
      table_configuration: "#{seating_event.total_tables} tables × #{seating_event.table_size} students",
      optimization_date: optimization_result ? Time.current : nil,
      success_rate: optimization_result&.dig(:success) ? 100 : 0
    }
  end

  def analyze_interactions
    coverage_report = generate_interaction_coverage_report
    
    {
      coverage_report: coverage_report,
      interaction_patterns: identify_interaction_patterns,
      frequency_analysis: analyze_interaction_frequencies,
      temporal_patterns: analyze_interaction_temporal_patterns
    }
  end

  def analyze_diversity_patterns
    return {} unless optimization_result

    daily_metrics = optimization_result[:daily_metrics] || {}
    
    # Analyze diversity across different dimensions
    diversity_dimensions = %i[overall_score attribute_diversity geographic_diversity demographic_diversity]
    
    dimension_analysis = diversity_dimensions.map do |dimension|
      daily_values = daily_metrics.values.map { |metrics| metrics[dimension] || 0 }
      
      {
        dimension: dimension,
        average: daily_values.sum / daily_values.count.to_f,
        trend: calculate_linear_trend(daily_values),
        consistency: calculate_coefficient_of_variation(daily_values),
        best_day: daily_metrics.max_by { |_, metrics| metrics[dimension] || 0 }&.first,
        worst_day: daily_metrics.min_by { |_, metrics| metrics[dimension] || 0 }&.first
      }
    end

    {
      dimension_analysis: dimension_analysis,
      overall_diversity_health: calculate_overall_diversity_health(dimension_analysis),
      improvement_suggestions: suggest_diversity_improvements(dimension_analysis)
    }
  end

  def perform_network_analysis
    generate_social_network_insights
  end

  def analyze_optimization_performance
    return {} unless optimization_result

    optimization_stats = optimization_result[:optimization_stats] || {}
    
    {
      runtime_analysis: {
        total_runtime: optimization_stats[:total_runtime],
        average_daily_runtime: optimization_stats[:total_runtime].to_f / optimization_stats[:total_days],
        efficiency_score: calculate_efficiency_score(optimization_stats)
      },
      quality_metrics: {
        average_daily_score: optimization_stats[:average_daily_score],
        score_consistency: calculate_score_consistency(optimization_result[:daily_metrics]),
        improvement_rate: optimization_stats[:diversity_trend]
      },
      strategy_effectiveness: {
        strategy_used: optimization_stats[:rotation_strategy],
        interaction_coverage: optimization_stats[:interaction_coverage],
        strategy_suitability: assess_strategy_suitability(optimization_stats)
      }
    }
  end

  def generate_student_insights
    interaction_matrix = InteractionTracking.interaction_matrix_for_event(seating_event)
    students = seating_event.cohort.students

    student_profiles = students.map do |student|
      connections = get_student_connections(student, interaction_matrix)
      
      {
        student: student,
        interaction_profile: {
          total_interactions: connections.sum { |c| c[:count] },
          unique_partners: connections.count,
          avg_interaction_strength: calculate_avg_connection_strength(connections),
          most_frequent_partners: connections.sort_by { |c| -c[:count] }.first(3)
        },
        social_metrics: {
          centrality_score: calculate_centrality_score(student, interaction_matrix, students),
          bridge_score: calculate_bridge_score(student, interaction_matrix, students),
          clustering_coefficient: calculate_clustering_coefficient(student, interaction_matrix)
        },
        recommendations: generate_student_specific_recommendations(student, connections)
      }
    end

    {
      student_profiles: student_profiles,
      class_social_health: calculate_class_social_health(student_profiles),
      intervention_suggestions: identify_students_needing_support(student_profiles)
    }
  end

  def generate_recommendations
    recommendations = []

    # Analyze current performance and suggest improvements
    if optimization_result
      coverage_report = generate_interaction_coverage_report
      
      if coverage_report[:coverage_percentage] < 70
        recommendations << {
          category: 'Interaction Coverage',
          priority: 'High',
          suggestion: 'Consider adding more workshop days or using a more aggressive rotation strategy to increase student interaction coverage.',
          expected_impact: 'Increase coverage by 15-25%'
        }
      end

      diversity_trends = analyze_diversity_trends
      if diversity_trends[:trend_analysis] && diversity_trends[:trend_analysis][:slope] < 0
        recommendations << {
          category: 'Diversity Trends',
          priority: 'Medium',
          suggestion: 'Diversity scores are declining across days. Consider adjusting rotation parameters or implementing day-specific constraints.',
          expected_impact: 'Stabilize or improve daily diversity scores'
        }
      end
    end

    # Network analysis recommendations
    network_insights = generate_social_network_insights
    if network_insights[:isolated_students].count > 0
      recommendations << {
        category: 'Social Integration',
        priority: 'High',
        suggestion: "#{network_insights[:isolated_students].count} students have limited interactions. Consider targeted seating interventions.",
        expected_impact: 'Improve social integration for isolated students'
      }
    end

    recommendations
  end

  def compare_with_alternatives
    return {} unless optimization_result

    current_strategy = optimization_result.dig(:optimization_stats, :rotation_strategy)
    
    # Theoretical comparison with other strategies
    alternative_strategies = [:maximum_diversity, :structured_rotation, :random_rotation, :progressive_mixing]
    
    comparisons = alternative_strategies.reject { |s| s == current_strategy.to_sym }.map do |strategy|
      {
        strategy: strategy,
        estimated_coverage: estimate_coverage_for_strategy(strategy),
        estimated_efficiency: estimate_efficiency_for_strategy(strategy),
        trade_offs: describe_strategy_tradeoffs(strategy)
      }
    end

    {
      current_strategy: current_strategy,
      current_performance: extract_current_performance_metrics,
      alternative_strategies: comparisons,
      recommendation: recommend_best_strategy(comparisons)
    }
  end

  def analyze_temporal_patterns
    return {} unless optimization_result

    daily_arrangements = optimization_result[:daily_arrangements] || {}
    
    temporal_metrics = daily_arrangements.keys.sort.map do |day|
      arrangement = daily_arrangements[day]
      
      {
        day: day,
        metrics: calculate_daily_temporal_metrics(day, arrangement, daily_arrangements)
      }
    end

    {
      daily_progression: temporal_metrics,
      learning_curve: calculate_learning_curve_metrics(temporal_metrics),
      optimal_workshop_length: estimate_optimal_workshop_length(temporal_metrics),
      fatigue_indicators: identify_fatigue_patterns(temporal_metrics)
    }
  end

  # Helper methods for calculations
  def calculate_interaction_distribution(interaction_matrix)
    frequency_counts = Hash.new(0)
    interaction_matrix.values.each { |data| frequency_counts[data[:count]] += 1 }
    frequency_counts
  end

  def calculate_coverage_efficiency(interaction_matrix, total_possible)
    actual = interaction_matrix.keys.count
    efficiency = actual.to_f / total_possible
    
    {
      raw_efficiency: efficiency,
      normalized_efficiency: [efficiency * 2, 1.0].min, # Normalize assuming 50% is excellent
      efficiency_grade: case efficiency
                        when 0.8..Float::INFINITY then 'A'
                        when 0.6..0.8 then 'B'
                        when 0.4..0.6 then 'C'
                        when 0.2..0.4 then 'D'
                        else 'F'
                        end
    }
  end

  def extract_diversity_dimensions(metrics)
    # Extract various diversity measures from metrics
    {
      attribute: metrics[:attribute_diversity] || 0,
      geographic: metrics[:geographic_diversity] || 0,
      demographic: metrics[:demographic_diversity] || 0,
      experience: metrics[:experience_diversity] || 0
    }
  end

  def calculate_trend_statistics(daily_scores)
    scores = daily_scores.map { |day_data| day_data[:overall_score] }
    return {} if scores.count < 2

    {
      slope: calculate_linear_trend(scores),
      r_squared: calculate_r_squared(scores),
      direction: determine_trend_direction(scores),
      volatility: calculate_coefficient_of_variation(scores)
    }
  end

  def calculate_linear_trend(values)
    return 0 if values.count < 2
    
    n = values.count
    x_values = (1..n).to_a
    x_mean = x_values.sum.to_f / n
    y_mean = values.sum.to_f / n
    
    numerator = x_values.zip(values).sum { |x, y| (x - x_mean) * (y - y_mean) }
    denominator = x_values.sum { |x| (x - x_mean) ** 2 }
    
    return 0 if denominator.zero?
    numerator / denominator
  end

  def calculate_coefficient_of_variation(values)
    return 0 if values.empty?
    
    mean = values.sum.to_f / values.count
    return 0 if mean.zero?
    
    variance = values.sum { |v| (v - mean) ** 2 } / values.count
    std_dev = Math.sqrt(variance)
    
    std_dev / mean
  end

  def get_student_connections(student, interaction_matrix)
    connections = []
    
    interaction_matrix.each do |pair_key, data|
      student_ids = pair_key.split('-').map(&:to_i)
      if student_ids.include?(student.id)
        other_student = data[:students].find { |s| s.id != student.id }
        connections << {
          partner: other_student,
          count: data[:count],
          strength: data[:strength],
          days: data[:days]
        }
      end
    end
    
    connections
  end

  def calculate_avg_connection_strength(connections)
    return 0 if connections.empty?
    
    strength_values = connections.map do |conn|
      case conn[:strength]
      when :high then 3
      when :medium then 2
      when :low then 1
      else 0
      end
    end
    
    strength_values.sum.to_f / connections.count
  end

  def calculate_centrality_score(student, interaction_matrix, all_students)
    connections = get_student_connections(student, interaction_matrix)
    total_possible = all_students.count - 1
    
    return 0 if total_possible.zero?
    connections.count.to_f / total_possible
  end

  def identify_student_clusters(student, interaction_matrix)
    # Simplified clustering based on connection patterns
    connections = get_student_connections(student, interaction_matrix)
    strong_connections = connections.select { |c| c[:strength] == :high }
    
    strong_connections.map { |c| c[:partner].id }.sort.join(',')
  end

  def calculate_network_density(interaction_matrix, student_count)
    return 0 if student_count < 2
    
    actual_connections = interaction_matrix.keys.count
    possible_connections = student_count * (student_count - 1) / 2
    
    actual_connections.to_f / possible_connections
  end

  def identify_community_clusters(interaction_matrix, students)
    # Simplified community detection
    # In a full implementation, this would use algorithms like Louvain or Girvan-Newman
    
    clusters = []
    processed_students = Set.new
    
    students.each do |student|
      next if processed_students.include?(student.id)
      
      cluster_members = find_connected_component(student, interaction_matrix, students)
      if cluster_members.count > 1
        clusters << {
          id: clusters.count + 1,
          members: cluster_members,
          size: cluster_members.count,
          internal_connections: count_internal_connections(cluster_members, interaction_matrix)
        }
        
        cluster_members.each { |member| processed_students.add(member.id) }
      end
    end
    
    clusters
  end

  def find_connected_component(start_student, interaction_matrix, all_students)
    # Simple connected component finding
    visited = Set.new
    queue = [start_student]
    component = []
    
    while queue.any?
      current = queue.shift
      next if visited.include?(current.id)
      
      visited.add(current.id)
      component << current
      
      # Find connected students
      connections = get_student_connections(current, interaction_matrix)
      strong_connections = connections.select { |c| c[:strength] == :high }
      
      strong_connections.each do |conn|
        queue << conn[:partner] unless visited.include?(conn[:partner].id)
      end
    end
    
    component
  end

  def count_internal_connections(cluster_members, interaction_matrix)
    member_ids = cluster_members.map(&:id)
    
    interaction_matrix.count do |pair_key, _|
      student_ids = pair_key.split('-').map(&:to_i)
      (student_ids & member_ids).count == 2
    end
  end

  def identify_bridge_students(student_metrics)
    # Students with high centrality but diverse connections across clusters
    student_metrics.select do |metrics|
      metrics[:centrality_score] > 0.3 && 
      metrics[:total_connections] > student_metrics.map { |m| m[:total_connections] }.sum / student_metrics.count.to_f
    end.first(5)
  end

  def identify_isolated_students(student_metrics)
    threshold = student_metrics.map { |m| m[:total_connections] }.sum.to_f / student_metrics.count / 2
    student_metrics.select { |metrics| metrics[:total_connections] < threshold }
  end

  def calculate_network_health_score(student_metrics, clusters)
    # Combined score based on connectivity, clustering, and balance
    avg_connections = student_metrics.map { |m| m[:total_connections] }.sum.to_f / student_metrics.count
    connection_variance = calculate_coefficient_of_variation(student_metrics.map { |m| m[:total_connections] })
    cluster_balance = clusters.empty? ? 0 : 1.0 - calculate_coefficient_of_variation(clusters.map { |c| c[:size] })
    
    # Weighted combination (0-100 scale)
    ((avg_connections * 0.4 + (1 - connection_variance) * 0.3 + cluster_balance * 0.3) * 100).round(1)
  end

  # Additional helper methods would be implemented here...
  # Simplified implementations for brevity

  def calculate_interaction_novelty(daily_arrangements)
    0.75 # Placeholder
  end

  def calculate_rotation_balance(daily_arrangements)
    0.85 # Placeholder
  end

  def calculate_student_exposure_metrics(daily_arrangements)
    { avg_partners_per_day: 3.5, unique_partner_ratio: 0.78 }
  end

  def calculate_clustering_avoidance(daily_arrangements)
    0.82 # Placeholder
  end

  def analyze_alternative_strategies(daily_arrangements)
    {} # Placeholder for strategy comparison
  end

  def calculate_optimization_success_rate(effectiveness_metrics)
    85.5 # Placeholder percentage
  end

  def generate_rotation_recommendations(effectiveness_metrics)
    ["Consider increasing interaction novelty", "Maintain current rotation balance"]
  end

  # More helper methods would be implemented here for a complete system
end