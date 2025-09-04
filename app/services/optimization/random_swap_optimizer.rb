# frozen_string_literal: true

module Optimization
  class RandomSwapOptimizer < BaseOptimizer
    DEFAULT_SWAP_PROBABILITY = 0.8
    DEFAULT_MOVE_PROBABILITY = 0.15
    DEFAULT_SHUFFLE_PROBABILITY = 0.05

    def initialize(calculator, constraint_evaluator, params = {})
      super
      @swap_probability = params[:swap_probability] || DEFAULT_SWAP_PROBABILITY
      @move_probability = params[:move_probability] || DEFAULT_MOVE_PROBABILITY
      @shuffle_probability = params[:shuffle_probability] || DEFAULT_SHUFFLE_PROBABILITY
    end

    def generate_neighbor(arrangement)
      operation = choose_operation
      
      case operation
      when :swap
        perform_student_swap(arrangement)
      when :move
        perform_student_move(arrangement)
      when :shuffle
        perform_table_shuffle(arrangement)
      else
        arrangement.deep_dup
      end
    end

    def should_accept?(current_score, new_score, iteration)
      # Random swap optimizer: only accept improvements
      new_score > current_score
    end

    private

    def choose_operation
      rand_val = rand
      
      if rand_val < @swap_probability
        :swap
      elsif rand_val < @swap_probability + @move_probability
        :move
      else
        :shuffle
      end
    end

    def perform_student_swap(arrangement)
      table_numbers = get_random_table_numbers(arrangement, 2)
      return arrangement.deep_dup if table_numbers.size < 2
      
      swap_students_between_tables(arrangement, table_numbers[0], table_numbers[1])
    end

    def perform_student_move(arrangement)
      all_tables = arrangement.keys.select { |num| arrangement[num].size > 0 }
      return arrangement.deep_dup if all_tables.size < 2
      
      # Find tables that can give/receive students
      source_tables = all_tables.select { |num| arrangement[num].size > 1 } # Can afford to lose a student
      target_tables = all_tables.select { |num| arrangement[num].size < @constraint_evaluator.seating_event.table_size }
      
      return arrangement.deep_dup if source_tables.empty? || target_tables.empty?
      
      source_table = source_tables.sample
      target_table = (target_tables - [source_table]).sample || target_tables.sample
      
      move_student_to_different_table(arrangement, source_table, target_table)
    end

    def perform_table_shuffle(arrangement)
      # Randomly select a table to shuffle
      eligible_tables = arrangement.keys.select { |num| arrangement[num].size > 2 }
      return arrangement.deep_dup if eligible_tables.empty?
      
      table_to_shuffle = eligible_tables.sample
      shuffle_table(arrangement, table_to_shuffle)
    end
  end
end