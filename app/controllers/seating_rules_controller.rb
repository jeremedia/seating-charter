class SeatingRulesController < ApplicationController
  before_action :set_seating_event
  before_action :set_seating_rule, only: [:show, :edit, :update, :destroy, :toggle]
  
  # GET /seating_events/:seating_event_id/seating_rules
  def index
    @seating_rules = @seating_event.seating_rules.includes(:seating_event).by_priority
    @natural_language_instructions = @seating_event.natural_language_instructions.includes(:created_by).order(created_at: :desc)
    
    # Get validation results for all rules
    @validation_result = RuleValidationService.validate_all_rules(@seating_event)
    
    # Statistics
    @stats = {
      total_rules: @seating_rules.count,
      active_rules: @seating_rules.active.count,
      high_confidence: @seating_rules.high_confidence.count,
      rule_types: @seating_rules.group(:rule_type).count
    }
  end
  
  # GET /seating_events/:seating_event_id/seating_rules/new
  def new
    @seating_rule = @seating_event.seating_rules.build
    @common_patterns = NaturalLanguageParsingService.get_common_patterns
    @sample_instructions = get_sample_instructions
  end
  
  # POST /seating_events/:seating_event_id/seating_rules
  def create
    if params[:natural_language_input].present?
      # Parse natural language instruction
      result = NaturalLanguageParsingService.parse_instruction(
        params[:natural_language_input],
        @seating_event,
        current_user
      )
      
      if result[:success]
        redirect_to seating_event_seating_rules_path(@seating_event), 
                   notice: "Successfully parsed instruction and created #{result[:rules].count} rule(s) with #{(result[:confidence] * 100).round(1)}% confidence."
      else
        flash.now[:alert] = "Failed to parse instruction: #{result[:error]}"
        @seating_rule = @seating_event.seating_rules.build
        @common_patterns = NaturalLanguageParsingService.get_common_patterns
        @sample_instructions = get_sample_instructions
        render :new
      end
    else
      # Manual rule creation
      @seating_rule = @seating_event.seating_rules.build(seating_rule_params)
      
      if @seating_rule.save
        redirect_to seating_event_seating_rules_path(@seating_event), 
                   notice: 'Seating rule was successfully created.'
      else
        @common_patterns = NaturalLanguageParsingService.get_common_patterns
        @sample_instructions = get_sample_instructions
        render :new
      end
    end
  end
  
  # GET /seating_events/:seating_event_id/seating_rules/:id
  def show
    @validation_result = RuleValidationService.validate_single_rule(@seating_rule)
    
    # Get affected students preview
    @affected_students = get_affected_students_preview(@seating_rule)
  end
  
  # GET /seating_events/:seating_event_id/seating_rules/:id/edit
  def edit
    @validation_result = RuleValidationService.validate_single_rule(@seating_rule)
  end
  
  # PATCH/PUT /seating_events/:seating_event_id/seating_rules/:id
  def update
    if @seating_rule.update(seating_rule_params)
      redirect_to seating_event_seating_rule_path(@seating_event, @seating_rule), 
                 notice: 'Seating rule was successfully updated.'
    else
      @validation_result = RuleValidationService.validate_single_rule(@seating_rule)
      render :edit
    end
  end
  
  # DELETE /seating_events/:seating_event_id/seating_rules/:id
  def destroy
    @seating_rule.destroy
    redirect_to seating_event_seating_rules_path(@seating_event), 
               notice: 'Seating rule was successfully deleted.'
  end
  
  # PATCH /seating_events/:seating_event_id/seating_rules/:id/toggle
  def toggle
    @seating_rule.update(active: !@seating_rule.active)
    
    status = @seating_rule.active? ? 'activated' : 'deactivated'
    redirect_to seating_event_seating_rules_path(@seating_event), 
               notice: "Rule was successfully #{status}."
  end
  
  # POST /seating_events/:seating_event_id/seating_rules/preview
  def preview
    if params[:instruction_text].present?
      result = NaturalLanguageParsingService.preview_parsing(
        params[:instruction_text],
        @seating_event
      )
      
      render json: result
    else
      render json: { success: false, error: "No instruction text provided" }
    end
  end
  
  # POST /seating_events/:seating_event_id/seating_rules/batch_parse
  def batch_parse
    instructions = params[:instructions].reject(&:blank?)
    
    if instructions.any?
      results = NaturalLanguageParsingService.parse_batch(
        instructions,
        @seating_event,
        current_user
      )
      
      successful = results.count { |r| r[:success] }
      total = results.count
      
      redirect_to seating_event_seating_rules_path(@seating_event),
                 notice: "Processed #{total} instructions. #{successful} successful, #{total - successful} failed."
    else
      redirect_to new_seating_event_seating_rule_path(@seating_event),
                 alert: "No instructions provided."
    end
  end
  
  # GET /seating_events/:seating_event_id/seating_rules/validate
  def validate
    @validation_result = RuleValidationService.validate_all_rules(@seating_event)
    
    render json: @validation_result
  end
  
  private
  
  def set_seating_event
    @seating_event = SeatingEvent.find(params[:seating_event_id])
  end
  
  def set_seating_rule
    @seating_rule = @seating_event.seating_rules.find(params[:id])
  end
  
  def seating_rule_params
    # Handle target_attributes specially since it comes in a different format from the form
    rule_params = params.require(:seating_rule).permit(
      :rule_type, :natural_language_input, :priority, :active,
      constraints: {}
    )
    
    # Process target_attributes from form format
    if params[:seating_rule][:target_attributes].present?
      target_attrs = {}
      params[:seating_rule][:target_attributes].each do |_, attr_data|
        field = attr_data[:field]
        values = attr_data[:values]
        
        if field.present? && values.present?
          # Split comma-separated values and clean them
          target_attrs[field] = values.split(',').map(&:strip).reject(&:blank?)
        end
      end
      rule_params[:target_attributes] = target_attrs
    end
    
    rule_params
  end
  
  def get_sample_instructions
    [
      "Keep all FBI agents at different tables",
      "Group all California agencies together", 
      "Spread military personnel evenly across tables",
      "Place new students near experienced ones",
      "Separate people from the same agency",
      "Ensure each table has mix of federal, state, and local",
      "Keep international students with domestic students",
      "Don't put more than 2 people from law enforcement at one table"
    ]
  end
  
  def get_affected_students_preview(rule, limit = 10)
    return [] unless rule.target_attributes.present?
    
    students = @seating_event.cohort.students.limit(100)
    affected = []
    
    students.each do |student|
      if rule.applies_to_student?(student)
        affected << {
          name: student.name,
          organization: student.organization,
          matching_attributes: get_matching_attributes(student, rule)
        }
      end
      
      break if affected.count >= limit
    end
    
    affected
  end
  
  def get_matching_attributes(student, rule)
    matching = {}
    
    rule.target_attributes.each do |field, values|
      student_value = student.get_attribute(field) || student.get_inference_value(field)
      if Array(values).include?(student_value)
        matching[field] = student_value
      end
    end
    
    matching
  end
end