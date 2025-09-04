# frozen_string_literal: true

class ConstraintEvaluator
  SEVERITY_LEVELS = %i[hard soft].freeze
  
  attr_reader :seating_event, :constraints

  def initialize(seating_event)
    @seating_event = seating_event
    @constraints = load_constraints
  end

  def evaluate(arrangement)
    violations = []
    
    @constraints.each do |constraint|
      constraint_violations = evaluate_constraint(constraint, arrangement)
      violations.concat(constraint_violations) if constraint_violations.any?
    end
    
    violations
  end

  def has_hard_violations?(arrangement)
    violations = evaluate(arrangement)
    violations.any? { |v| v[:severity] == :hard }
  end

  def calculate_constraint_score(arrangement)
    violations = evaluate(arrangement)
    total_penalty = violations.sum do |violation|
      case violation[:severity]
      when :hard
        10.0 # Heavy penalty for hard constraints
      when :soft
        1.0  # Light penalty for soft constraints
      else
        0.0
      end
    end
    
    # Convert penalty to score (0 to 1, where 1 is no violations)
    max_possible_penalty = calculate_max_possible_penalty(arrangement)
    return 1.0 if max_possible_penalty.zero?
    
    score = [1.0 - (total_penalty / max_possible_penalty), 0.0].max
    score
  end

  private

  def load_constraints
    constraints = []
    
    # Load constraints from seating instructions
    seating_event.seating_instructions.where(applied: true).each do |instruction|
      if instruction.parsed_constraints.present?
        constraints.concat(parse_seating_constraints(instruction))
      end
    end
    
    # Add default constraints
    constraints.concat(default_constraints)
    
    constraints
  end

  def parse_seating_constraints(instruction)
    constraints = []
    parsed = instruction.parsed_constraints
    
    # Handle different types of parsed constraints
    case parsed
    when Hash
      constraints << create_constraint_from_hash(parsed, instruction)
    when Array
      parsed.each do |constraint_data|
        constraints << create_constraint_from_hash(constraint_data, instruction)
      end
    end
    
    constraints.compact
  end

  def create_constraint_from_hash(constraint_data, instruction)
    {
      id: "instruction_#{instruction.id}_#{SecureRandom.hex(4)}",
      type: constraint_data['type'] || 'custom',
      description: constraint_data['description'] || instruction.instruction_text,
      severity: (constraint_data['severity'] || 'soft').to_sym,
      parameters: constraint_data['parameters'] || {},
      evaluator: method(:evaluate_custom_constraint),
      source: 'seating_instruction',
      source_id: instruction.id
    }
  end

  def default_constraints
    [
      {
        id: 'table_size_limit',
        type: 'table_size',
        description: 'Tables must not exceed maximum size',
        severity: :hard,
        parameters: { max_size: seating_event.table_size },
        evaluator: method(:evaluate_table_size_constraint),
        source: 'system'
      },
      {
        id: 'minimum_table_size',
        type: 'table_size',
        description: 'Tables should have at least 2 students',
        severity: :soft,
        parameters: { min_size: 2 },
        evaluator: method(:evaluate_minimum_table_size_constraint),
        source: 'system'
      },
      {
        id: 'balanced_tables',
        type: 'balance',
        description: 'Tables should be reasonably balanced in size',
        severity: :soft,
        parameters: { max_difference: 2 },
        evaluator: method(:evaluate_balanced_tables_constraint),
        source: 'system'
      }
    ]
  end

  def evaluate_constraint(constraint, arrangement)
    begin
      constraint[:evaluator].call(constraint, arrangement)
    rescue StandardError => e
      Rails.logger.error "Error evaluating constraint #{constraint[:id]}: #{e.message}"
      [{
        constraint_id: constraint[:id],
        severity: :soft,
        type: 'evaluation_error',
        description: "Failed to evaluate constraint: #{e.message}",
        details: {}
      }]
    end
  end

  def evaluate_table_size_constraint(constraint, arrangement)
    violations = []
    max_size = constraint[:parameters][:max_size]
    
    arrangement.each do |table_number, students|
      if students.size > max_size
        violations << {
          constraint_id: constraint[:id],
          severity: constraint[:severity],
          type: constraint[:type],
          description: "Table #{table_number} has #{students.size} students (max: #{max_size})",
          table_number: table_number,
          details: {
            current_size: students.size,
            max_allowed: max_size,
            excess_students: students.size - max_size
          }
        }
      end
    end
    
    violations
  end

  def evaluate_minimum_table_size_constraint(constraint, arrangement)
    violations = []
    min_size = constraint[:parameters][:min_size]
    
    arrangement.each do |table_number, students|
      if students.size < min_size && students.size > 0
        violations << {
          constraint_id: constraint[:id],
          severity: constraint[:severity],
          type: constraint[:type],
          description: "Table #{table_number} has only #{students.size} student(s) (recommended: #{min_size}+)",
          table_number: table_number,
          details: {
            current_size: students.size,
            recommended_min: min_size,
            shortage: min_size - students.size
          }
        }
      end
    end
    
    violations
  end

  def evaluate_balanced_tables_constraint(constraint, arrangement)
    violations = []
    return violations if arrangement.empty?
    
    max_difference = constraint[:parameters][:max_difference]
    table_sizes = arrangement.values.map(&:size).reject(&:zero?)
    
    return violations if table_sizes.size <= 1
    
    min_size = table_sizes.min
    max_size = table_sizes.max
    
    if max_size - min_size > max_difference
      violations << {
        constraint_id: constraint[:id],
        severity: constraint[:severity],
        type: constraint[:type],
        description: "Tables are imbalanced: sizes range from #{min_size} to #{max_size} students",
        details: {
          min_table_size: min_size,
          max_table_size: max_size,
          difference: max_size - min_size,
          max_allowed_difference: max_difference,
          table_sizes: arrangement.transform_values(&:size)
        }
      }
    end
    
    violations
  end

  def evaluate_custom_constraint(constraint, arrangement)
    violations = []
    
    # Handle AI-interpreted constraints
    if constraint[:parameters].present?
      case constraint[:parameters]['constraint_type']
      when 'separate_students'
        violations.concat(evaluate_separation_constraint(constraint, arrangement))
      when 'group_students'
        violations.concat(evaluate_grouping_constraint(constraint, arrangement))
      when 'attribute_distribution'
        violations.concat(evaluate_attribute_distribution_constraint(constraint, arrangement))
      when 'avoid_combination'
        violations.concat(evaluate_avoidance_constraint(constraint, arrangement))
      else
        # Generic custom constraint evaluation
        violations.concat(evaluate_generic_constraint(constraint, arrangement))
      end
    end
    
    violations
  end

  def evaluate_separation_constraint(constraint, arrangement)
    violations = []
    students_to_separate = find_students_by_criteria(constraint[:parameters]['students'] || [])
    
    arrangement.each do |table_number, students|
      matching_students = students & students_to_separate
      if matching_students.size > 1
        violations << {
          constraint_id: constraint[:id],
          severity: constraint[:severity],
          type: 'separation',
          description: "Table #{table_number} has students that should be separated: #{matching_students.map(&:name).join(', ')}",
          table_number: table_number,
          details: {
            students_to_separate: matching_students.map(&:name),
            criteria: constraint[:parameters]['criteria']
          }
        }
      end
    end
    
    violations
  end

  def evaluate_grouping_constraint(constraint, arrangement)
    violations = []
    students_to_group = find_students_by_criteria(constraint[:parameters]['students'] || [])
    
    return violations if students_to_group.size < 2
    
    # Check if students that should be grouped are actually together
    tables_with_target_students = arrangement.select { |_, students| (students & students_to_group).any? }
    
    if tables_with_target_students.size > 1
      violations << {
        constraint_id: constraint[:id],
        severity: constraint[:severity],
        type: 'grouping',
        description: "Students that should be grouped are spread across multiple tables",
        details: {
          students_to_group: students_to_group.map(&:name),
          tables_affected: tables_with_target_students.keys,
          criteria: constraint[:parameters]['criteria']
        }
      }
    end
    
    violations
  end

  def evaluate_attribute_distribution_constraint(constraint, arrangement)
    violations = []
    attribute = constraint[:parameters]['attribute']
    desired_distribution = constraint[:parameters]['distribution'] # e.g., 'even', 'mixed'
    
    return violations unless attribute
    
    arrangement.each do |table_number, students|
      next if students.size < 2
      
      attribute_values = students.map { |s| get_student_attribute_value(s, attribute) }.compact
      
      case desired_distribution
      when 'even'
        if attribute_values.uniq.size < [attribute_values.size / 2, 2].min
          violations << create_distribution_violation(constraint, table_number, attribute, 'lacks diversity')
        end
      when 'mixed'
        if attribute_values.uniq.size <= 1 && attribute_values.size > 1
          violations << create_distribution_violation(constraint, table_number, attribute, 'not mixed')
        end
      end
    end
    
    violations
  end

  def evaluate_avoidance_constraint(constraint, arrangement)
    violations = []
    combinations_to_avoid = constraint[:parameters]['combinations'] || []
    
    arrangement.each do |table_number, students|
      combinations_to_avoid.each do |combination|
        if combination_present_at_table?(students, combination)
          violations << {
            constraint_id: constraint[:id],
            severity: constraint[:severity],
            type: 'avoidance',
            description: "Table #{table_number} contains avoided combination: #{combination['description']}",
            table_number: table_number,
            details: {
              avoided_combination: combination,
              affected_students: find_students_in_combination(students, combination).map(&:name)
            }
          }
        end
      end
    end
    
    violations
  end

  def evaluate_generic_constraint(constraint, arrangement)
    # Fallback for constraints that don't fit specific patterns
    [{
      constraint_id: constraint[:id],
      severity: :soft,
      type: 'generic',
      description: "Custom constraint evaluation not fully implemented: #{constraint[:description]}",
      details: { constraint_parameters: constraint[:parameters] }
    }]
  end

  def find_students_by_criteria(criteria)
    return [] unless criteria.is_a?(Array)
    
    students = seating_event.cohort.students
    
    criteria.each do |criterion|
      case criterion['type']
      when 'name'
        students = students.where("name ILIKE ?", "%#{criterion['value']}%")
      when 'organization'
        students = students.where("organization ILIKE ?", "%#{criterion['value']}%")
      when 'attribute'
        students = students.where("student_attributes->>'#{criterion['attribute']}' = ?", criterion['value'])
      when 'inference'
        students = students.where("inferences->>'#{criterion['field']}' @> ?", { value: criterion['value'] }.to_json)
      end
    end
    
    students.to_a
  end

  def get_student_attribute_value(student, attribute)
    case attribute
    when 'gender'
      student.gender
    when 'organization'
      student.organization
    when 'location'
      student.location
    when 'agency_level'
      student.agency_level
    when 'seniority_level'
      student.seniority_level
    else
      student.get_attribute(attribute) || student.get_inference_value(attribute)
    end
  end

  def create_distribution_violation(constraint, table_number, attribute, issue)
    {
      constraint_id: constraint[:id],
      severity: constraint[:severity],
      type: 'distribution',
      description: "Table #{table_number} #{issue} in #{attribute} distribution",
      table_number: table_number,
      details: {
        attribute: attribute,
        issue: issue,
        desired_distribution: constraint[:parameters]['distribution']
      }
    }
  end

  def combination_present_at_table?(students, combination)
    # Check if the specified combination of attributes/students is present
    return false unless combination['conditions']
    
    combination['conditions'].all? do |condition|
      students.any? do |student|
        get_student_attribute_value(student, condition['attribute']) == condition['value']
      end
    end
  end

  def find_students_in_combination(students, combination)
    return [] unless combination['conditions']
    
    students.select do |student|
      combination['conditions'].any? do |condition|
        get_student_attribute_value(student, condition['attribute']) == condition['value']
      end
    end
  end

  def calculate_max_possible_penalty(arrangement)
    # Estimate maximum possible penalty for normalization
    total_tables = arrangement.size
    total_students = arrangement.values.sum(&:size)
    
    # Rough estimate based on constraint types
    hard_constraint_count = @constraints.count { |c| c[:severity] == :hard }
    soft_constraint_count = @constraints.count { |c| c[:severity] == :soft }
    
    (hard_constraint_count * total_tables * 10.0) + (soft_constraint_count * total_tables * 1.0)
  end
end