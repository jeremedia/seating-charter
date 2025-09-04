# frozen_string_literal: true

module Optimization
  class BaseOptimizer
    attr_reader :calculator, :constraint_evaluator, :params

    def initialize(calculator, constraint_evaluator, params = {})
      @calculator = calculator
      @constraint_evaluator = constraint_evaluator
      @params = params.with_indifferent_access
    end

    def generate_neighbor(arrangement)
      raise NotImplementedError, "Subclasses must implement generate_neighbor"
    end

    def should_accept?(current_score, new_score, iteration)
      raise NotImplementedError, "Subclasses must implement should_accept?"
    end

    protected

    def swap_students_between_tables(arrangement, table1_num, table2_num, student1_idx = nil, student2_idx = nil)
      # Create a deep copy of the arrangement
      new_arrangement = arrangement.deep_dup
      
      table1 = new_arrangement[table1_num]
      table2 = new_arrangement[table2_num]
      
      return new_arrangement if table1.empty? || table2.empty?
      
      # Select random students if indices not provided
      student1_idx ||= rand(table1.size)
      student2_idx ||= rand(table2.size)
      
      # Perform the swap
      student1 = table1[student1_idx]
      student2 = table2[student2_idx]
      
      table1[student1_idx] = student2
      table2[student2_idx] = student1
      
      new_arrangement
    end

    def move_student_to_different_table(arrangement, source_table_num, target_table_num, student_idx = nil)
      new_arrangement = arrangement.deep_dup
      
      source_table = new_arrangement[source_table_num]
      target_table = new_arrangement[target_table_num]
      
      return new_arrangement if source_table.empty?
      
      student_idx ||= rand(source_table.size)
      student = source_table.delete_at(student_idx)
      target_table << student
      
      new_arrangement
    end

    def shuffle_table(arrangement, table_num)
      new_arrangement = arrangement.deep_dup
      new_arrangement[table_num] = new_arrangement[table_num].shuffle
      new_arrangement
    end

    def get_random_table_numbers(arrangement, count = 2)
      table_numbers = arrangement.keys.select { |num| arrangement[num].size > 0 }
      return [] if table_numbers.size < count
      
      table_numbers.sample(count)
    end

    def calculate_neighbor_with_constraint_penalty(arrangement)
      diversity_score = @calculator.calculate_total_score(arrangement, @constraint_evaluator.seating_event)
      constraint_violations = @constraint_evaluator.evaluate(arrangement)
      
      penalty = constraint_violations.sum do |violation|
        case violation[:severity]
        when :hard
          10.0
        when :soft
          1.0
        else
          0.0
        end
      end
      
      diversity_score - (penalty * 0.1) # Scale penalty appropriately
    end
  end
end