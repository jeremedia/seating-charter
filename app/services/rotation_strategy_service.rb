# frozen_string_literal: true

class RotationStrategyService
  ROTATION_STRATEGIES = {
    maximum_diversity: 'Maximize interaction diversity across all days',
    structured_rotation: 'Systematic rotation with predictable patterns',
    random_rotation: 'Random rotation with anti-clustering constraints',
    custom_pattern: 'Custom rotation pattern defined by user',
    progressive_mixing: 'Gradual relationship building from teams to individuals',
    geographic_rotation: 'Rotate based on geographic or demographic attributes'
  }.freeze

  attr_reader :seating_event, :optimization_params

  def initialize(seating_event, optimization_params = {})
    @seating_event = seating_event
    @optimization_params = optimization_params.with_indifferent_access
  end

  def generate_day_arrangement(day_number:, students:, previous_arrangements: {}, strategy: :maximum_diversity, day_config: {})
    Rails.logger.info "Generating day #{day_number} arrangement using #{strategy} strategy"

    case strategy.to_sym
    when :maximum_diversity
      maximum_diversity_rotation(day_number, students, previous_arrangements, day_config)
    when :structured_rotation
      structured_rotation(day_number, students, previous_arrangements, day_config)
    when :random_rotation
      random_rotation_with_constraints(day_number, students, previous_arrangements, day_config)
    when :custom_pattern
      custom_pattern_rotation(day_number, students, previous_arrangements, day_config)
    when :progressive_mixing
      progressive_mixing_rotation(day_number, students, previous_arrangements, day_config)
    when :geographic_rotation
      geographic_rotation(day_number, students, previous_arrangements, day_config)
    else
      raise ArgumentError, "Unknown rotation strategy: #{strategy}"
    end
  end

  def preview_rotation_pattern(strategy:, days_count:, sample_students: nil)
    sample_students ||= seating_event.cohort.students.limit(12) # Use small sample for preview
    preview_arrangements = {}

    (1..days_count).each do |day_number|
      preview_arrangements[day_number] = generate_day_arrangement(
        day_number: day_number,
        students: sample_students,
        previous_arrangements: preview_arrangements.slice(1...day_number),
        strategy: strategy,
        day_config: { constraints: [], preferences: [] }
      )
    end

    analyze_preview_pattern(preview_arrangements, sample_students, strategy)
  end

  def calculate_rotation_efficiency(arrangements, students)
    return 0 if arrangements.empty?

    total_interactions = calculate_total_interactions(arrangements)
    possible_interactions = students.count * (students.count - 1) / 2 * arrangements.count
    unique_interactions = calculate_unique_interactions(arrangements)

    {
      interaction_coverage: (unique_interactions.to_f / (students.count * (students.count - 1) / 2) * 100).round(2),
      repetition_rate: ((total_interactions - unique_interactions).to_f / total_interactions * 100).round(2),
      efficiency_score: (unique_interactions.to_f / total_interactions * 100).round(2)
    }
  end

  private

  # Maximum Diversity Strategy - prioritize students who haven't interacted
  def maximum_diversity_rotation(day_number, students, previous_arrangements, day_config)
    if day_number == 1
      return generate_initial_balanced_arrangement(students)
    end

    # Get interaction history from previous days
    interaction_penalties = calculate_interaction_penalties(students, previous_arrangements)
    
    # Use genetic algorithm approach to minimize interaction penalties
    best_arrangement = nil
    best_score = Float::INFINITY
    
    # Try multiple random starting arrangements and pick the best
    20.times do
      arrangement = generate_diversity_focused_arrangement(students, interaction_penalties)
      score = calculate_arrangement_penalty_score(arrangement, interaction_penalties)
      
      if score < best_score
        best_score = score
        best_arrangement = arrangement
      end
    end
    
    best_arrangement
  end

  # Structured Rotation - systematic approach like round-robin
  def structured_rotation(day_number, students, previous_arrangements, day_config)
    if day_number == 1
      return generate_initial_balanced_arrangement(students)
    end

    students_per_table = seating_event.table_size
    total_tables = seating_event.total_tables
    
    # Calculate rotation offset based on day number and table structure
    rotation_offset = calculate_structured_rotation_offset(day_number, students.count, students_per_table)
    
    # Apply rotation to previous day's arrangement
    previous_arrangement = previous_arrangements[day_number - 1]
    return generate_initial_balanced_arrangement(students) unless previous_arrangement

    rotate_arrangement_systematically(previous_arrangement, rotation_offset, students)
  end

  # Random Rotation with Constraints - avoid consecutive interactions
  def random_rotation_with_constraints(day_number, students, previous_arrangements, day_config)
    max_attempts = 100
    attempts = 0
    
    loop do
      arrangement = generate_random_arrangement(students)
      
      if valid_random_arrangement?(arrangement, previous_arrangements, day_config)
        return arrangement
      end
      
      attempts += 1
      break if attempts >= max_attempts
    end
    
    # Fallback to maximum diversity if constraints can't be satisfied
    maximum_diversity_rotation(day_number, students, previous_arrangements, day_config)
  end

  # Custom Pattern - user-defined rotation rules
  def custom_pattern_rotation(day_number, students, previous_arrangements, day_config)
    custom_rules = day_config[:custom_rotation_rules] || optimization_params[:custom_rotation_rules]
    
    if custom_rules.present?
      apply_custom_rotation_rules(day_number, students, previous_arrangements, custom_rules)
    else
      # Fallback to maximum diversity
      maximum_diversity_rotation(day_number, students, previous_arrangements, day_config)
    end
  end

  # Progressive Mixing - gradually break up initial groups
  def progressive_mixing_rotation(day_number, students, previous_arrangements, day_config)
    mixing_intensity = calculate_mixing_intensity(day_number)
    
    if day_number == 1
      # Start with attribute-based groupings (teams, departments, etc.)
      return generate_attribute_grouped_arrangement(students)
    end

    previous_arrangement = previous_arrangements[day_number - 1]
    return generate_initial_balanced_arrangement(students) unless previous_arrangement

    apply_progressive_mixing(previous_arrangement, students, mixing_intensity)
  end

  # Geographic Rotation - based on location/demographic attributes
  def geographic_rotation(day_number, students, previous_arrangements, day_config)
    geographic_attribute = day_config[:geographic_attribute] || 'location'
    
    if day_number == 1
      return generate_geographic_balanced_arrangement(students, geographic_attribute)
    end

    # Rotate while maintaining geographic diversity at each table
    previous_arrangement = previous_arrangements[day_number - 1]
    rotate_with_geographic_constraints(previous_arrangement, students, geographic_attribute)
  end

  # Helper methods for arrangement generation
  def generate_initial_balanced_arrangement(students)
    tables = {}
    students_per_table = seating_event.table_size
    total_tables = seating_event.total_tables
    
    # Shuffle students for randomness
    shuffled_students = students.shuffle
    
    shuffled_students.each_with_index do |student, index|
      table_number = (index % total_tables) + 1
      tables[table_number] ||= []
      
      if tables[table_number].size < students_per_table
        tables[table_number] << student
      else
        # Find table with least students
        least_filled_table = tables.min_by { |_, students_list| students_list.size }
        least_filled_table[1] << student
      end
    end
    
    tables
  end

  def calculate_interaction_penalties(students, previous_arrangements)
    penalties = Hash.new(0)
    
    previous_arrangements.each do |day, arrangement|
      arrangement.each do |table_number, table_students|
        table_students.combination(2).each do |student_a, student_b|
          key = [student_a.id, student_b.id].sort.join('-')
          penalties[key] += 1
        end
      end
    end
    
    penalties
  end

  def generate_diversity_focused_arrangement(students, interaction_penalties)
    students_per_table = seating_event.table_size
    total_tables = seating_event.total_tables
    
    # Create tables array
    tables = Array.new(total_tables) { [] }
    remaining_students = students.dup.shuffle
    
    # Fill tables trying to minimize interaction penalties
    remaining_students.each do |student|
      best_table_index = find_best_table_for_student(student, tables, interaction_penalties)
      
      if tables[best_table_index].size < students_per_table
        tables[best_table_index] << student
      else
        # Find any table with space
        available_table_index = tables.find_index { |table| table.size < students_per_table }
        if available_table_index
          tables[available_table_index] << student
        else
          # Add to least filled table
          least_filled_index = tables.each_with_index.min_by { |table, _| table.size }[1]
          tables[least_filled_index] << student
        end
      end
    end
    
    # Convert to hash format
    result = {}
    tables.each_with_index do |table_students, index|
      result[index + 1] = table_students if table_students.any?
    end
    
    result
  end

  def find_best_table_for_student(student, tables, interaction_penalties)
    best_table_index = 0
    lowest_penalty = Float::INFINITY
    
    tables.each_with_index do |table, index|
      next if table.size >= seating_event.table_size
      
      # Calculate penalty for placing student at this table
      penalty = 0
      table.each do |table_student|
        key = [student.id, table_student.id].sort.join('-')
        penalty += interaction_penalties[key]
      end
      
      if penalty < lowest_penalty
        lowest_penalty = penalty
        best_table_index = index
      end
    end
    
    best_table_index
  end

  def calculate_arrangement_penalty_score(arrangement, interaction_penalties)
    total_penalty = 0
    
    arrangement.each do |table_number, students|
      students.combination(2).each do |student_a, student_b|
        key = [student_a.id, student_b.id].sort.join('-')
        total_penalty += interaction_penalties[key] || 0
      end
    end
    
    total_penalty
  end

  def calculate_structured_rotation_offset(day_number, student_count, students_per_table)
    # Calculate optimal rotation to maximize new interactions
    base_offset = day_number - 1
    
    # Adjust offset based on table size to avoid simple patterns
    adjusted_offset = (base_offset * students_per_table) % student_count
    
    # Add small random component to break ties
    adjusted_offset + rand(students_per_table)
  end

  def rotate_arrangement_systematically(previous_arrangement, rotation_offset, students)
    # Convert arrangement to flat list, rotate, then rebuild
    student_list = []
    previous_arrangement.values.each { |table_students| student_list.concat(table_students) }
    
    # Rotate the list
    student_list = student_list.rotate(rotation_offset)
    
    # Rebuild arrangement
    tables = {}
    students_per_table = seating_event.table_size
    total_tables = seating_event.total_tables
    
    student_list.each_with_index do |student, index|
      table_number = (index / students_per_table) + 1
      tables[table_number] ||= []
      tables[table_number] << student
    end
    
    tables
  end

  def generate_random_arrangement(students)
    generate_initial_balanced_arrangement(students.shuffle)
  end

  def valid_random_arrangement?(arrangement, previous_arrangements, day_config)
    # Check constraints like "no more than X consecutive days together"
    max_consecutive_days = day_config[:max_consecutive_days] || 2
    
    # For now, just check against immediate previous day
    return true if previous_arrangements.empty?
    
    previous_arrangement = previous_arrangements.values.last
    consecutive_pairs = count_consecutive_pairs(arrangement, previous_arrangement)
    
    # Allow some consecutive pairs but not too many
    total_pairs = count_total_pairs(arrangement)
    consecutive_ratio = consecutive_pairs.to_f / total_pairs
    
    consecutive_ratio < 0.3 # Allow up to 30% consecutive pairs
  end

  def count_consecutive_pairs(current_arrangement, previous_arrangement)
    current_pairs = get_all_pairs(current_arrangement)
    previous_pairs = get_all_pairs(previous_arrangement)
    
    (current_pairs & previous_pairs).size
  end

  def count_total_pairs(arrangement)
    get_all_pairs(arrangement).size
  end

  def get_all_pairs(arrangement)
    pairs = []
    arrangement.each do |table_number, students|
      students.combination(2).each do |student_a, student_b|
        pairs << [student_a.id, student_b.id].sort
      end
    end
    pairs
  end

  def apply_custom_rotation_rules(day_number, students, previous_arrangements, custom_rules)
    # Placeholder for custom rule application
    # This would parse and apply user-defined rotation rules
    generate_initial_balanced_arrangement(students)
  end

  def calculate_mixing_intensity(day_number)
    # Progressive increase in mixing intensity
    base_intensity = 0.3
    day_factor = (day_number - 1) * 0.2
    
    [base_intensity + day_factor, 1.0].min
  end

  def generate_attribute_grouped_arrangement(students)
    # Group students by similar attributes initially
    # This would use custom attributes or teams if available
    generate_initial_balanced_arrangement(students)
  end

  def apply_progressive_mixing(previous_arrangement, students, mixing_intensity)
    # Gradually increase randomness while maintaining some structure
    stability_factor = 1.0 - mixing_intensity
    
    # Keep some students in similar positions, move others
    stable_students = (students.count * stability_factor).to_i
    students_to_move = students.count - stable_students
    
    # Implement mixing logic here
    generate_initial_balanced_arrangement(students)
  end

  def generate_geographic_balanced_arrangement(students, geographic_attribute)
    # Balance tables by geographic diversity
    # This would use student attributes to ensure geographic mixing
    generate_initial_balanced_arrangement(students)
  end

  def rotate_with_geographic_constraints(previous_arrangement, students, geographic_attribute)
    # Rotate while maintaining geographic diversity requirements
    generate_initial_balanced_arrangement(students)
  end

  def calculate_total_interactions(arrangements)
    total = 0
    arrangements.each do |day, arrangement|
      arrangement.each do |table, students|
        total += students.combination(2).count
      end
    end
    total
  end

  def calculate_unique_interactions(arrangements)
    all_pairs = Set.new
    
    arrangements.each do |day, arrangement|
      arrangement.each do |table, students|
        students.combination(2).each do |student_a, student_b|
          pair_key = [student_a.id, student_b.id].sort.join('-')
          all_pairs.add(pair_key)
        end
      end
    end
    
    all_pairs.size
  end

  def analyze_preview_pattern(preview_arrangements, students, strategy)
    efficiency_metrics = calculate_rotation_efficiency(preview_arrangements, students)
    
    {
      success: true,
      strategy: strategy,
      days_previewed: preview_arrangements.keys.count,
      student_sample_size: students.count,
      preview_arrangements: preview_arrangements,
      efficiency_metrics: efficiency_metrics,
      pattern_analysis: {
        interaction_distribution: analyze_interaction_distribution(preview_arrangements),
        diversity_trend: calculate_diversity_trend(preview_arrangements),
        rotation_predictability: calculate_rotation_predictability(preview_arrangements)
      }
    }
  end

  def analyze_interaction_distribution(arrangements)
    interaction_counts = Hash.new(0)
    
    arrangements.each do |day, arrangement|
      arrangement.each do |table, students|
        students.combination(2).each do |student_a, student_b|
          key = [student_a.id, student_b.id].sort.join('-')
          interaction_counts[key] += 1
        end
      end
    end
    
    frequency_distribution = Hash.new(0)
    interaction_counts.values.each { |count| frequency_distribution[count] += 1 }
    
    {
      total_unique_pairs: interaction_counts.keys.count,
      frequency_distribution: frequency_distribution,
      most_frequent_interactions: interaction_counts.values.max,
      least_frequent_interactions: interaction_counts.values.min
    }
  end

  def calculate_diversity_trend(arrangements)
    # Calculate how diversity changes across days
    daily_diversity_scores = []
    
    arrangements.each do |day, arrangement|
      diversity_score = calculate_daily_diversity_score(arrangement)
      daily_diversity_scores << diversity_score
    end
    
    # Calculate trend (positive = increasing diversity, negative = decreasing)
    return 0 if daily_diversity_scores.length < 2
    
    first_half_avg = daily_diversity_scores[0...(daily_diversity_scores.length/2)].sum.to_f / (daily_diversity_scores.length/2)
    second_half_avg = daily_diversity_scores[(daily_diversity_scores.length/2)..-1].sum.to_f / (daily_diversity_scores.length - daily_diversity_scores.length/2)
    
    second_half_avg - first_half_avg
  end

  def calculate_daily_diversity_score(arrangement)
    # Placeholder diversity calculation
    # This would integrate with the DiversityCalculator
    arrangement.values.map(&:count).sum.to_f / arrangement.keys.count
  end

  def calculate_rotation_predictability(arrangements)
    # Measure how predictable the rotation pattern is
    # Lower scores = more random, higher scores = more predictable
    return 0 if arrangements.length < 3
    
    pattern_consistency = 0
    
    # Analyze position changes between consecutive days
    (2..arrangements.length).each do |day|
      current_positions = get_student_positions(arrangements[day])
      previous_positions = get_student_positions(arrangements[day - 1])
      
      consistency_score = calculate_position_consistency(current_positions, previous_positions)
      pattern_consistency += consistency_score
    end
    
    pattern_consistency / (arrangements.length - 1).to_f
  end

  def get_student_positions(arrangement)
    positions = {}
    arrangement.each do |table_number, students|
      students.each_with_index do |student, seat_index|
        positions[student.id] = { table: table_number, seat: seat_index }
      end
    end
    positions
  end

  def calculate_position_consistency(current_positions, previous_positions)
    total_moves = 0
    predictable_moves = 0
    
    current_positions.each do |student_id, current_pos|
      previous_pos = previous_positions[student_id]
      next unless previous_pos
      
      total_moves += 1
      
      # Simple heuristic for predictable movement
      table_change = (current_pos[:table] - previous_pos[:table]).abs
      if table_change <= 1 # Moved to adjacent table or stayed
        predictable_moves += 1
      end
    end
    
    return 0 if total_moves.zero?
    predictable_moves.to_f / total_moves
  end
end