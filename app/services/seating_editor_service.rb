class SeatingEditorService
  include ActiveModel::Model
  
  attr_accessor :seating_arrangement, :current_user
  
  def initialize(seating_arrangement, current_user = nil)
    @seating_arrangement = seating_arrangement
    @current_user = current_user
    @edit_history = []
  end
  
  # Process a student move between tables
  def move_student(student_id, from_table, to_table, position = nil)
    student = Student.find(student_id)
    
    # Store previous state for undo
    previous_state = capture_current_state
    
    ActiveRecord::Base.transaction do
      # Remove from old table
      old_assignment = @seating_arrangement.table_assignments.find_by(
        student: student,
        table_number: from_table
      )
      
      if old_assignment
        old_assignment.destroy
      end
      
      # Add to new table
      new_assignment = @seating_arrangement.table_assignments.create!(
        student: student,
        table_number: to_table,
        position: position
      )
      
      # Recalculate diversity scores
      new_scores = calculate_diversity_scores
      
      # Validate constraints
      constraint_violations = validate_constraints_after_move(student, from_table, to_table)
      
      # Update arrangement
      @seating_arrangement.update!(
        diversity_metrics: new_scores,
        last_modified_at: Time.current,
        last_modified_by: @current_user
      )
      
      # Add to history
      add_to_history(previous_state, "Move #{student.name} from Table #{from_table} to Table #{to_table}")
      
      {
        success: true,
        new_scores: new_scores,
        constraint_violations: constraint_violations,
        assignment: new_assignment
      }
    end
  rescue => e
    {
      success: false,
      error: e.message,
      constraint_violations: []
    }
  end
  
  # Swap two students
  def swap_students(student_a_id, student_b_id)
    student_a = Student.find(student_a_id)
    student_b = Student.find(student_b_id)
    
    assignment_a = @seating_arrangement.table_assignments.find_by(student: student_a)
    assignment_b = @seating_arrangement.table_assignments.find_by(student: student_b)
    
    return { success: false, error: "Students not found in arrangement" } unless assignment_a && assignment_b
    
    previous_state = capture_current_state
    
    ActiveRecord::Base.transaction do
      # Swap table assignments
      temp_table = assignment_a.table_number
      temp_position = assignment_a.position
      
      assignment_a.update!(
        table_number: assignment_b.table_number,
        position: assignment_b.position
      )
      
      assignment_b.update!(
        table_number: temp_table,
        position: temp_position
      )
      
      # Recalculate scores
      new_scores = calculate_diversity_scores
      constraint_violations = validate_all_constraints
      
      @seating_arrangement.update!(
        diversity_metrics: new_scores,
        last_modified_at: Time.current,
        last_modified_by: @current_user
      )
      
      add_to_history(previous_state, "Swap #{student_a.name} and #{student_b.name}")
      
      {
        success: true,
        new_scores: new_scores,
        constraint_violations: constraint_violations
      }
    end
  rescue => e
    {
      success: false,
      error: e.message
    }
  end
  
  # Create a new table
  def create_table(table_number = nil)
    table_number ||= next_available_table_number
    
    # Check if table already exists
    existing = @seating_arrangement.table_assignments.exists?(table_number: table_number)
    return { success: false, error: "Table #{table_number} already exists" } if existing
    
    {
      success: true,
      table_number: table_number,
      message: "Table #{table_number} created"
    }
  end
  
  # Delete a table and move students to unassigned
  def delete_table(table_number)
    assignments = @seating_arrangement.table_assignments.where(table_number: table_number)
    return { success: false, error: "Table not found" } if assignments.empty?
    
    previous_state = capture_current_state
    
    ActiveRecord::Base.transaction do
      # Move students to unassigned (table 0)
      assignments.update_all(table_number: 0, position: nil)
      
      new_scores = calculate_diversity_scores
      
      @seating_arrangement.update!(
        diversity_metrics: new_scores,
        last_modified_at: Time.current,
        last_modified_by: @current_user
      )
      
      add_to_history(previous_state, "Delete Table #{table_number}")
      
      {
        success: true,
        moved_students: assignments.count,
        new_scores: new_scores
      }
    end
  end
  
  # Balance table sizes
  def balance_tables
    previous_state = capture_current_state
    
    assignments = @seating_arrangement.table_assignments.includes(:student)
    tables = assignments.group_by(&:table_number).reject { |k, _| k == 0 }
    
    return { success: false, error: "No tables to balance" } if tables.empty?
    
    total_students = assignments.count
    num_tables = tables.keys.count
    target_size = (total_students / num_tables.to_f).round
    
    ActiveRecord::Base.transaction do
      # Complex balancing logic would go here
      # For now, we'll implement basic redistribution
      
      new_scores = calculate_diversity_scores
      
      @seating_arrangement.update!(
        diversity_metrics: new_scores,
        last_modified_at: Time.current,
        last_modified_by: @current_user
      )
      
      add_to_history(previous_state, "Balance table sizes")
      
      {
        success: true,
        target_size: target_size,
        new_scores: new_scores
      }
    end
  end
  
  # Shuffle students on a specific table
  def shuffle_table(table_number)
    assignments = @seating_arrangement.table_assignments.where(table_number: table_number)
    return { success: false, error: "Table not found" } if assignments.empty?
    
    previous_state = capture_current_state
    
    ActiveRecord::Base.transaction do
      students = assignments.map(&:student).shuffle
      assignments.each_with_index do |assignment, index|
        assignment.update!(student: students[index], position: index + 1)
      end
      
      new_scores = calculate_diversity_scores
      
      @seating_arrangement.update!(
        diversity_metrics: new_scores,
        last_modified_at: Time.current,
        last_modified_by: @current_user
      )
      
      add_to_history(previous_state, "Shuffle Table #{table_number}")
      
      {
        success: true,
        shuffled_count: students.count,
        new_scores: new_scores
      }
    end
  end
  
  # Undo last action
  def undo
    return { success: false, error: "No actions to undo" } if @edit_history.empty?
    
    previous_state = @edit_history.pop
    
    ActiveRecord::Base.transaction do
      restore_state(previous_state[:state])
      
      {
        success: true,
        action: previous_state[:description],
        restored_at: Time.current
      }
    end
  rescue => e
    {
      success: false,
      error: "Failed to undo: #{e.message}"
    }
  end
  
  # Auto-save current state
  def auto_save
    @seating_arrangement.update!(
      arrangement_data: serialize_current_state,
      last_modified_at: Time.current,
      last_modified_by: @current_user
    )
    
    { success: true, saved_at: Time.current }
  end
  
  # Get current table layout for rendering
  def get_table_layout
    assignments = @seating_arrangement.table_assignments.includes(:student)
    tables = assignments.group_by(&:table_number)
    
    layout = {}
    tables.each do |table_number, table_assignments|
      layout[table_number] = {
        students: table_assignments.sort_by { |a| a.position || 0 }.map do |assignment|
          {
            id: assignment.student.id,
            name: assignment.student.name,
            organization: assignment.student.organization,
            title: assignment.student.title,
            gender: assignment.student.gender,
            agency_level: assignment.student.agency_level,
            department_type: assignment.student.department_type,
            seniority_level: assignment.student.seniority_level,
            position: assignment.position
          }
        end,
        diversity_score: calculate_table_diversity_score(table_number),
        constraint_violations: get_table_constraint_violations(table_number)
      }
    end
    
    layout
  end
  
  private
  
  def capture_current_state
    {
      assignments: @seating_arrangement.table_assignments.map do |assignment|
        {
          student_id: assignment.student_id,
          table_number: assignment.table_number,
          position: assignment.position
        }
      end,
      diversity_metrics: @seating_arrangement.diversity_metrics,
      timestamp: Time.current
    }
  end
  
  def restore_state(state)
    @seating_arrangement.table_assignments.destroy_all
    
    state[:assignments].each do |assignment_data|
      @seating_arrangement.table_assignments.create!(
        student_id: assignment_data[:student_id],
        table_number: assignment_data[:table_number],
        position: assignment_data[:position]
      )
    end
    
    @seating_arrangement.update!(
      diversity_metrics: state[:diversity_metrics],
      last_modified_at: Time.current,
      last_modified_by: @current_user
    )
  end
  
  def add_to_history(state, description)
    @edit_history << {
      state: state,
      description: description,
      timestamp: Time.current
    }
    
    # Keep only last 20 actions
    @edit_history = @edit_history.last(20)
  end
  
  def serialize_current_state
    capture_current_state.to_json
  end
  
  def next_available_table_number
    existing_numbers = @seating_arrangement.table_assignments
                                          .select(:table_number)
                                          .distinct
                                          .where.not(table_number: 0)
                                          .pluck(:table_number)
    
    (1..20).find { |n| !existing_numbers.include?(n) } || existing_numbers.max + 1
  end
  
  def calculate_diversity_scores
    # This would implement the actual diversity calculation logic
    # For now, return a basic structure
    {
      overall_score: rand(0.6..1.0).round(3),
      gender_balance: rand(0.5..1.0).round(3),
      agency_distribution: rand(0.5..1.0).round(3),
      department_mix: rand(0.5..1.0).round(3),
      seniority_spread: rand(0.5..1.0).round(3),
      calculated_at: Time.current.iso8601
    }
  end
  
  def calculate_table_diversity_score(table_number)
    # Calculate diversity score for a specific table
    assignments = @seating_arrangement.table_assignments
                                     .joins(:student)
                                     .where(table_number: table_number)
    
    return 0.0 if assignments.empty?
    
    # Basic diversity calculation
    students = assignments.map(&:student)
    gender_variety = students.map(&:gender).uniq.count
    agency_variety = students.map(&:agency_level).uniq.count
    
    # Simple diversity score based on variety
    variety_score = (gender_variety + agency_variety) / (students.count * 2.0)
    [variety_score, 1.0].min.round(3)
  end
  
  def validate_constraints_after_move(student, from_table, to_table)
    violations = []
    
    # Get active seating rules for this event
    rules = @seating_arrangement.seating_event.seating_rules.where(is_active: true)
    
    rules.each do |rule|
      violation = check_rule_violation(rule, student, to_table)
      violations << violation if violation
    end
    
    violations
  end
  
  def validate_all_constraints
    violations = []
    
    # Check all active rules against current arrangement
    rules = @seating_arrangement.seating_event.seating_rules.where(is_active: true)
    
    rules.each do |rule|
      rule_violations = check_rule_against_arrangement(rule)
      violations.concat(rule_violations)
    end
    
    violations
  end
  
  def get_table_constraint_violations(table_number)
    violations = []
    assignments = @seating_arrangement.table_assignments.where(table_number: table_number)
    
    return violations if assignments.empty?
    
    # Check for basic constraint violations
    students = assignments.includes(:student).map(&:student)
    
    # Example: Check if table has too many students from same agency
    agency_counts = students.group_by(&:agency_level).transform_values(&:count)
    max_from_same_agency = students.count > 4 ? 2 : 1
    
    agency_counts.each do |agency, count|
      if count > max_from_same_agency
        violations << {
          type: 'agency_concentration',
          severity: 'warning',
          message: "Too many students from #{agency} agency (#{count}/#{max_from_same_agency})"
        }
      end
    end
    
    violations
  end
  
  def check_rule_violation(rule, student, table_number)
    # Implement rule checking logic based on rule type
    # This is a placeholder - actual implementation would depend on rule structure
    nil
  end
  
  def check_rule_against_arrangement(rule)
    # Check rule against entire arrangement
    []
  end
end