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
    students = seating_event.cohort.students.includes(:table_assignments)
    
    return failure_result("No students found") if students.empty?
    return failure_result("Insufficient students for optimization") if students.count < 2

    # Initialize optimization components
    calculator = DiversityCalculator.new
    constraint_evaluator = ConstraintEvaluator.new(seating_event)
    
    # Initialize decision logging
    decision_logger = DecisionLogService.new(seating_event)
    
    # Generate initial arrangement
    initial_arrangement = generate_initial_arrangement(students)
    current_arrangement = initial_arrangement.dup
    best_arrangement = initial_arrangement.dup
    
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
    seating_arrangement = seating_event.seating_arrangements.build(
      arrangement_data: arrangement_data[:arrangement],
      optimization_scores: arrangement_data[:optimization_stats],
      diversity_metrics: arrangement_data[:diversity_metrics],
      decision_log_data: arrangement_data[:decision_log] || {},
      created_by: created_by
    )
    
    if seating_arrangement.save
      create_table_assignments(seating_arrangement, arrangement_data[:arrangement])
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

  def generate_initial_arrangement(students)
    # Simple round-robin assignment to ensure even distribution
    tables = {}
    students_per_table = seating_event.table_size
    total_tables = seating_event.total_tables
    
    students.each_with_index do |student, index|
      table_number = (index % total_tables) + 1
      tables[table_number] ||= []
      
      if tables[table_number].size < students_per_table
        tables[table_number] << student
      else
        # Handle overflow by finding the table with the least students
        least_filled_table = tables.min_by { |_, students_list| students_list.size }
        least_filled_table[1] << student
      end
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