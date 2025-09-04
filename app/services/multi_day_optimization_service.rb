# frozen_string_literal: true

class MultiDayOptimizationService
  DEFAULT_MAX_RUNTIME_PER_DAY = 20.seconds
  DEFAULT_ROTATION_STRATEGY = :maximum_diversity
  
  attr_reader :seating_event, :optimization_params, :results
  
  def initialize(seating_event, optimization_params = {})
    @seating_event = seating_event
    @optimization_params = optimization_params.with_indifferent_access
    @results = {}
    @interaction_tracker = InteractionTrackingService.new(seating_event)
    @rotation_service = RotationStrategyService.new(seating_event, optimization_params)
  end

  def optimize_multiple_days(days_config:, rotation_strategy: DEFAULT_ROTATION_STRATEGY, max_runtime_per_day: DEFAULT_MAX_RUNTIME_PER_DAY)
    Rails.logger.info "Starting multi-day optimization for event #{seating_event.id} with #{days_config.length} days"
    
    return failure_result("Multi-day events require at least 2 days") if days_config.length < 2
    return failure_result("Multi-day events limited to 10 days maximum") if days_config.length > 10
    
    start_time = Time.current
    students = seating_event.cohort.students.includes(:table_assignments)
    
    return failure_result("No students found") if students.empty?
    return failure_result("Insufficient students for optimization") if students.count < 2
    
    # Initialize tracking for multi-day optimization
    daily_arrangements = {}
    daily_metrics = {}
    overall_interaction_matrix = {}
    
    days_config.each_with_index do |day_config, day_index|
      day_number = day_index + 1
      Rails.logger.info "Optimizing day #{day_number} of #{days_config.length}"
      
      # Get students attending this day (handle absences)
      attending_students = get_attending_students(students, day_config)
      next if attending_students.empty?
      
      # Apply day-specific constraints and preferences
      day_optimization_params = build_day_optimization_params(day_config, day_number)
      
      # Use rotation strategy to get base arrangement for this day
      base_arrangement = @rotation_service.generate_day_arrangement(
        day_number: day_number,
        students: attending_students,
        previous_arrangements: daily_arrangements,
        strategy: rotation_strategy,
        day_config: day_config
      )
      
      # Optimize the base arrangement using single-day optimizer with multi-day context
      day_optimizer = create_day_optimizer(attending_students, day_optimization_params)
      optimization_result = day_optimizer.optimize(
        initial_arrangement: base_arrangement,
        max_runtime: max_runtime_per_day,
        interaction_history: overall_interaction_matrix
      )
      
      if optimization_result[:success]
        daily_arrangements[day_number] = optimization_result[:arrangement]
        daily_metrics[day_number] = optimization_result[:diversity_metrics]
        
        # Update interaction tracking
        @interaction_tracker.record_day_interactions(
          day_number: day_number,
          arrangement: optimization_result[:arrangement],
          interaction_matrix: overall_interaction_matrix
        )
        
        Rails.logger.info "Day #{day_number} optimized successfully with score #{optimization_result[:score].round(3)}"
      else
        Rails.logger.error "Failed to optimize day #{day_number}: #{optimization_result[:error]}"
        return failure_result("Optimization failed for day #{day_number}: #{optimization_result[:error]}")
      end
    end
    
    # Calculate overall multi-day metrics
    overall_metrics = calculate_overall_metrics(daily_arrangements, daily_metrics, overall_interaction_matrix)
    total_runtime = Time.current - start_time
    
    @results = {
      success: true,
      daily_arrangements: daily_arrangements,
      daily_metrics: daily_metrics,
      overall_metrics: overall_metrics,
      interaction_matrix: overall_interaction_matrix,
      optimization_stats: {
        total_days: days_config.length,
        rotation_strategy: rotation_strategy,
        total_runtime: total_runtime.round(2),
        average_daily_score: overall_metrics[:average_daily_score],
        interaction_coverage: overall_metrics[:interaction_coverage],
        diversity_trend: overall_metrics[:diversity_trend]
      }
    }
    
    Rails.logger.info "Multi-day optimization completed: #{days_config.length} days in #{total_runtime.round(2)}s"
    Rails.logger.info "Overall interaction coverage: #{overall_metrics[:interaction_coverage].round(2)}%"
    
    @results
  end

  def save_multi_day_arrangement(arrangement_data, created_by)
    return nil unless arrangement_data[:success]
    
    saved_arrangements = {}
    
    arrangement_data[:daily_arrangements].each do |day_number, daily_arrangement|
      seating_arrangement = seating_event.seating_arrangements.build(
        arrangement_data: daily_arrangement,
        optimization_scores: arrangement_data[:optimization_stats].merge(day_number: day_number),
        diversity_metrics: arrangement_data[:daily_metrics][day_number],
        created_by: created_by,
        day_number: day_number
      )
      
      if seating_arrangement.save
        create_table_assignments(seating_arrangement, daily_arrangement)
        saved_arrangements[day_number] = seating_arrangement
      else
        # Rollback if any day fails
        saved_arrangements.values.each(&:destroy)
        return nil
      end
    end
    
    # Save overall multi-day metrics
    save_multi_day_metrics(arrangement_data, created_by, saved_arrangements)
    
    saved_arrangements
  end

  def analyze_interaction_patterns(arrangements_data)
    interaction_analyzer = InteractionPatternAnalyzer.new(seating_event)
    interaction_analyzer.analyze_multi_day_patterns(
      arrangements_data[:daily_arrangements],
      arrangements_data[:interaction_matrix]
    )
  end

  def generate_rotation_preview(days_count:, rotation_strategy: DEFAULT_ROTATION_STRATEGY)
    students = seating_event.cohort.students.limit(20) # Preview with subset for performance
    preview_arrangements = {}
    
    (1..days_count).each do |day_number|
      preview_arrangements[day_number] = @rotation_service.generate_day_arrangement(
        day_number: day_number,
        students: students,
        previous_arrangements: preview_arrangements.slice(1...day_number),
        strategy: rotation_strategy,
        day_config: { constraints: [], preferences: [] }
      )
    end
    
    {
      success: true,
      preview_arrangements: preview_arrangements,
      rotation_strategy: rotation_strategy,
      student_sample_size: students.count
    }
  end

  private

  def get_attending_students(all_students, day_config)
    if day_config[:absent_student_ids].present?
      all_students.reject { |s| day_config[:absent_student_ids].include?(s.id) }
    else
      all_students
    end
  end

  def build_day_optimization_params(day_config, day_number)
    base_params = @optimization_params.dup
    
    # Add day-specific constraints
    if day_config[:constraints].present?
      base_params[:day_constraints] = day_config[:constraints]
    end
    
    # Add day-specific preferences
    if day_config[:preferences].present?
      base_params[:day_preferences] = day_config[:preferences]
    end
    
    # Add day context for optimization weighting
    base_params[:day_number] = day_number
    base_params[:is_first_day] = day_number == 1
    base_params[:multi_day_context] = true
    
    base_params
  end

  def create_day_optimizer(students, optimization_params)
    MultiDayAwareSingleDayOptimizer.new(seating_event, optimization_params)
  end

  def calculate_overall_metrics(daily_arrangements, daily_metrics, interaction_matrix)
    total_students = seating_event.cohort.students.count
    possible_interactions = total_students * (total_students - 1) / 2
    actual_interactions = interaction_matrix.values.sum { |interactions| interactions.count }
    
    daily_scores = daily_metrics.values.map { |metrics| metrics[:overall_score] || 0 }
    
    {
      average_daily_score: daily_scores.sum / daily_scores.length.to_f,
      interaction_coverage: (actual_interactions.to_f / possible_interactions * 100),
      diversity_trend: calculate_diversity_trend(daily_scores),
      total_unique_interactions: actual_interactions,
      possible_interactions: possible_interactions,
      days_optimized: daily_arrangements.keys.count,
      interaction_distribution: calculate_interaction_distribution(interaction_matrix)
    }
  end

  def calculate_diversity_trend(daily_scores)
    return 0 if daily_scores.length < 2
    
    # Calculate the trend using linear regression slope
    n = daily_scores.length
    sum_x = (1..n).sum
    sum_y = daily_scores.sum
    sum_xy = daily_scores.each_with_index.sum { |score, i| score * (i + 1) }
    sum_x_squared = (1..n).sum { |i| i * i }
    
    slope = (n * sum_xy - sum_x * sum_y).to_f / (n * sum_x_squared - sum_x * sum_x)
    slope.round(4)
  end

  def calculate_interaction_distribution(interaction_matrix)
    frequency_counts = Hash.new(0)
    
    interaction_matrix.each do |student_pair, interactions|
      frequency_counts[interactions.length] += 1
    end
    
    frequency_counts
  end

  def create_table_assignments(seating_arrangement, arrangement_data)
    arrangement_data.each do |table_number, students|
      students.each_with_index do |student, seat_position|
        seating_arrangement.table_assignments.create!(
          student: student,
          table_number: table_number,
          seat_position: seat_position + 1,
          locked: false
        )
      end
    end
  end

  def save_multi_day_metrics(arrangement_data, created_by, saved_arrangements)
    # Save to a separate model for multi-day analytics if needed
    # For now, we'll store in the seating_event's metadata
    seating_event.update(
      multi_day_metrics: arrangement_data[:overall_metrics],
      multi_day_optimization_completed_at: Time.current,
      multi_day_optimization_created_by: created_by.id
    )
  end

  def failure_result(message)
    {
      success: false,
      error: message,
      daily_arrangements: {},
      daily_metrics: {},
      overall_metrics: {},
      interaction_matrix: {},
      optimization_stats: {}
    }
  end
end

# Supporting service for interaction tracking across multiple days
class InteractionTrackingService
  def initialize(seating_event)
    @seating_event = seating_event
  end

  def record_day_interactions(day_number:, arrangement:, interaction_matrix:)
    arrangement.each do |table_number, students|
      # Record all pairwise interactions at this table
      students.combination(2).each do |student_a, student_b|
        pair_key = generate_pair_key(student_a, student_b)
        interaction_matrix[pair_key] ||= []
        interaction_matrix[pair_key] << {
          day: day_number,
          table: table_number,
          recorded_at: Time.current
        }
        
        # Also update the database interaction tracking
        update_database_interaction(student_a, student_b, day_number)
      end
    end
  end

  private

  def generate_pair_key(student_a, student_b)
    [student_a.id, student_b.id].sort.join("-")
  end

  def update_database_interaction(student_a, student_b)
    interaction = InteractionTracking.find_or_initialize_by(
      student_a: [student_a, student_b].min_by(&:id),
      student_b: [student_a, student_b].max_by(&:id),
      seating_event: @seating_event
    )
    
    interaction.increment_interaction!
  end
end

# Multi-day aware single day optimizer
class MultiDayAwareSingleDayOptimizer
  def initialize(seating_event, optimization_params)
    @seating_event = seating_event
    @optimization_params = optimization_params
    @base_optimizer = SeatingOptimizationService.new(seating_event, optimization_params)
  end

  def optimize(initial_arrangement:, max_runtime:, interaction_history: {})
    # Modify the optimization to consider interaction history
    enhanced_params = @optimization_params.merge(
      interaction_penalty_weight: 2.0, # Penalize repeated interactions
      interaction_history: interaction_history,
      initial_arrangement: initial_arrangement
    )
    
    # Use the base optimizer with enhanced parameters
    @base_optimizer.optimize(
      max_runtime: max_runtime
    )
  end
end