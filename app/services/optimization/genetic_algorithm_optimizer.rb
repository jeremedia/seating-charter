# frozen_string_literal: true

module Optimization
  class GeneticAlgorithmOptimizer < BaseOptimizer
    DEFAULT_POPULATION_SIZE = 20
    DEFAULT_MUTATION_RATE = 0.1
    DEFAULT_CROSSOVER_RATE = 0.8
    DEFAULT_ELITE_SIZE = 4

    def initialize(calculator, constraint_evaluator, params = {})
      super
      @population_size = params[:population_size] || DEFAULT_POPULATION_SIZE
      @mutation_rate = params[:mutation_rate] || DEFAULT_MUTATION_RATE
      @crossover_rate = params[:crossover_rate] || DEFAULT_CROSSOVER_RATE
      @elite_size = params[:elite_size] || DEFAULT_ELITE_SIZE
      
      @population = []
      @generation = 0
      @best_fitness_history = []
      @diversity_history = []
    end

    def generate_neighbor(arrangement)
      # For genetic algorithm, we work with populations, not individual neighbors
      # This method is called to get the next generation's best individual
      
      if @population.empty?
        initialize_population(arrangement)
      end
      
      evolve_population
      @generation += 1
      
      # Return the best individual from current population
      best_individual = @population.max_by { |individual| individual[:fitness] }
      best_individual[:arrangement]
    end

    def should_accept?(current_score, new_score, iteration)
      # In genetic algorithms, we always "accept" the new population
      # The selection process handles fitness-based decisions
      true
    end

    def update_parameters(iteration)
      # Optionally adjust mutation rate over time
      if iteration % 50 == 0
        # Slightly decrease mutation rate as we progress (focus more on exploitation)
        @mutation_rate = [@mutation_rate * 0.98, 0.05].max
      end
      
      if iteration % 20 == 0
        Rails.logger.debug "Genetic Algorithm - Generation: #{@generation}, " \
                          "Best Fitness: #{@best_fitness_history.last&.round(4)}, " \
                          "Population Diversity: #{@diversity_history.last&.round(4)}"
      end
    end

    def population_info
      return {} if @population.empty?
      
      fitnesses = @population.map { |individual| individual[:fitness] }
      
      {
        generation: @generation,
        population_size: @population.size,
        best_fitness: fitnesses.max,
        average_fitness: fitnesses.sum / fitnesses.size,
        worst_fitness: fitnesses.min,
        fitness_std_dev: calculate_standard_deviation(fitnesses),
        mutation_rate: @mutation_rate,
        best_fitness_history: @best_fitness_history.last(10),
        diversity_history: @diversity_history.last(10)
      }
    end

    private

    def initialize_population(base_arrangement)
      @population = []
      
      # Add the base arrangement as one individual
      fitness = calculate_fitness(base_arrangement)
      @population << { arrangement: base_arrangement.deep_dup, fitness: fitness }
      
      # Generate additional random individuals
      (@population_size - 1).times do
        individual_arrangement = generate_random_individual(base_arrangement)
        individual_fitness = calculate_fitness(individual_arrangement)
        @population << { arrangement: individual_arrangement, fitness: individual_fitness }
      end
      
      record_population_stats
    end

    def evolve_population
      # Selection: choose parents based on fitness
      parents = select_parents
      
      # Create new population with elites
      new_population = select_elites
      
      # Generate offspring through crossover and mutation
      while new_population.size < @population_size
        parent1, parent2 = parents.sample(2)
        
        if rand < @crossover_rate
          child = crossover(parent1[:arrangement], parent2[:arrangement])
        else
          child = parent1[:arrangement].deep_dup
        end
        
        if rand < @mutation_rate
          child = mutate(child)
        end
        
        fitness = calculate_fitness(child)
        new_population << { arrangement: child, fitness: fitness }
      end
      
      @population = new_population
      record_population_stats
    end

    def select_parents
      # Tournament selection
      tournament_size = 3
      parents = []
      
      (@population_size * 2).times do # Generate more parents than needed
        tournament = @population.sample(tournament_size)
        winner = tournament.max_by { |individual| individual[:fitness] }
        parents << winner
      end
      
      parents
    end

    def select_elites
      # Keep the best individuals
      @population.sort_by { |individual| -individual[:fitness] }.first(@elite_size)
    end

    def crossover(parent1, parent2)
      # Order-based crossover for seating arrangements
      child = {}
      
      # Get all students from both parents
      all_students = parent1.values.flatten
      used_students = Set.new
      
      # Randomly decide which tables to inherit from which parent
      parent1.keys.each do |table_num|
        if rand < 0.5
          # Take from parent1
          source_table = parent1[table_num].reject { |student| used_students.include?(student.id) }
        else
          # Take from parent2
          source_table = parent2[table_num].reject { |student| used_students.include?(student.id) }
        end
        
        child[table_num] = source_table
        source_table.each { |student| used_students.add(student.id) }
      end
      
      # Place remaining students randomly
      remaining_students = all_students.reject { |student| used_students.include?(student.id) }
      remaining_students.each do |student|
        # Find a table with space
        available_tables = child.keys.select do |table_num|
          child[table_num].size < @constraint_evaluator.seating_event.table_size
        end
        
        if available_tables.any?
          target_table = available_tables.sample
          child[target_table] << student
        else
          # If no tables have space, add to smallest table (constraint violation)
          smallest_table = child.min_by { |_, students| students.size }[0]
          child[smallest_table] << student
        end
      end
      
      child
    end

    def mutate(arrangement)
      # Various mutation operations
      mutation_type = rand(4)
      
      case mutation_type
      when 0
        # Swap two random students
        mutate_swap(arrangement)
      when 1
        # Move a student to a different table
        mutate_move(arrangement)
      when 2
        # Shuffle a random table
        mutate_shuffle_table(arrangement)
      when 3
        # Redistribute students in a table
        mutate_redistribute(arrangement)
      end
    end

    def mutate_swap(arrangement)
      new_arrangement = arrangement.deep_dup
      table_numbers = get_random_table_numbers(new_arrangement, 2)
      
      if table_numbers.size >= 2
        return swap_students_between_tables(new_arrangement, table_numbers[0], table_numbers[1])
      end
      
      new_arrangement
    end

    def mutate_move(arrangement)
      new_arrangement = arrangement.deep_dup
      eligible_tables = new_arrangement.keys.select { |num| new_arrangement[num].size > 1 }
      
      return new_arrangement if eligible_tables.empty?
      
      source_table = eligible_tables.sample
      target_tables = new_arrangement.keys.select do |num|
        num != source_table && new_arrangement[num].size < @constraint_evaluator.seating_event.table_size
      end
      
      return new_arrangement if target_tables.empty?
      
      target_table = target_tables.sample
      move_student_to_different_table(new_arrangement, source_table, target_table)
    end

    def mutate_shuffle_table(arrangement)
      new_arrangement = arrangement.deep_dup
      eligible_tables = new_arrangement.keys.select { |num| new_arrangement[num].size > 2 }
      
      return new_arrangement if eligible_tables.empty?
      
      table_to_shuffle = eligible_tables.sample
      shuffle_table(new_arrangement, table_to_shuffle)
    end

    def mutate_redistribute(arrangement)
      new_arrangement = arrangement.deep_dup
      eligible_tables = new_arrangement.keys.select { |num| new_arrangement[num].size > 3 }
      
      return new_arrangement if eligible_tables.empty?
      
      table_to_redistribute = eligible_tables.sample
      students = new_arrangement[table_to_redistribute]
      
      # Remove some students and redistribute them
      students_to_move = students.sample([students.size / 3, 1].max)
      students_to_move.each { |student| students.delete(student) }
      
      # Place them in other tables
      students_to_move.each do |student|
        available_tables = new_arrangement.keys.select do |num|
          num != table_to_redistribute && 
          new_arrangement[num].size < @constraint_evaluator.seating_event.table_size
        end
        
        if available_tables.any?
          target_table = available_tables.sample
          new_arrangement[target_table] << student
        else
          # Put back if no space
          new_arrangement[table_to_redistribute] << student
        end
      end
      
      new_arrangement
    end

    def generate_random_individual(base_arrangement)
      # Create a random arrangement by shuffling all students
      all_students = base_arrangement.values.flatten.shuffle
      table_numbers = base_arrangement.keys.sort
      table_size = @constraint_evaluator.seating_event.table_size
      
      new_arrangement = {}
      table_numbers.each { |num| new_arrangement[num] = [] }
      
      # Distribute students randomly but try to respect table size constraints
      all_students.each_with_index do |student, index|
        table_num = table_numbers[index % table_numbers.size]
        
        # If the selected table is full, find the next available table
        if new_arrangement[table_num].size >= table_size
          available_table = table_numbers.find { |num| new_arrangement[num].size < table_size }
          table_num = available_table || table_num # Use original if all full
        end
        
        new_arrangement[table_num] << student
      end
      
      new_arrangement
    end

    def calculate_fitness(arrangement)
      # Fitness is the same as the diversity score minus constraint penalties
      diversity_score = @calculator.calculate_total_score(arrangement, @constraint_evaluator.seating_event)
      constraint_violations = @constraint_evaluator.evaluate(arrangement)
      
      penalty = constraint_violations.sum do |violation|
        case violation[:severity]
        when :hard
          0.5  # Heavy penalty for hard constraints
        when :soft
          0.1  # Light penalty for soft constraints
        else
          0.0
        end
      end
      
      [diversity_score - penalty, 0.0].max
    end

    def record_population_stats
      fitnesses = @population.map { |individual| individual[:fitness] }
      @best_fitness_history << fitnesses.max
      
      # Calculate population diversity (how different the individuals are)
      diversity = calculate_population_diversity
      @diversity_history << diversity
    end

    def calculate_population_diversity
      return 0.0 if @population.size < 2
      
      # Calculate pairwise differences between arrangements
      total_differences = 0
      comparison_count = 0
      
      @population.combination(2) do |ind1, ind2|
        difference = calculate_arrangement_difference(ind1[:arrangement], ind2[:arrangement])
        total_differences += difference
        comparison_count += 1
      end
      
      comparison_count > 0 ? total_differences / comparison_count : 0.0
    end

    def calculate_arrangement_difference(arr1, arr2)
      # Simple measure: count how many students are in different tables
      total_students = arr1.values.flatten.size
      different_positions = 0
      
      arr1.each do |table_num, students|
        arr2_students = arr2[table_num] || []
        students.each do |student|
          unless arr2_students.include?(student)
            different_positions += 1
          end
        end
      end
      
      total_students > 0 ? different_positions.to_f / total_students : 0.0
    end

    def calculate_standard_deviation(values)
      return 0.0 if values.size < 2
      
      mean = values.sum / values.size.to_f
      variance = values.sum { |v| (v - mean) ** 2 } / values.size.to_f
      Math.sqrt(variance)
    end
  end
end