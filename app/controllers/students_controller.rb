class StudentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_cohort
  before_action :set_student, only: [:edit, :update, :destroy]

  def index
    @students = @cohort.students.order(:name)
    @students_with_inferences = @students.select { |s| s.inferences.present? && s.inferences.any? }
    @students_without_inferences = @students - @students_with_inferences
  end

  def new
    @student = @cohort.students.build
  end

  def create
    @student = @cohort.students.build(student_params)
    
    if @student.save
      redirect_to cohort_students_path(@cohort), notice: 'Student was successfully added.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @student.update(student_params)
      # Update inferences based on the form inputs
      update_student_inferences(@student)
      redirect_to cohort_students_path(@cohort), notice: 'Student was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @student.destroy
    redirect_to cohort_students_path(@cohort), notice: 'Student was successfully removed.'
  end

  private

  def set_cohort
    @cohort = current_user.cohorts.find(params[:cohort_id])
  end

  def set_student
    @student = @cohort.students.find(params[:id])
  end

  def student_params
    params.require(:student).permit(:name, :title, :organization, :location, 
                                   :gender, :agency_level, :department_type, :seniority_level)
  end
  
  def update_student_inferences(student)
    # Build new inferences object based on form inputs
    new_inferences = student.inferences || {}
    
    # Update gender if provided
    if params[:student][:gender].present?
      new_inferences['gender'] = {
        'value' => params[:student][:gender],
        'confidence' => student.inferences&.dig('gender', 'confidence') || 1.0
      }
    else
      new_inferences.delete('gender')
    end
    
    # Update agency_level if provided
    if params[:student][:agency_level].present?
      new_inferences['agency_level'] = {
        'value' => params[:student][:agency_level],
        'confidence' => student.inferences&.dig('agency_level', 'confidence') || 1.0
      }
    else
      new_inferences.delete('agency_level')
    end
    
    # Update department_type if provided
    if params[:student][:department_type].present?
      new_inferences['department_type'] = {
        'value' => params[:student][:department_type],
        'confidence' => student.inferences&.dig('department_type', 'confidence') || 1.0
      }
    else
      new_inferences.delete('department_type')
    end
    
    # Update seniority_level if provided
    if params[:student][:seniority_level].present?
      new_inferences['seniority_level'] = {
        'value' => params[:student][:seniority_level],
        'confidence' => student.inferences&.dig('seniority_level', 'confidence') || 1.0
      }
    else
      new_inferences.delete('seniority_level')
    end
    
    # Save the updated inferences
    student.update_column(:inferences, new_inferences.presence)
  end
end