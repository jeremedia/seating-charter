class Admin::CostTrackingsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin_user
  before_action :set_cost_tracking, only: [:show]
  
  def index
    @cost_trackings = CostTracking.includes(:user)
                                  .order(created_at: :desc)
                                  .page(params[:page])
                                  .per(50)
    
    # Summary statistics
    @total_cost = CostTracking.sum(:cost_estimate)
    @total_tokens = CostTracking.sum('input_tokens + output_tokens')
    @requests_today = CostTracking.where('created_at >= ?', Date.current.beginning_of_day).count
    @cost_today = CostTracking.where('created_at >= ?', Date.current.beginning_of_day).sum(:cost_estimate)
    
    # Filter options
    if params[:user_id].present?
      @cost_trackings = @cost_trackings.where(user_id: params[:user_id])
    end
    
    if params[:purpose].present?
      @cost_trackings = @cost_trackings.where(purpose: params[:purpose])
    end
    
    if params[:ai_model_used].present?
      @cost_trackings = @cost_trackings.where(ai_model_used: params[:ai_model_used])
    end
    
    # Group by purpose for chart data
    @cost_by_purpose = CostTracking.group(:purpose).sum(:cost_estimate)
    @requests_by_model = CostTracking.group(:ai_model_used).count
  end
  
  def show
  end
  
  private
  
  def set_cost_tracking
    @cost_tracking = CostTracking.find(params[:id])
  end
  
  def ensure_admin_user
    # For now, allow all authenticated users. In production, add proper admin role checking
    # redirect_to root_path unless current_user.admin?
  end
end