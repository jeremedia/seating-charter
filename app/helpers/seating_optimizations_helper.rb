# frozen_string_literal: true

module SeatingOptimizationsHelper
  def diversity_score_color_class(score)
    case score
    when 0.8..1.0
      'text-green-600 bg-green-100'
    when 0.6..0.79
      'text-yellow-600 bg-yellow-100'
    when 0.4..0.59
      'text-orange-600 bg-orange-100'
    else
      'text-red-600 bg-red-100'
    end
  end

  def diversity_score_badge(score)
    percentage = (score * 100).round(1)
    classes = diversity_score_color_class(score)
    
    content_tag :span, "#{percentage}%", 
                class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{classes}"
  end

  def constraint_violation_badge(violation)
    case violation[:severity]
    when :hard
      content_tag :span, "HARD", 
                  class: "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800"
    when :soft
      content_tag :span, "SOFT", 
                  class: "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800"
    else
      content_tag :span, "UNKNOWN", 
                  class: "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800"
    end
  end

  def optimization_strategy_description(strategy)
    case strategy.to_s.downcase
    when 'random_swap'
      "Simple random swapping of students between tables. Fast execution but may not find optimal solutions."
    when 'simulated_annealing'
      "Temperature-based optimization that gradually reduces randomness. Balances exploration and exploitation for high-quality results."
    when 'genetic_algorithm'
      "Population-based evolutionary approach using crossover and mutation. Excellent for complex scenarios but requires more computation time."
    else
      "Unknown optimization strategy."
    end
  end

  def format_runtime(seconds)
    return "0s" unless seconds&.positive?
    
    if seconds < 60
      "#{seconds.round(1)}s"
    else
      minutes = (seconds / 60).floor
      remaining_seconds = (seconds % 60).round
      "#{minutes}m #{remaining_seconds}s"
    end
  end

  def diversity_dimension_icon(dimension)
    case dimension.to_s
    when 'agency_diversity'
      '🏛️'  # Government building
    when 'geographic_diversity'
      '🗺️'   # World map
    when 'role_diversity'
      '👥'   # People
    when 'gender_diversity'
      '⚖️'   # Balance scale
    when 'experience_diversity'
      '📊'   # Chart
    when 'interaction_history'
      '🤝'   # Handshake
    else
      '📋'   # Clipboard
    end
  end

  def diversity_dimension_title(dimension)
    case dimension.to_s
    when 'agency_diversity'
      'Agency & Organization Diversity'
    when 'geographic_diversity'
      'Geographic Diversity'
    when 'role_diversity'
      'Role & Seniority Diversity'
    when 'gender_diversity'
      'Gender Diversity'
    when 'experience_diversity'
      'Experience Level Diversity'
    when 'interaction_history'
      'Interaction History Balance'
    else
      dimension.to_s.humanize
    end
  end

  def table_diversity_score(table_metrics)
    return 0.0 unless table_metrics.is_a?(Hash)
    
    scores = table_metrics.values.map { |metric| metric.is_a?(Hash) ? metric[:score] : 0.0 }
    scores.empty? ? 0.0 : scores.sum / scores.size
  end

  def student_attribute_display(student, attribute)
    case attribute.to_s
    when 'gender'
      student.gender&.titleize || 'Not specified'
    when 'agency_level'
      student.agency_level&.titleize || 'Not specified'
    when 'seniority_level'
      student.seniority_level&.titleize || 'Not specified'
    when 'department_type'
      student.department_type&.titleize || 'Not specified'
    else
      student.send(attribute) if student.respond_to?(attribute)
    end
  rescue
    'Not available'
  end

  def optimization_improvement_text(initial_score, final_score)
    return "No improvement data" unless initial_score && final_score
    
    improvement = ((final_score - initial_score) * 100).round(1)
    
    if improvement > 0
      "+#{improvement}% improvement"
    elsif improvement < 0
      "#{improvement}% (regression)"
    else
      "No change"
    end
  end

  def arrangement_quality_text(score)
    case score
    when 0.9..1.0
      "Excellent diversity"
    when 0.8..0.89
      "Very good diversity"
    when 0.7..0.79
      "Good diversity"
    when 0.6..0.69
      "Adequate diversity"
    when 0.5..0.59
      "Moderate diversity"
    when 0.4..0.49
      "Below average diversity"
    else
      "Needs improvement"
    end
  end

  def table_size_status(actual_size, target_size)
    if actual_size == target_size
      content_tag :span, "Optimal", class: "text-green-600 text-sm font-medium"
    elsif actual_size > target_size
      content_tag :span, "Over capacity", class: "text-red-600 text-sm font-medium"
    elsif actual_size < 2
      content_tag :span, "Under minimum", class: "text-yellow-600 text-sm font-medium"
    else
      content_tag :span, "Acceptable", class: "text-gray-600 text-sm font-medium"
    end
  end

  def progress_bar(percentage, color_class = "bg-blue-600")
    content_tag :div, class: "w-full bg-gray-200 rounded-full h-2" do
      content_tag :div, "", 
                  class: "#{color_class} h-2 rounded-full transition-all duration-300",
                  style: "width: #{percentage}%"
    end
  end
end