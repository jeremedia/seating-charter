class Admin::AiConfigurationsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin_user
  before_action :set_ai_configuration, only: [:show, :edit, :update, :destroy, :activate, :test]
  
  def index
    @ai_configurations = AiConfiguration.all.order(:created_at)
    @active_config = AiConfiguration.active_configuration
  end
  
  def show
    @test_result = nil
    if params[:test] == 'true'
      @test_result = OpenaiService.test_interface(nil, current_user)
    end
  end
  
  def new
    @ai_configuration = AiConfiguration.new(
      temperature: 0.1,
      max_tokens: 500,
      batch_size: 5,
      retry_attempts: 3,
      cost_per_token: 0.00003,
      active: false
    )
  end
  
  def create
    @ai_configuration = AiConfiguration.new(ai_configuration_params)
    
    if @ai_configuration.save
      redirect_to admin_ai_configurations_path, notice: 'AI configuration was successfully created.'
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @ai_configuration.update(ai_configuration_params)
      redirect_to admin_ai_configuration_path(@ai_configuration), notice: 'AI configuration was successfully updated.'
    else
      render :edit
    end
  end
  
  def destroy
    if @ai_configuration.active?
      redirect_to admin_ai_configurations_path, alert: 'Cannot delete the active configuration.'
      return
    end
    
    @ai_configuration.destroy
    redirect_to admin_ai_configurations_path, notice: 'AI configuration was successfully deleted.'
  end
  
  def activate
    if @ai_configuration.update(active: true)
      redirect_to admin_ai_configurations_path, notice: "#{@ai_configuration.ai_model_name} is now the active configuration."
    else
      redirect_to admin_ai_configurations_path, alert: 'Failed to activate configuration.'
    end
  end
  
  def test
    @test_result = OpenaiService.test_interface(params[:test_prompt], current_user)
    render :show
  end
  
  private
  
  def set_ai_configuration
    @ai_configuration = AiConfiguration.find(params[:id])
  end
  
  def ai_configuration_params
    params.require(:ai_configuration).permit(
      :ai_model_name, :api_endpoint, :temperature, :max_tokens, 
      :batch_size, :retry_attempts, :cost_per_token, :active
    )
  end
  
  def ensure_admin_user
    # For now, allow all authenticated users. In production, add proper admin role checking
    # redirect_to root_path unless current_user.admin?
  end
end