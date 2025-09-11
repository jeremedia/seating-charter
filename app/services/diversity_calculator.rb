# frozen_string_literal: true

class DiversityCalculator
  # Default weights for different diversity dimensions
  DEFAULT_WEIGHTS = {
    agency_diversity: 0.25,
    geographic_diversity: 0.20,
    role_diversity: 0.20,
    gender_diversity: 0.15,
    experience_diversity: 0.10,
    interaction_history: 0.10
  }.freeze

  def initialize(weights = {})
    @weights = DEFAULT_WEIGHTS.merge(weights)
  end

  def calculate_total_score(arrangement, seating_event)
    return 0.0 if arrangement.empty?

    detailed_metrics = calculate_detailed_metrics(arrangement, seating_event)
    
    # Weighted sum of all diversity dimensions
    total_score = @weights.sum do |dimension, weight|
      score = detailed_metrics.dig(:overall, dimension, :score) || 0.0
      weight * score.to_f
    end

    # Normalize to 0-1 range
    [total_score, 1.0].min
  end

  def calculate_detailed_metrics(arrangement, seating_event)
    metrics = {}
    
    arrangement.each do |table_number, students|
      next if students.size < 2 # Skip tables with less than 2 students
      
      table_metrics = {
        agency_diversity: calculate_agency_diversity(students),
        geographic_diversity: calculate_geographic_diversity(students),
        role_diversity: calculate_role_diversity(students),
        gender_diversity: calculate_gender_diversity(students),
        experience_diversity: calculate_experience_diversity(students),
        interaction_history: calculate_interaction_penalty(students, seating_event)
      }
      
      metrics["table_#{table_number}"] = table_metrics
    end
    
    # Calculate overall metrics as weighted average of table metrics
    overall_metrics = calculate_overall_metrics(metrics)
    
    {
      overall: overall_metrics,
      by_table: metrics,
      summary: generate_summary_stats(arrangement, overall_metrics)
    }
  end

  private

  def calculate_agency_diversity(students)
    agency_levels = students.map(&:agency_level).compact.uniq
    organizations = students.map(&:organization).compact.uniq
    
    # Combine agency level diversity with organizational diversity
    level_diversity = calculate_diversity_index(students.map(&:agency_level).compact)
    org_diversity = calculate_diversity_index(students.map(&:organization).compact)
    
    # Weight organizational diversity higher as it's more specific
    combined_score = (level_diversity * 0.3) + (org_diversity * 0.7)
    
    {
      score: combined_score,
      unique_agencies: agency_levels.size,
      unique_organizations: organizations.size,
      details: {
        agency_levels: agency_levels,
        organizations: organizations.take(5) # Limit for display
      }
    }
  end

  def calculate_geographic_diversity(students)
    locations = students.map(&:location).compact
    return { score: 0.0, unique_locations: 0, details: { locations: [] } } if locations.empty?
    
    # Extract states/regions for broader geographic diversity
    states = locations.map { |loc| extract_state_from_location(loc) }.compact.uniq
    
    location_diversity = calculate_diversity_index(locations)
    state_diversity = calculate_diversity_index(states)
    
    # Combine location and state diversity
    combined_score = (location_diversity * 0.6) + (state_diversity * 0.4)
    
    {
      score: combined_score,
      unique_locations: locations.uniq.size,
      unique_states: states.size,
      details: {
        locations: locations.uniq.take(5),
        states: states.take(5)
      }
    }
  end

  def calculate_role_diversity(students)
    titles = students.map(&:title).compact
    return { score: 0.0, unique_roles: 0, details: { titles: [] } } if titles.empty?
    
    # Normalize titles to role categories
    role_categories = titles.map { |title| categorize_role(title) }.compact
    seniority_levels = students.map(&:seniority_level).compact
    
    title_diversity = calculate_diversity_index(titles)
    category_diversity = calculate_diversity_index(role_categories)
    seniority_diversity = calculate_diversity_index(seniority_levels)
    
    # Weighted combination
    combined_score = (title_diversity * 0.4) + (category_diversity * 0.4) + (seniority_diversity * 0.2)
    
    {
      score: combined_score,
      unique_roles: titles.uniq.size,
      unique_categories: role_categories.uniq.size,
      details: {
        titles: titles.uniq.take(5),
        categories: role_categories.uniq,
        seniority_levels: seniority_levels.uniq
      }
    }
  end

  def calculate_gender_diversity(students)
    genders = students.map(&:gender).compact
    return { score: 0.0, distribution: {}, details: { genders: [] } } if genders.empty?
    
    diversity_score = calculate_diversity_index(genders)
    gender_distribution = genders.group_by(&:itself).transform_values(&:count)
    
    {
      score: diversity_score,
      distribution: gender_distribution,
      details: {
        genders: genders.uniq,
        balance_ratio: calculate_balance_ratio(gender_distribution)
      }
    }
  end

  def calculate_experience_diversity(students)
    # Use a combination of seniority level and inferred experience indicators
    seniority_levels = students.map(&:seniority_level).compact
    
    # Infer experience from titles and organizations
    experience_indicators = students.map do |student|
      infer_experience_level(student.title, student.seniority_level)
    end.compact
    
    seniority_diversity = calculate_diversity_index(seniority_levels)
    experience_diversity = calculate_diversity_index(experience_indicators)
    
    combined_score = (seniority_diversity * 0.6) + (experience_diversity * 0.4)
    
    {
      score: combined_score,
      seniority_levels: seniority_levels.uniq,
      experience_indicators: experience_indicators.uniq,
      details: {
        distribution: experience_indicators.group_by(&:itself).transform_values(&:count)
      }
    }
  end

  def calculate_interaction_penalty(students, seating_event)
    return { score: 1.0, previous_interactions: 0, details: {} } if students.size < 2
    
    total_penalty = 0.0
    interaction_count = 0
    interaction_details = {}
    
    students.combination(2) do |student_a, student_b|
      # Check previous interactions in this cohort
      interactions = InteractionTracking.joins(:seating_event)
        .where(seating_events: { cohort_id: seating_event.cohort_id })
        .where(
          '(student_a_id = ? AND student_b_id = ?) OR (student_a_id = ? AND student_b_id = ?)',
          student_a.id, student_b.id, student_b.id, student_a.id
        )
        .where.not(seating_event_id: seating_event.id)
      
      interaction_count_pair = interactions.sum(:interaction_count)
      
      if interaction_count_pair > 0
        # Apply penalty based on how recently and frequently they've interacted
        penalty = calculate_interaction_penalty_for_pair(interactions)
        total_penalty += penalty
        interaction_count += interaction_count_pair
        
        interaction_details["#{student_a.name} & #{student_b.name}"] = {
          count: interaction_count_pair,
          penalty: penalty,
          last_interaction: interactions.maximum(:last_interaction)
        }
      end
    end
    
    # Convert penalty to score (higher penalty = lower score)
    max_possible_penalty = students.combination(2).count * 1.0
    penalty_ratio = max_possible_penalty > 0 ? total_penalty / max_possible_penalty : 0
    score = [1.0 - penalty_ratio, 0.0].max
    
    {
      score: score,
      previous_interactions: interaction_count,
      interaction_pairs: interaction_details.size,
      details: interaction_details
    }
  end

  def calculate_overall_metrics(table_metrics)
    return {} if table_metrics.empty?
    
    overall = {}
    dimension_names = table_metrics.values.first.keys
    
    dimension_names.each do |dimension|
      scores = table_metrics.values.map { |metrics| metrics[dimension][:score] }
      overall[dimension] = {
        score: scores.sum / scores.size,
        min: scores.min,
        max: scores.max,
        std_dev: calculate_standard_deviation(scores)
      }
    end
    
    overall
  end

  def generate_summary_stats(arrangement, overall_metrics)
    total_students = arrangement.values.sum(&:size)
    total_tables = arrangement.keys.size
    avg_table_size = total_students.to_f / total_tables
    
    {
      total_students: total_students,
      total_tables: total_tables,
      average_table_size: avg_table_size.round(1),
      overall_score: overall_metrics.values.sum { |m| m[:score] } / overall_metrics.size,
      score_distribution: {
        min: overall_metrics.values.map { |m| m[:min] }.min,
        max: overall_metrics.values.map { |m| m[:max] }.max,
        avg_std_dev: overall_metrics.values.sum { |m| m[:std_dev] } / overall_metrics.size
      }
    }
  end

  # Helper methods for diversity calculations

  def calculate_diversity_index(values)
    return 0.0 if values.empty?
    
    # Use Simpson's Diversity Index: 1 - Σ(p_i^2)
    # Where p_i is the proportion of each category
    total = values.size.to_f
    proportions = values.group_by(&:itself).values.map { |group| (group.size / total) ** 2 }
    
    1.0 - proportions.sum
  end

  def extract_state_from_location(location)
    # Simple extraction - look for state abbreviations or common patterns
    state_match = location.match(/,\s*([A-Z]{2})(?:\s|$)/) || location.match(/,\s*([A-Z]{2,})\s*$/)
    state_match&.[](1)
  end

  def categorize_role(title)
    return nil if title.blank?
    
    title_lower = title.downcase
    
    case title_lower
    when /chief|ceo|coo|cfo|president|executive|director/
      'executive'
    when /manager|supervisor|lead|coordinator/
      'management'
    when /analyst|specialist|officer|agent/
      'professional'
    when /assistant|admin|support|clerk/
      'support'
    when /engineer|developer|architect|scientist/
      'technical'
    else
      'other'
    end
  end

  def infer_experience_level(title, seniority_level)
    return seniority_level if seniority_level.present?
    return nil if title.blank?
    
    title_lower = title.downcase
    
    case title_lower
    when /senior|sr\.|lead|principal|chief|director/
      'senior'
    when /junior|jr\.|associate|assistant/
      'junior'
    when /manager|supervisor|coordinator/
      'mid'
    else
      'mid'
    end
  end

  def calculate_interaction_penalty_for_pair(interactions)
    return 0.0 if interactions.empty?
    
    base_penalty = 0.1
    
    interactions.each do |interaction|
      # Higher penalty for more recent interactions
      days_ago = (Date.current - interaction.last_interaction).to_i
      recency_multiplier = [2.0 - (days_ago / 30.0), 0.1].max
      
      # Higher penalty for more frequent interactions
      frequency_multiplier = [interaction.interaction_count / 5.0, 2.0].min
      
      base_penalty += (0.1 * recency_multiplier * frequency_multiplier)
    end
    
    [base_penalty, 1.0].min
  end

  def calculate_balance_ratio(distribution)
    return 1.0 if distribution.size <= 1
    
    values = distribution.values.sort
    min_count = values.first.to_f
    max_count = values.last.to_f
    
    max_count > 0 ? min_count / max_count : 0.0
  end

  def calculate_standard_deviation(values)
    return 0.0 if values.size < 2
    
    mean = values.sum / values.size.to_f
    variance = values.sum { |v| (v - mean) ** 2 } / values.size.to_f
    Math.sqrt(variance)
  end
end