class ImportReviewsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_cohort
  before_action :set_import_session, only: [:index, :edit, :update, :bulk_update, :confirm]
  before_action :set_student, only: [:edit, :update]
  
  def index
    @students = @import_session.student_import_records.includes(:student).map(&:student)
    @inference_fields = %w[gender agency_level department_type seniority_level]
    
    # Group students by confidence levels for summary
    @high_confidence_students = @students.select { |s| average_confidence(s) >= 0.8 }
    @medium_confidence_students = @students.select { |s| average_confidence(s) >= 0.6 && average_confidence(s) < 0.8 }
    @low_confidence_students = @students.select { |s| average_confidence(s) < 0.6 }
  end
  
  def edit
    @inference_fields = %w[gender agency_level department_type seniority_level]
    @field_options = field_options
  end
  
  def update
    inference_params = params[:student][:inferences] || {}
    updated_fields = []
    
    inference_params.each do |field, value|
      next if value.blank?
      
      # Set inference with manual confidence (high since it's manually reviewed)
      @student.set_inference(field, value, 0.95)
      updated_fields << field.humanize
    end
    
    if @student.save
      redirect_to cohort_import_session_import_reviews_path(@cohort, @import_session),
                  notice: "Updated #{@student.name}'s attributes: #{updated_fields.join(', ')}"
    else
      @inference_fields = %w[gender agency_level department_type seniority_level]
      @field_options = field_options
      render :edit, status: :unprocessable_entity
    end
  end
  
  def bulk_update
    action = params[:bulk_action]
    student_ids = params[:student_ids] || []
    
    if student_ids.empty?
      redirect_to cohort_import_session_import_reviews_path(@cohort, @import_session),
                  alert: 'Please select at least one student.'
      return
    end
    
    students = Student.where(id: student_ids, cohort: @cohort)
    
    case action
    when 'accept_high_confidence'
      accept_high_confidence_inferences(students)
    when 'reject_low_confidence'
      reject_low_confidence_inferences(students)
    when 'reset_all'
      reset_all_inferences(students)
    else
      redirect_to cohort_import_session_import_reviews_path(@cohort, @import_session),
                  alert: 'Invalid bulk action.'
      return
    end
    
    redirect_to cohort_import_session_import_reviews_path(@cohort, @import_session),
                notice: "Bulk action completed for #{students.count} students."
  end
  
  def confirm
    # Mark all students as reviewed and finalize the import
    students = @import_session.student_import_records.includes(:student).map(&:student)
    
    # Set all students as reviewed
    students.each do |student|
      student.set_attribute('reviewed_at', Time.current.iso8601)
      student.set_attribute('reviewed_by', current_user.id)
      student.save!
    end
    
    # Update import session status
    @import_session.update!(
      status: :completed,
      import_metadata: (@import_session.import_metadata || {}).merge({
        reviewed_at: Time.current.iso8601,
        reviewed_by: current_user.id,
        students_reviewed: students.count
      })
    )
    
    redirect_to cohort_path(@cohort), 
                notice: "Import review completed! #{students.count} students have been added to #{@cohort.name}."
  end
  
  private
  
  def set_cohort
    @cohort = Cohort.find(params[:cohort_id])
    authorize_cohort_access
  end
  
  def set_import_session
    @import_session = @cohort.import_sessions.find(params[:import_session_id])
    
    unless @import_session.completed?
      redirect_to cohort_import_path(@cohort, @import_session),
                  alert: 'Import is still processing. Please wait for completion.'
    end
  end
  
  def set_student
    @student = Student.find(params[:id])
    
    unless @import_session.student_import_records.find_by(student: @student)
      redirect_to cohort_import_session_import_reviews_path(@cohort, @import_session),
                  alert: 'Student not found in this import session.'
    end
  end
  
  def authorize_cohort_access
    unless @cohort.user == current_user || current_user.admin?
      redirect_to dashboard_path, alert: 'Access denied.'
    end
  end
  
  def average_confidence(student)
    inference_fields = %w[gender agency_level department_type seniority_level]
    confidences = inference_fields.map { |field| student.get_inference_confidence(field) }.compact
    
    return 0.0 if confidences.empty?
    confidences.sum / confidences.size
  end
  
  def accept_high_confidence_inferences(students)
    students.each do |student|
      %w[gender agency_level department_type seniority_level].each do |field|
        confidence = student.get_inference_confidence(field)
        if confidence && confidence >= 0.8
          # Mark as accepted by setting confidence to 0.99
          current_value = student.get_inference_value(field)
          student.set_inference(field, current_value, 0.99) if current_value
        end
      end
      student.save!
    end
  end
  
  def reject_low_confidence_inferences(students)
    students.each do |student|
      %w[gender agency_level department_type seniority_level].each do |field|
        confidence = student.get_inference_confidence(field)
        if confidence && confidence < 0.6
          # Reset to unknown with low confidence
          student.set_inference(field, 'unknown', 0.1)
        end
      end
      student.save!
    end
  end
  
  def reset_all_inferences(students)
    students.each do |student|
      %w[gender agency_level department_type seniority_level].each do |field|
        student.set_inference(field, 'unknown', 0.1)
      end
      student.save!
    end
  end
  
  def field_options
    {
      'gender' => [
        ['Male', 'male'],
        ['Female', 'female'],
        ['Unknown', 'unknown']
      ],
      'agency_level' => [
        ['Federal', 'federal'],
        ['State', 'state'],
        ['Local', 'local'],
        ['Military', 'military'],
        ['Private', 'private'],
        ['Unknown', 'unknown']
      ],
      'department_type' => [
        ['Law Enforcement', 'law_enforcement'],
        ['Fire/EMS', 'fire_ems'],
        ['Emergency Management', 'emergency_management'],
        ['Military', 'military'],
        ['Intelligence', 'intelligence'],
        ['Public Health', 'public_health'],
        ['Cybersecurity', 'cybersecurity'],
        ['Transportation', 'transportation'],
        ['Homeland Security', 'homeland_security'],
        ['Unknown', 'unknown']
      ],
      'seniority_level' => [
        ['Senior', 'senior'],
        ['Mid-level', 'mid_level'],
        ['Junior', 'junior'],
        ['Unknown', 'unknown']
      ]
    }
  end
end