# frozen_string_literal: true

class SeatingOptimizationService
  DEFAULT_MAX_RUNTIME = 30.seconds
  DEFAULT_STRATEGY = :simulated_annealing

  attr_reader :seating_event, :optimization_params, :results

  def initialize(seating_event, optimization_params = {})
    @seating_event = seating_event
    @optimization_params = optimization_params.with_indifferent_access
    @results = {}
  end

  def optimize(strategy: DEFAULT_STRATEGY, max_runtime: DEFAULT_MAX_RUNTIME)
    Rails.logger.info "Starting seating optimization for event #{seating_event.id} with #{strategy} strategy"
    
    start_time = Time.current
    # Load students without includes to avoid any weird Rails behavior
    students = seating_event.cohort.students.to_a
    
    # Verify students are persisted
    Rails.logger.info "Loaded #{students.count} students, all persisted: #{students.all?(&:persisted?)}"
    
    return failure_result("No students found") if students.empty?
    return failure_result("Insufficient students for optimization") if students.count < 2

    # Initialize optimization components
    calculator = DiversityCalculator.new
    constraint_evaluator = ConstraintEvaluator.new(seating_event)
    
    # Initialize decision logging
    decision_logger = DecisionLogService.new(seating_event)
    
    # Generate initial arrangement
    initial_arrangement = generate_initial_arrangement(students)
    # Deep copy the arrangement structure but keep the same Student object references
    current_arrangement = deep_copy_arrangement(initial_arrangement)
    best_arrangement = deep_copy_arrangement(initial_arrangement)
    
    # Calculate initial scores
    current_score = calculator.calculate_total_score(current_arrangement, seating_event)
    best_score = current_score
    
    # Start decision logging
    decision_logger.start_optimization_session(
      strategy: strategy,
      initial_arrangement: initial_arrangement,
      parameters: optimization_params
    )
    
    # Initial constraint evaluation
    initial_violations = constraint_evaluator.evaluate(initial_arrangement)
    decision_logger.log_constraint_evaluation(initial_arrangement, initial_violations)
    
    # Initial diversity analysis
    initial_metrics = calculator.calculate_detailed_metrics(initial_arrangement, seating_event)
    decision_logger.log_diversity_analysis(initial_arrangement, initial_metrics)
    
    # Select and run optimization strategy
    optimizer = create_optimizer(strategy, calculator, constraint_evaluator)
    
    iterations = 0
    improvements = 0
    
    previous_metrics = initial_metrics
    
    while Time.current - start_time < max_runtime
      # Generate new arrangement using strategy
      new_arrangement = optimizer.generate_neighbor(current_arrangement)
      new_score = calculator.calculate_total_score(new_arrangement, seating_event)
      
      # Check constraints
      constraint_violations = constraint_evaluator.evaluate(new_arrangement)
      constraint_penalty = calculate_constraint_penalty(constraint_violations)
      adjusted_score = new_score - constraint_penalty
      
      # Decide whether to accept the new arrangement
      accepted = optimizer.should_accept?(current_score, adjusted_score, iterations)
      
      # Log the iteration
      decision_logger.log_iteration(
        iteration: iterations,
        current_arrangement: current_arrangement,
        current_score: current_score,
        new_arrangement: new_arrangement,
        new_score: adjusted_score,
        accepted: accepted,
        reason: determine_acceptance_reason(current_score, adjusted_score, accepted)
      )
      
      if accepted
        current_arrangement = new_arrangement
        current_score = adjusted_score
        
        # Log constraint violations if any
        if constraint_violations.any?
          decision_logger.log_constraint_evaluation(new_arrangement, constraint_violations)
        end
        
        # Log diversity changes every few iterations
        if iterations % 10 == 0
          current_metrics = calculator.calculate_detailed_metrics(new_arrangement, seating_event)
          decision_logger.log_diversity_analysis(new_arrangement, current_metrics, previous_metrics)
          previous_metrics = current_metrics
        end
        
        if adjusted_score > best_score
          best_arrangement = new_arrangement.dup
          best_score = adjusted_score
          improvements += 1
          Rails.logger.debug "New best score: #{best_score} at iteration #{iterations}"
          
          # Log significant improvements
          decision_logger.log_improvement(iterations, current_score - (adjusted_score - current_score), adjusted_score, new_arrangement)
        end
      end
      
      iterations += 1
      optimizer.update_parameters(iterations) if optimizer.respond_to?(:update_parameters)
      
      # Early termination if we've reached a very good solution
      if best_score > 0.95 && constraint_violations.empty?
        decision_logger.log_decision("early_termination", { 
          reason: "excellent_score_achieved", 
          final_score: best_score,
          iteration: iterations 
        })
        break
      end
    end
    
    runtime = Time.current - start_time
    
    # Create final results
    final_metrics = calculator.calculate_detailed_metrics(best_arrangement, seating_event)
    final_violations = constraint_evaluator.evaluate(best_arrangement)
    
    # Finalize decision logging
    decision_logger.finalize_optimization(
      final_arrangement: best_arrangement,
      final_score: best_score,
      final_metrics: final_metrics,
      total_iterations: iterations,
      runtime: runtime
    )
    
    @results = {
      success: true,
      arrangement: best_arrangement,
      score: best_score,
      diversity_metrics: final_metrics,
      constraint_violations: final_violations,
      decision_log: decision_logger.get_log_summary,
      optimization_stats: {
        strategy: strategy,
        iterations: iterations,
        improvements: improvements,
        runtime: runtime.round(2),
        initial_score: calculator.calculate_total_score(initial_arrangement, seating_event),
        final_score: best_score,
        improvement: ((best_score - calculator.calculate_total_score(initial_arrangement, seating_event)) * 100).round(2)
      }
    }
    
    Rails.logger.info "Optimization completed: #{iterations} iterations, #{improvements} improvements, " \
                      "final score: #{best_score.round(3)} in #{runtime.round(2)}s"
    
    @results
  end

  def save_arrangement(arrangement_data, created_by)
    # Keep the original arrangement with Student objects for table assignments
    original_arrangement = arrangement_data[:arrangement]
    
    # Convert arrangement to store student IDs instead of objects for JSONB storage
    arrangement_for_storage = {}
    original_arrangement.each do |table_number, students|
      arrangement_for_storage[table_number] = students.map do |student|
        if student.is_a?(Student)
          # Store just essential data for display, not full object
          {
            'id' => student.id,
            'name' => student.name,
            'organization' => student.organization,
            'inferences' => student.inferences
          }
        else
          student # Already a hash
        end
      end
    end
    
    seating_arrangement = seating_event.seating_arrangements.build(
      arrangement_data: arrangement_for_storage,
      optimization_scores: arrangement_data[:optimization_stats],
      diversity_metrics: arrangement_data[:diversity_metrics],
      decision_log_data: arrangement_data[:decision_log] || {},
      created_by: created_by
    )
    
    if seating_arrangement.save
      # Pass the ORIGINAL arrangement with Student objects, not the converted one
      create_table_assignments(seating_arrangement, original_arrangement)
      seating_arrangement
    else
      nil
    end
  end

  def compare_arrangements(arrangements)
    calculator = DiversityCalculator.new
    
    arrangements.map do |arrangement|
      score = calculator.calculate_total_score(arrangement[:data], seating_event)
      metrics = calculator.calculate_detailed_metrics(arrangement[:data], seating_event)
      
      arrangement.merge(
        score: score,
        detailed_metrics: metrics
      )
    end.sort_by { |a| -a[:score] }
  end

  private
  
  def deep_copy_arrangement(arrangement)
    # Create a new hash with new arrays, but keep the same Student object references
    new_arrangement = {}
    arrangement.each do |table_number, students_at_table|
      # Create a new array with the same Student objects (not duplicates)
      new_arrangement[table_number] = students_at_table.dup
    end
    new_arrangement
  end

  def generate_initial_arrangement(students)
    # Simple round-robin assignment to ensure even distribution
    tables = {}
    students_per_table = seating_event.table_size
    total_tables = seating_event.total_tables
    max_capacity = students_per_table * total_tables
    
    # Only seat as many students as we have seats for
    students_to_seat = students.first(max_capacity)
    
    # Log warning if there are more students than seats
    if students.count > max_capacity
      Rails.logger.warn "Warning: #{students.count} students but only #{max_capacity} seats available. #{students.count - max_capacity} students will not be seated."
    end
    
    students_to_seat.each_with_index do |student, index|
      table_number = (index % total_tables) + 1
      tables[table_number] ||= []
      
      if tables[table_number].size < students_per_table
        tables[table_number] << student
      else
        # Find a table with space (should not happen with proper sizing)
        available_table = tables.find { |_, students_list| students_list.size < students_per_table }
        if available_table
          available_table[1] << student
        else
          Rails.logger.error "No available seats for student #{student.id}"
        end
      end
    end
    
    # Ensure all tables exist even if empty
    (1..total_tables).each do |table_num|
      tables[table_num] ||= []
    end
    
    tables
  end

  def create_optimizer(strategy, calculator, constraint_evaluator)
    case strategy.to_sym
    when :random_swap
      Optimization::RandomSwapOptimizer.new(calculator, constraint_evaluator, optimization_params)
    when :simulated_annealing
      Optimization::SimulatedAnnealingOptimizer.new(calculator, constraint_evaluator, optimization_params)
    when :genetic_algorithm
      Optimization::GeneticAlgorithmOptimizer.new(calculator, constraint_evaluator, optimization_params)
    else
      raise ArgumentError, "Unknown optimization strategy: #{strategy}"
    end
  end

  def calculate_constraint_penalty(violations)
    penalty = 0
    violations.each do |violation|
      case violation[:severity]
      when :hard
        penalty += 10.0  # Heavy penalty for hard constraint violations
      when :soft
        penalty += 1.0   # Light penalty for soft constraint violations
      end
    end
    penalty
  end

  def create_table_assignments(seating_arrangement, arrangement_data)
    cohort_id = seating_arrangement.seating_event.cohort_id
    
    arrangement_data.each do |table_number, students|
      students.each_with_index do |student_data, seat_position|
        # Always look up the student fresh from the database to avoid unpersisted duplicates
        student = if student_data.is_a?(Student)
          # Look up by name since the object might be a duplicate
          Student.find_by!(name: student_data.name, cohort_id: cohort_id)
        elsif student_data.is_a?(Hash) && student_data['id']
          Student.find(student_data['id'])
        elsif student_data.is_a?(Hash)
          Student.find_by!(
            name: student_data['name'] || student_data[:name],
            cohort_id: cohort_id
          )
        else
          raise "Invalid student data: #{student_data.inspect}"
        end
        
        # Create TableAssignment with the fresh student ID
        TableAssignment.create!(
          seating_arrangement_id: seating_arrangement.id,
          student_id: student.id,
          table_number: table_number,
          seat_position: seat_position + 1,
          locked: false
        )
      end
    end
  rescue => e
    Rails.logger.error "Error creating table assignments: #{e.message}"
    Rails.logger.error "Arrangement data sample: #{arrangement_data.first.inspect}"
    raise
  end

  def failure_result(message)
    {
      success: false,
      error: message,
      arrangement: {},
      score: 0,
      diversity_metrics: {},
      constraint_violations: [],
      optimization_stats: {}
    }
  end
  
  def determine_acceptance_reason(current_score, new_score, accepted)
    return 'rejected' unless accepted
    
    if new_score > current_score
      'improvement'
    elsif new_score == current_score
      'equal_score'
    else
      'exploration' # Accepted despite lower score (e.g., simulated annealing)
    end
  end
end