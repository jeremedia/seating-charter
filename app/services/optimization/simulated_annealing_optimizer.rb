# frozen_string_literal: true

module Optimization
  class SimulatedAnnealingOptimizer < BaseOptimizer
    DEFAULT_INITIAL_TEMPERATURE = 100.0
    DEFAULT_COOLING_RATE = 0.95
    DEFAULT_MIN_TEMPERATURE = 0.01

    def initialize(calculator, constraint_evaluator, params = {})
      super
      @initial_temperature = params[:initial_temperature] || DEFAULT_INITIAL_TEMPERATURE
      @cooling_rate = params[:cooling_rate] || DEFAULT_COOLING_RATE
      @min_temperature = params[:min_temperature] || DEFAULT_MIN_TEMPERATURE
      @current_temperature = @initial_temperature
      
      # Track temperature history for debugging
      @temperature_history = []
    end

    def generate_neighbor(arrangement)
      # Use similar neighbor generation as random swap but with more variety
      operation_weights = calculate_operation_weights
      operation = choose_weighted_operation(operation_weights)
      
      case operation
      when :small_swap
        perform_small_swap(arrangement)
      when :large_swap
        perform_large_swap(arrangement)
      when :student_move
        perform_strategic_move(arrangement)
      when :table_reorganize
        perform_table_reorganization(arrangement)
      else
        arrangement.deep_dup
      end
    end

    def should_accept?(current_score, new_score, iteration)
      # Always accept improvements
      return true if new_score > current_score
      
      # Accept worse solutions with probability based on temperature
      score_diff = current_score - new_score
      return false if score_diff <= 0 || @current_temperature <= 0
      
      acceptance_probability = Math.exp(-score_diff / @current_temperature)
      rand < acceptance_probability
    end

    def update_parameters(iteration)
      # Cool down the temperature
      @current_temperature = [@current_temperature * @cooling_rate, @min_temperature].max
      @temperature_history << @current_temperature
      
      Rails.logger.debug "Simulated Annealing - Iteration: #{iteration}, Temperature: #{@current_temperature.round(4)}" if iteration % 100 == 0
    end

    def temperature_info
      {
        current: @current_temperature,
        initial: @initial_temperature,
        cooling_rate: @cooling_rate,
        min_temperature: @min_temperature,
        history: @temperature_history.last(10) # Last 10 temperatures
      }
    end

    private

    def calculate_operation_weights
      # Adjust operation weights based on temperature
      # Higher temperature = more exploration (larger moves)
      # Lower temperature = more exploitation (smaller moves)
      temp_factor = @current_temperature / @initial_temperature
      
      {
        small_swap: 0.4 + (0.2 * (1 - temp_factor)),      # More likely when cooler
        large_swap: 0.2 + (0.3 * temp_factor),            # More likely when hotter
        student_move: 0.3,                                 # Constant
        table_reorganize: 0.1 + (0.2 * temp_factor)       # More likely when hotter
      }
    end

    def choose_weighted_operation(weights)
      rand_val = rand
      cumulative = 0
      
      weights.each do |operation, weight|
        cumulative += weight
        return operation if rand_val <= cumulative
      end
      
      :small_swap # Fallback
    end

    def perform_small_swap(arrangement)
      # Swap students within the same table or between adjacent tables
      table_numbers = get_random_table_numbers(arrangement, 2)
      return arrangement.deep_dup if table_numbers.size < 2
      
      # Prefer tables that are close in number (adjacent)
      if (table_numbers[1] - table_numbers[0]).abs > 2 && rand < 0.7
        # Try to find closer tables
        all_tables = arrangement.keys.select { |num| arrangement[num].size > 0 }
        table1 = all_tables.sample
        close_tables = all_tables.select { |t| (t - table1).abs <= 2 && t != table1 }
        table2 = close_tables.empty? ? all_tables.sample : close_tables.sample
        table_numbers = [table1, table2]
      end
      
      swap_students_between_tables(arrangement, table_numbers[0], table_numbers[1])
    end

    def perform_large_swap(arrangement)
      # Swap multiple students or students from distant tables
      table_numbers = get_random_table_numbers(arrangement, 2)
      return arrangement.deep_dup if table_numbers.size < 2
      
      new_arrangement = arrangement.deep_dup
      
      # Perform multiple swaps
      swap_count = rand(2..3)
      swap_count.times do
        if new_arrangement[table_numbers[0]].any? && new_arrangement[table_numbers[1]].any?
          new_arrangement = swap_students_between_tables(
            new_arrangement, 
            table_numbers[0], 
            table_numbers[1]
          )
        end
      end
      
      new_arrangement
    end

    def perform_strategic_move(arrangement)
      # Move students to improve diversity scores
      all_tables = arrangement.keys.select { |num| arrangement[num].size > 0 }
      return arrangement.deep_dup if all_tables.size < 2
      
      # Find the table with the lowest diversity score
      table_scores = {}
      all_tables.each do |table_num|
        table_arrangement = { table_num => arrangement[table_num] }
        table_scores[table_num] = @calculator.calculate_total_score(table_arrangement, @constraint_evaluator.seating_event)
      end
      
      # Move from lowest scoring table to highest scoring table
      source_table = table_scores.min_by { |_, score| score }[0]
      target_table = table_scores.max_by { |_, score| score }[0]
      
      # Don't move if it would violate constraints
      return arrangement.deep_dup if arrangement[source_table].size <= 1
      return arrangement.deep_dup if arrangement[target_table].size >= @constraint_evaluator.seating_event.table_size
      
      move_student_to_different_table(arrangement, source_table, target_table)
    end

    def perform_table_reorganization(arrangement)
      # Reorganize an entire table by redistributing its students
      eligible_tables = arrangement.keys.select { |num| arrangement[num].size > 2 }
      return arrangement.deep_dup if eligible_tables.empty?
      
      table_to_reorganize = eligible_tables.sample
      students_to_redistribute = arrangement[table_to_reorganize].dup
      
      new_arrangement = arrangement.deep_dup
      new_arrangement[table_to_reorganize] = []
      
      # Redistribute students to other tables
      other_tables = arrangement.keys - [table_to_reorganize]
      
      students_to_redistribute.each do |student|
        # Find the best table for this student
        best_table = find_best_table_for_student(new_arrangement, student, other_tables)
        if best_table && new_arrangement[best_table].size < @constraint_evaluator.seating_event.table_size
          new_arrangement[best_table] << student
        else
          # Fallback: put back in original table
          new_arrangement[table_to_reorganize] << student
        end
      end
      
      new_arrangement
    end

    def find_best_table_for_student(arrangement, student, candidate_tables)
      best_table = nil
      best_score = -1
      
      candidate_tables.each do |table_num|
        next if arrangement[table_num].size >= @constraint_evaluator.seating_event.table_size
        
        # Try adding the student to this table and calculate score
        test_arrangement = arrangement.deep_dup
        test_arrangement[table_num] << student
        
        table_score = @calculator.calculate_total_score(
          { table_num => test_arrangement[table_num] }, 
          @constraint_evaluator.seating_event
        )
        
        if table_score > best_score
          best_score = table_score
          best_table = table_num
        end
      end
      
      best_table
    end
  end
end