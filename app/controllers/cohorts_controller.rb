class CohortsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_cohort, only: [:show, :edit, :update, :destroy]
  
  def index
    @cohorts = current_user.cohorts.includes(:students, :seating_events)
  end
  
  def show
    @students = @cohort.students.includes(:student_import_records)
    @recent_imports = @cohort.import_sessions.recent.limit(5)
    @seating_events = @cohort.seating_events.includes(:seating_arrangements)
  end
  
  def new
    @cohort = current_user.cohorts.build
  end
  
  def create
    @cohort = current_user.cohorts.build(cohort_params)
    
    if @cohort.save
      redirect_to @cohort, notice: 'Cohort was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    if @cohort.update(cohort_params)
      redirect_to @cohort, notice: 'Cohort was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @cohort.destroy
    redirect_to cohorts_path, notice: 'Cohort was successfully deleted.'
  end
  
  private
  
  def set_cohort
    @cohort = current_user.cohorts.find(params[:id])
  end
  
  def cohort_params
    params.require(:cohort).permit(:name, :description, :start_date, :end_date, :max_students)
  end
end