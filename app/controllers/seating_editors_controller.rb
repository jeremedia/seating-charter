class SeatingEditorsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_seating_arrangement
  before_action :set_editor_service
  
  # GET /seating_arrangements/:id/edit
  def edit
    @table_layout = @editor_service.get_table_layout
    @unassigned_students = get_unassigned_students
    @diversity_scores = @seating_arrangement.diversity_metrics || {}
    @constraint_violations = get_all_constraint_violations
  end
  
  # POST /seating_arrangements/:id/move_student
  def move_student
    result = @editor_service.move_student(
      params[:student_id],
      params[:from_table].to_i,
      params[:to_table].to_i,
      params[:position]&.to_i
    )
    
    if result[:success]
      render json: {
        success: true,
        new_scores: result[:new_scores],
        constraint_violations: result[:constraint_violations],
        table_layout: @editor_service.get_table_layout
      }
    else
      render json: {
        success: false,
        error: result[:error],
        constraint_violations: result[:constraint_violations]
      }, status: :unprocessable_entity
    end
  end
  
  # POST /seating_arrangements/:id/swap_students
  def swap_students
    result = @editor_service.swap_students(
      params[:student_a_id],
      params[:student_b_id]
    )
    
    if result[:success]
      render json: {
        success: true,
        new_scores: result[:new_scores],
        constraint_violations: result[:constraint_violations],
        table_layout: @editor_service.get_table_layout
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end
  
  # POST /seating_arrangements/:id/create_table
  def create_table
    result = @editor_service.create_table(params[:table_number]&.to_i)
    
    if result[:success]
      render json: {
        success: true,
        table_number: result[:table_number],
        message: result[:message],
        table_layout: @editor_service.get_table_layout
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end
  
  # DELETE /seating_arrangements/:id/delete_table/:table_number
  def delete_table
    result = @editor_service.delete_table(params[:table_number].to_i)
    
    if result[:success]
      render json: {
        success: true,
        moved_students: result[:moved_students],
        new_scores: result[:new_scores],
        table_layout: @editor_service.get_table_layout,
        unassigned_students: get_unassigned_students
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end
  
  # POST /seating_arrangements/:id/balance_tables
  def balance_tables
    result = @editor_service.balance_tables
    
    if result[:success]
      render json: {
        success: true,
        target_size: result[:target_size],
        new_scores: result[:new_scores],
        table_layout: @editor_service.get_table_layout
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end
  
  # POST /seating_arrangements/:id/shuffle_table/:table_number
  def shuffle_table
    result = @editor_service.shuffle_table(params[:table_number].to_i)
    
    if result[:success]
      render json: {
        success: true,
        shuffled_count: result[:shuffled_count],
        new_scores: result[:new_scores],
        table_layout: @editor_service.get_table_layout
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end
  
  # POST /seating_arrangements/:id/undo
  def undo
    result = @editor_service.undo
    
    if result[:success]
      render json: {
        success: true,
        action: result[:action],
        restored_at: result[:restored_at],
        table_layout: @editor_service.get_table_layout,
        diversity_scores: @seating_arrangement.reload.diversity_metrics,
        unassigned_students: get_unassigned_students
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end
  
  # POST /seating_arrangements/:id/auto_save
  def auto_save
    result = @editor_service.auto_save
    
    render json: {
      success: result[:success],
      saved_at: result[:saved_at],
      error: result[:error]
    }
  end
  
  # GET /seating_arrangements/:id/status
  def status
    render json: {
      table_layout: @editor_service.get_table_layout,
      diversity_scores: @seating_arrangement.diversity_metrics,
      constraint_violations: get_all_constraint_violations,
      unassigned_students: get_unassigned_students,
      last_modified_at: @seating_arrangement.last_modified_at,
      last_modified_by: @seating_arrangement.last_modified_by&.name
    }
  end
  
  # POST /seating_arrangements/:id/lock
  def lock
    @seating_arrangement.update!(
      is_locked: true,
      locked_by: current_user,
      locked_at: Time.current
    )
    
    render json: {
      success: true,
      locked_by: current_user.name,
      locked_at: @seating_arrangement.locked_at
    }
  end
  
  # POST /seating_arrangements/:id/unlock
  def unlock
    @seating_arrangement.update!(
      is_locked: false,
      locked_by: nil,
      locked_at: nil
    )
    
    render json: {
      success: true,
      unlocked_at: Time.current
    }
  end
  
  # GET /seating_arrangements/:id/search_students
  def search_students
    query = params[:query]&.downcase
    
    students = @seating_arrangement.seating_event.cohort.students
    
    if query.present?
      students = students.where(
        "LOWER(name) LIKE ? OR LOWER(organization) LIKE ? OR LOWER(title) LIKE ?",
        "%#{query}%", "%#{query}%", "%#{query}%"
      )
    end
    
    # Get current assignments
    assignments = @seating_arrangement.table_assignments.includes(:student)
    assignment_map = assignments.index_by(&:student_id)
    
    results = students.limit(20).map do |student|
      assignment = assignment_map[student.id]
      {
        id: student.id,
        name: student.name,
        organization: student.organization,
        title: student.title,
        current_table: assignment&.table_number,
        gender: student.gender,
        agency_level: student.agency_level,
        department_type: student.department_type,
        seniority_level: student.seniority_level
      }
    end
    
    render json: { students: results }
  end
  
  # POST /seating_arrangements/:id/apply_template
  def apply_template
    template_name = params[:template_name]
    
    case template_name
    when 'u_shape'
      result = apply_u_shape_template
    when 'classroom'
      result = apply_classroom_template
    when 'roundtables'
      result = apply_roundtables_template
    else
      result = { success: false, error: "Unknown template: #{template_name}" }
    end
    
    if result[:success]
      render json: {
        success: true,
        template_applied: template_name,
        table_layout: @editor_service.get_table_layout,
        new_scores: result[:new_scores]
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end
  
  # GET /seating_arrangements/:id/export
  def export
    format = params[:format] || 'json'
    
    case format
    when 'json'
      render json: {
        arrangement: {
          id: @seating_arrangement.id,
          name: "Seating Arrangement #{@seating_arrangement.id}",
          event: @seating_arrangement.seating_event.event_name,
          created_at: @seating_arrangement.created_at,
          diversity_scores: @seating_arrangement.diversity_metrics,
          table_layout: @editor_service.get_table_layout
        }
      }
    when 'csv'
      csv_data = generate_csv_export
      send_data csv_data, filename: "seating_arrangement_#{@seating_arrangement.id}.csv"
    when 'pdf'
      # Would implement PDF generation
      render json: { error: "PDF export not yet implemented" }, status: :not_implemented
    else
      render json: { error: "Unsupported format: #{format}" }, status: :bad_request
    end
  end
  
  private
  
  def set_seating_arrangement
    @seating_arrangement = SeatingArrangement.find(params[:id] || params[:seating_arrangement_id])
  end
  
  def set_editor_service
    @editor_service = SeatingEditorService.new(@seating_arrangement, current_user)
  end
  
  def get_unassigned_students
    assigned_student_ids = @seating_arrangement.table_assignments
                                             .where.not(table_number: 0)
                                             .pluck(:student_id)
    
    unassigned_assignments = @seating_arrangement.table_assignments
                                                .includes(:student)
                                                .where(table_number: 0)
    
    unassigned_assignments.map do |assignment|
      {
        id: assignment.student.id,
        name: assignment.student.name,
        organization: assignment.student.organization,
        title: assignment.student.title,
        gender: assignment.student.gender,
        agency_level: assignment.student.agency_level,
        department_type: assignment.student.department_type,
        seniority_level: assignment.student.seniority_level
      }
    end
  end
  
  def get_all_constraint_violations
    violations = []
    
    # Get violations for each table
    table_numbers = @seating_arrangement.table_assignments
                                       .select(:table_number)
                                       .distinct
                                       .where.not(table_number: 0)
                                       .pluck(:table_number)
    
    table_numbers.each do |table_number|
      table_violations = @editor_service.send(:get_table_constraint_violations, table_number)
      violations.concat(table_violations.map { |v| v.merge(table_number: table_number) })
    end
    
    violations
  end
  
  def apply_u_shape_template
    # Implement U-shape seating template
    # This would arrange students in a U formation
    
    @editor_service.auto_save
    
    {
      success: true,
      new_scores: @seating_arrangement.reload.diversity_metrics
    }
  end
  
  def apply_classroom_template
    # Implement classroom-style seating template
    # This would arrange students in rows
    
    @editor_service.auto_save
    
    {
      success: true,
      new_scores: @seating_arrangement.reload.diversity_metrics
    }
  end
  
  def apply_roundtables_template
    # Implement round tables template
    # This would distribute students evenly across round tables
    
    @editor_service.auto_save
    
    {
      success: true,
      new_scores: @seating_arrangement.reload.diversity_metrics
    }
  end
  
  def generate_csv_export
    require 'csv'
    
    table_layout = @editor_service.get_table_layout
    
    CSV.generate do |csv|
      csv << ['Table Number', 'Student Name', 'Organization', 'Title', 'Gender', 'Agency Level', 'Department Type', 'Seniority Level']
      
      table_layout.each do |table_number, table_data|
        next if table_number == 0 # Skip unassigned
        
        table_data[:students].each do |student|
          csv << [
            table_number,
            student[:name],
            student[:organization],
            student[:title],
            student[:gender],
            student[:agency_level],
            student[:department_type],
            student[:seniority_level]
          ]
        end
      end
    end
  end
end