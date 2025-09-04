class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @cohorts = current_user.cohorts.includes(:students, :seating_events)
    @recent_imports = current_user.import_sessions.recent.limit(5)
    @total_students = Student.joins(:cohort).where(cohorts: { user: current_user }).count
    @active_cohorts = @cohorts.active.count
  end
end
