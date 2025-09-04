# frozen_string_literal: true

class SeatingOptimizationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_seating_event
  before_action :ensure_event_access

  def new
    @optimization_params = {
      strategy: 'simulated_annealing',
      max_runtime: 30,
      weights: default_diversity_weights,
      strategy_params: default_strategy_params
    }
    
    @available_strategies = {
      'random_swap' => 'Random Swap (Basic)',
      'simulated_annealing' => 'Simulated Annealing (Recommended)',
      'genetic_algorithm' => 'Genetic Algorithm (Advanced)'
    }
    
    @students_count = @seating_event.cohort.students.count
    @tables_info = calculate_table_distribution
  end

  def create
    optimization_service = SeatingOptimizationService.new(@seating_event, optimization_params)
    
    begin
      @results = optimization_service.optimize(
        strategy: params[:strategy]&.to_sym || :simulated_annealing,
        max_runtime: params[:max_runtime]&.to_i&.seconds || 30.seconds
      )
      
      if @results[:success]
        # Save the optimized arrangement
        @seating_arrangement = optimization_service.save_arrangement(@results, current_user)
        
        if @seating_arrangement
          flash[:success] = "Seating arrangement optimized successfully! " \
                           "Score: #{(@results[:score] * 100).round(1)}% " \
                           "(#{@results[:optimization_stats][:improvements]} improvements)"
          redirect_to seating_optimization_path(@seating_event, @seating_arrangement)
        else
          flash[:error] = "Failed to save the optimized arrangement."
          render :new
        end
      else
        flash[:error] = @results[:error] || "Optimization failed."
        render :new
      end
    rescue StandardError => e
      Rails.logger.error "Optimization error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      flash[:error] = "An error occurred during optimization: #{e.message}"
      render :new
    end
  end

  def show
    @seating_arrangement = @seating_event.seating_arrangements.find(params[:id])
    @table_assignments = @seating_arrangement.table_assignments.includes(:student).order(:table_number, :seat_position)
    
    # Recalculate metrics for display
    arrangement_data = build_arrangement_from_assignments(@table_assignments)
    calculator = DiversityCalculator.new
    @diversity_metrics = calculator.calculate_detailed_metrics(arrangement_data, @seating_event)
    @overall_score = calculator.calculate_total_score(arrangement_data, @seating_event)
    
    # Constraint evaluation
    constraint_evaluator = ConstraintEvaluator.new(@seating_event)
    @constraint_violations = constraint_evaluator.evaluate(arrangement_data)
    
    @tables_data = prepare_tables_data(@table_assignments, @diversity_metrics)
  end

  def compare
    arrangement_ids = params[:arrangement_ids] || [@seating_event.seating_arrangements.recent.limit(3).pluck(:id)].flatten
    @arrangements = @seating_event.seating_arrangements.where(id: arrangement_ids).includes(:table_assignments)
    
    @comparison_data = @arrangements.map do |arrangement|
      arrangement_data = build_arrangement_from_assignments(arrangement.table_assignments)
      calculator = DiversityCalculator.new
      
      {
        arrangement: arrangement,
        score: calculator.calculate_total_score(arrangement_data, @seating_event),
        metrics: calculator.calculate_detailed_metrics(arrangement_data, @seating_event),
        violations: ConstraintEvaluator.new(@seating_event).evaluate(arrangement_data)
      }
    end.sort_by { |data| -data[:score] }
  end

  def optimize_async
    # Trigger background optimization job
    optimization_job = SeatingOptimizationJob.perform_later(
      @seating_event.id,
      current_user.id,
      optimization_params
    )
    
    render json: {
      success: true,
      job_id: optimization_job.job_id,
      message: "Optimization started in background. You will be notified when complete."
    }
  end

  def optimization_status
    # Check the status of a background optimization job
    job_id = params[:job_id]
    # This would require implementing job status tracking
    # For now, return a placeholder response
    render json: {
      status: 'processing',
      progress: rand(10..90),
      message: 'Optimization in progress...'
    }
  end

  def export
    @seating_arrangement = @seating_event.seating_arrangements.find(params[:id])
    @table_assignments = @seating_arrangement.table_assignments.includes(:student).order(:table_number, :seat_position)
    
    respond_to do |format|
      format.csv do
        send_data generate_csv_export(@table_assignments), 
                  filename: "seating_arrangement_#{@seating_event.name}_#{Date.current}.csv"
      end
      format.pdf do
        render pdf: "seating_arrangement_#{@seating_event.name}",
               layout: 'pdf',
               template: 'seating_optimizations/export_pdf'
      end
    end
  end

  private

  def set_seating_event
    @seating_event = SeatingEvent.find(params[:seating_event_id])
  end

  def ensure_event_access
    # Ensure user has access to this seating event
    unless @seating_event.cohort.user == current_user || current_user.admin?
      flash[:error] = "You don't have permission to access this seating event."
      redirect_to root_path
    end
  end

  def optimization_params
    return {} unless params[:optimization_params]
    
    permitted = params.require(:optimization_params).permit(
      :strategy,
      :max_runtime,
      weights: [
        :agency_diversity,
        :geographic_diversity, 
        :role_diversity,
        :gender_diversity,
        :experience_diversity,
        :interaction_history
      ],
      strategy_params: [
        # Random Swap params
        :swap_probability,
        :move_probability,
        :shuffle_probability,
        
        # Simulated Annealing params
        :initial_temperature,
        :cooling_rate,
        :min_temperature,
        
        # Genetic Algorithm params
        :population_size,
        :mutation_rate,
        :crossover_rate,
        :elite_size
      ]
    )
    
    # Convert string values to appropriate types
    if permitted[:weights]
      permitted[:weights] = permitted[:weights].transform_values(&:to_f)
    end
    
    if permitted[:strategy_params]
      permitted[:strategy_params] = permitted[:strategy_params].transform_values do |v|
        v.to_s.match?(/^\d*\.?\d+$/) ? v.to_f : v
      end
    end
    
    permitted.to_h
  end

  def default_diversity_weights
    {
      agency_diversity: 0.25,
      geographic_diversity: 0.20,
      role_diversity: 0.20,
      gender_diversity: 0.15,
      experience_diversity: 0.10,
      interaction_history: 0.10
    }
  end

  def default_strategy_params
    {
      simulated_annealing: {
        initial_temperature: 100.0,
        cooling_rate: 0.95,
        min_temperature: 0.01
      },
      genetic_algorithm: {
        population_size: 20,
        mutation_rate: 0.1,
        crossover_rate: 0.8,
        elite_size: 4
      },
      random_swap: {
        swap_probability: 0.8,
        move_probability: 0.15,
        shuffle_probability: 0.05
      }
    }
  end

  def calculate_table_distribution
    total_students = @seating_event.cohort.students.count
    table_size = @seating_event.table_size
    total_tables = @seating_event.total_tables
    
    students_per_table = total_students / total_tables
    remainder = total_students % total_tables
    
    {
      total_students: total_students,
      total_tables: total_tables,
      target_table_size: table_size,
      avg_students_per_table: students_per_table,
      tables_with_extra: remainder,
      capacity_utilization: (total_students.to_f / (total_tables * table_size) * 100).round(1)
    }
  end

  def build_arrangement_from_assignments(table_assignments)
    arrangement = {}
    
    table_assignments.group_by(&:table_number).each do |table_number, assignments|
      arrangement[table_number] = assignments.sort_by(&:seat_position).map(&:student)
    end
    
    arrangement
  end

  def prepare_tables_data(table_assignments, diversity_metrics)
    tables_data = {}
    
    table_assignments.group_by(&:table_number).each do |table_number, assignments|
      students = assignments.sort_by(&:seat_position).map(&:student)
      table_metrics = diversity_metrics.dig(:by_table, "table_#{table_number}") || {}
      
      tables_data[table_number] = {
        students: students,
        assignments: assignments,
        metrics: table_metrics,
        size: students.size,
        diversity_score: table_metrics.values.map { |m| m[:score] }.sum / [table_metrics.size, 1].max
      }
    end
    
    tables_data.sort.to_h
  end

  def generate_csv_export(table_assignments)
    CSV.generate(headers: true) do |csv|
      csv << ['Table Number', 'Seat Position', 'Student Name', 'Title', 'Organization', 'Location']
      
      table_assignments.each do |assignment|
        student = assignment.student
        csv << [
          assignment.table_number,
          assignment.seat_position,
          student.name,
          student.title,
          student.organization,
          student.location
        ]
      end
    end
  end
end