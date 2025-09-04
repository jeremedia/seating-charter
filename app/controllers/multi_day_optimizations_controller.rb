# frozen_string_literal: true

class MultiDayOptimizationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_cohort
  before_action :set_seating_event
  before_action :check_multi_day_event
  
  def new
    @multi_day_config = build_default_config
    @rotation_strategies = RotationStrategyService::ROTATION_STRATEGIES
    @available_days = calculate_available_days
    @student_count = @seating_event.cohort.students.count
  end

  def create
    @multi_day_config = multi_day_params
    
    if validate_multi_day_config(@multi_day_config)
      # Start async optimization
      job = MultiDayOptimizationJob.perform_later(
        @seating_event.id,
        @multi_day_config,
        current_user.id
      )
      
      redirect_to optimization_status_cohort_seating_event_multi_day_optimizations_path(
        @cohort, @seating_event, job_id: job.job_id
      ), notice: 'Multi-day optimization started. This may take a few minutes.'
    else
      @rotation_strategies = RotationStrategyService::ROTATION_STRATEGIES
      @available_days = calculate_available_days
      @student_count = @seating_event.cohort.students.count
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @optimization_result = load_optimization_result
    
    if @optimization_result.blank?
      redirect_to new_cohort_seating_event_multi_day_optimization_path(@cohort, @seating_event),
                  alert: 'No multi-day optimization found. Please create one first.'
      return
    end

    @daily_arrangements = @optimization_result[:daily_arrangements]
    @overall_metrics = @optimization_result[:overall_metrics]
    @optimization_stats = @optimization_result[:optimization_stats]
    @interaction_analysis = analyze_interactions(@optimization_result)
  end

  def calendar
    @optimization_result = load_optimization_result
    redirect_to_new_if_no_result and return
    
    @calendar_data = build_calendar_data(@optimization_result)
    @day_navigation = build_day_navigation(@optimization_result)
  end

  def interactions
    @optimization_result = load_optimization_result
    redirect_to_new_if_no_result and return
    
    @interaction_matrix = build_interaction_matrix(@optimization_result)
    @interaction_stats = calculate_interaction_statistics(@interaction_matrix)
    @network_analysis = perform_network_analysis(@optimization_result)
  end

  def optimize_async
    config = JSON.parse(params[:config] || '{}').with_indifferent_access
    
    job = MultiDayOptimizationJob.perform_later(
      @seating_event.id,
      config,
      current_user.id
    )
    
    render json: { 
      success: true, 
      job_id: job.job_id,
      status_url: optimization_status_cohort_seating_event_multi_day_optimizations_path(
        @cohort, @seating_event, job_id: job.job_id
      )
    }
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  def optimization_status
    job_id = params[:job_id]
    
    if job_id.present?
      job_status = check_job_status(job_id)
      render json: job_status
    else
      # Check for completed optimization in database
      result = load_optimization_result
      if result.present?
        render json: {
          status: 'completed',
          success: true,
          result_url: cohort_seating_event_multi_day_optimization_path(@cohort, @seating_event)
        }
      else
        render json: {
          status: 'not_found',
          success: false,
          message: 'No optimization found'
        }
      end
    end
  end

  def preview_rotation
    strategy = params[:strategy]&.to_sym || :maximum_diversity
    days_count = params[:days_count]&.to_i || 3
    
    rotation_service = RotationStrategyService.new(@seating_event)
    preview_result = rotation_service.preview_rotation_pattern(
      strategy: strategy,
      days_count: days_count
    )
    
    render json: preview_result
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  def export
    @optimization_result = load_optimization_result
    redirect_to_new_if_no_result and return

    respond_to do |format|
      format.csv do
        csv_data = generate_csv_export(@optimization_result)
        send_data csv_data, 
                  filename: "multi_day_seating_#{@seating_event.name.parameterize}_#{Date.current}.csv",
                  type: 'text/csv'
      end
      
      format.json do
        render json: @optimization_result
      end
      
      format.pdf do
        pdf_data = generate_pdf_export(@optimization_result)
        send_data pdf_data, 
                  filename: "multi_day_seating_#{@seating_event.name.parameterize}_#{Date.current}.pdf",
                  type: 'application/pdf'
      end
    end
  end

  def analytics
    @optimization_result = load_optimization_result
    redirect_to_new_if_no_result and return
    
    @analytics = MultiDayAnalyticsService.new(@seating_event, @optimization_result).generate_comprehensive_report
    
    respond_to do |format|
      format.html
      format.json { render json: @analytics }
    end
  end

  def day_arrangement
    day_number = params[:day_number].to_i
    @optimization_result = load_optimization_result
    redirect_to_new_if_no_result and return
    
    @day_arrangement = @optimization_result[:daily_arrangements][day_number]
    @day_metrics = @optimization_result[:daily_metrics][day_number]
    @day_number = day_number
    
    render partial: 'day_arrangement_details'
  end

  def update_day_arrangement
    day_number = params[:day_number].to_i
    arrangement_updates = params[:arrangement_updates]
    
    # Load current optimization result
    optimization_result = load_optimization_result
    redirect_to_new_if_no_result and return unless optimization_result
    
    # Apply manual updates to the specific day
    updated_arrangement = apply_manual_updates(
      optimization_result[:daily_arrangements][day_number],
      arrangement_updates
    )
    
    # Recalculate metrics for the updated day
    recalculated_result = recalculate_day_metrics(optimization_result, day_number, updated_arrangement)
    
    # Save updated arrangement
    save_updated_optimization(recalculated_result)
    
    render json: {
      success: true,
      updated_arrangement: updated_arrangement,
      updated_metrics: recalculated_result[:daily_metrics][day_number]
    }
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  def bulk_optimize
    bulk_config = params[:bulk_config]
    selected_events = params[:selected_event_ids] || []
    
    jobs = []
    
    selected_events.each do |event_id|
      event = @cohort.seating_events.find(event_id)
      next unless event.multi_day?
      
      job = MultiDayOptimizationJob.perform_later(
        event.id,
        bulk_config,
        current_user.id
      )
      jobs << { event_id: event.id, job_id: job.job_id }
    end
    
    render json: {
      success: true,
      jobs: jobs,
      message: "Started optimization for #{jobs.count} events"
    }
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  private

  def set_cohort
    @cohort = current_user.cohorts.find(params[:cohort_id])
  end

  def set_seating_event
    @seating_event = @cohort.seating_events.find(params[:seating_event_id])
  end

  def check_multi_day_event
    unless @seating_event.multi_day? || @seating_event.workshop?
      redirect_to cohort_seating_event_path(@cohort, @seating_event),
                  alert: 'Multi-day optimization is only available for multi-day and workshop events.'
    end
  end

  def multi_day_params
    params.require(:multi_day_config).permit(
      :rotation_strategy,
      :max_runtime_per_day,
      :total_days,
      :allow_manual_adjustments,
      :optimization_priority,
      days_config: [
        :day_number,
        :day_name,
        :special_constraints,
        absent_student_ids: [],
        constraints: [],
        preferences: []
      ],
      advanced_options: [
        :interaction_penalty_weight,
        :diversity_weight,
        :stability_weight,
        :geographic_weight
      ]
    )
  end

  def build_default_config
    base_date = @seating_event.event_date
    student_count = @seating_event.cohort.students.count
    
    {
      rotation_strategy: 'maximum_diversity',
      max_runtime_per_day: 20,
      total_days: 3,
      allow_manual_adjustments: true,
      optimization_priority: 'diversity',
      days_config: (1..3).map do |day_num|
        {
          day_number: day_num,
          day_name: "Day #{day_num}",
          special_constraints: '',
          absent_student_ids: [],
          constraints: [],
          preferences: []
        }
      end,
      advanced_options: {
        interaction_penalty_weight: 2.0,
        diversity_weight: 1.0,
        stability_weight: 0.5,
        geographic_weight: 0.3
      }
    }.with_indifferent_access
  end

  def calculate_available_days
    max_days = [(@seating_event.cohort.students.count / 4), 10].min
    (2..max_days).to_a
  end

  def validate_multi_day_config(config)
    @validation_errors = []
    
    # Basic validations
    if config[:total_days].to_i < 2
      @validation_errors << "Multi-day events must have at least 2 days"
    end
    
    if config[:total_days].to_i > 10
      @validation_errors << "Multi-day events are limited to 10 days maximum"
    end
    
    if config[:max_runtime_per_day].to_i < 5
      @validation_errors << "Runtime per day must be at least 5 seconds"
    end
    
    # Validate days configuration
    days_config = config[:days_config] || []
    if days_config.length != config[:total_days].to_i
      @validation_errors << "Number of day configurations must match total days"
    end
    
    # Check for valid rotation strategy
    unless RotationStrategyService::ROTATION_STRATEGIES.key?(config[:rotation_strategy].to_sym)
      @validation_errors << "Invalid rotation strategy selected"
    end
    
    @validation_errors.empty?
  end

  def load_optimization_result
    # Try to load from cache/session first, then from database
    result = session[:multi_day_optimization_result]
    return result if result.present?
    
    # Load from database if available (would need a model to store this)
    latest_arrangement = @seating_event.seating_arrangements
                                        .where('optimization_scores @> ?', { multi_day: true }.to_json)
                                        .order(created_at: :desc)
                                        .first
    
    if latest_arrangement
      reconstruct_optimization_result_from_db(latest_arrangement)
    else
      nil
    end
  end

  def reconstruct_optimization_result_from_db(arrangement)
    # Reconstruct the optimization result format from database records
    # This would need proper implementation based on how we store multi-day results
    {
      success: true,
      daily_arrangements: { 1 => arrangement.arrangement_data },
      daily_metrics: { 1 => arrangement.diversity_metrics },
      overall_metrics: arrangement.optimization_scores,
      optimization_stats: arrangement.optimization_scores
    }
  end

  def analyze_interactions(optimization_result)
    service = MultiDayOptimizationService.new(@seating_event)
    service.analyze_interaction_patterns(optimization_result)
  end

  def build_calendar_data(optimization_result)
    calendar_data = {}
    
    optimization_result[:daily_arrangements].each do |day_number, arrangement|
      calendar_data[day_number] = {
        tables: arrangement,
        metrics: optimization_result[:daily_metrics][day_number],
        date: @seating_event.event_date + (day_number - 1).days
      }
    end
    
    calendar_data
  end

  def build_day_navigation(optimization_result)
    days = optimization_result[:daily_arrangements].keys.sort
    
    days.map do |day_num|
      {
        day_number: day_num,
        day_name: "Day #{day_num}",
        date: @seating_event.event_date + (day_num - 1).days,
        metrics_summary: summarize_day_metrics(optimization_result[:daily_metrics][day_num])
      }
    end
  end

  def build_interaction_matrix(optimization_result)
    InteractionTracking.interaction_matrix_for_event(@seating_event)
  end

  def calculate_interaction_statistics(interaction_matrix)
    total_pairs = interaction_matrix.keys.count
    strong_relationships = interaction_matrix.values.count { |data| data[:strength] == :high }
    medium_relationships = interaction_matrix.values.count { |data| data[:strength] == :medium }
    
    {
      total_unique_interactions: total_pairs,
      strong_relationships: strong_relationships,
      medium_relationships: medium_relationships,
      weak_relationships: total_pairs - strong_relationships - medium_relationships,
      average_interaction_frequency: interaction_matrix.values.map { |data| data[:count] }.sum.to_f / total_pairs
    }
  end

  def perform_network_analysis(optimization_result)
    # Placeholder for social network analysis
    # This would analyze the interaction patterns and identify:
    # - Central/popular students
    # - Isolated students
    # - Cliques or groups
    # - Network density
    {
      network_density: 0.75,
      most_connected_students: [],
      least_connected_students: [],
      identified_clusters: []
    }
  end

  def check_job_status(job_id)
    # This would integrate with whatever job backend is being used (Sidekiq, etc.)
    # For now, return a placeholder
    {
      status: 'processing',
      progress: 60,
      message: 'Optimizing day 2 of 3...',
      estimated_completion: 45.seconds.from_now
    }
  end

  def generate_csv_export(optimization_result)
    CSV.generate(headers: true) do |csv|
      # Headers
      csv << ['Day', 'Table', 'Student Name', 'Student ID', 'Seat Position']
      
      # Data rows
      optimization_result[:daily_arrangements].each do |day_number, arrangement|
        arrangement.each do |table_number, students|
          students.each_with_index do |student, seat_index|
            csv << [
              "Day #{day_number}",
              "Table #{table_number}",
              student.name,
              student.id,
              seat_index + 1
            ]
          end
        end
      end
    end
  end

  def generate_pdf_export(optimization_result)
    # Placeholder for PDF generation
    # This would use a gem like Prawn to generate a formatted PDF
    "PDF export not yet implemented"
  end

  def apply_manual_updates(arrangement, updates)
    # Apply manual student movement updates to arrangement
    updated_arrangement = arrangement.deep_dup
    
    updates.each do |update|
      student_id = update[:student_id].to_i
      from_table = update[:from_table].to_i
      to_table = update[:to_table].to_i
      
      # Find and remove student from old table
      student = updated_arrangement[from_table]&.find { |s| s.id == student_id }
      next unless student
      
      updated_arrangement[from_table].delete(student)
      
      # Add student to new table
      updated_arrangement[to_table] ||= []
      updated_arrangement[to_table] << student
    end
    
    updated_arrangement
  end

  def recalculate_day_metrics(optimization_result, day_number, updated_arrangement)
    # Recalculate metrics for the updated day
    calculator = DiversityCalculator.new
    updated_metrics = calculator.calculate_detailed_metrics(updated_arrangement, @seating_event)
    
    result = optimization_result.deep_dup
    result[:daily_arrangements][day_number] = updated_arrangement
    result[:daily_metrics][day_number] = updated_metrics
    
    # Recalculate overall metrics
    result[:overall_metrics] = recalculate_overall_metrics(result[:daily_arrangements], result[:daily_metrics])
    
    result
  end

  def recalculate_overall_metrics(daily_arrangements, daily_metrics)
    # Recalculate overall metrics from updated daily data
    daily_scores = daily_metrics.values.map { |metrics| metrics[:overall_score] || 0 }
    
    {
      average_daily_score: daily_scores.sum / daily_scores.length.to_f,
      days_optimized: daily_arrangements.keys.count
    }
  end

  def save_updated_optimization(optimization_result)
    # Save the updated optimization result
    session[:multi_day_optimization_result] = optimization_result
    
    # Also save to database if needed
    # This would create/update the appropriate database records
  end

  def summarize_day_metrics(day_metrics)
    return {} unless day_metrics
    
    {
      overall_score: day_metrics[:overall_score]&.round(2) || 0,
      diversity_score: day_metrics[:diversity_score]&.round(2) || 0,
      interactions_count: day_metrics[:interactions_count] || 0
    }
  end

  def redirect_to_new_if_no_result
    if @optimization_result.blank?
      redirect_to new_cohort_seating_event_multi_day_optimization_path(@cohort, @seating_event),
                  alert: 'No multi-day optimization found. Please create one first.'
    end
  end
end