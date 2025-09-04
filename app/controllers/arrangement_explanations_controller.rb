# frozen_string_literal: true

class ArrangementExplanationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_seating_arrangement, except: [:index]
  before_action :set_seating_event, only: [:index]
  before_action :ensure_explanations_exist, only: [:show, :table, :student, :diversity, :constraints, :export]

  # GET /seating_events/:seating_event_id/arrangements/:arrangement_id/explanations
  def show
    @explanation_data = @seating_arrangement.explanation_data
    @confidence_scores = @seating_arrangement.confidence_scores
    @decision_log = @seating_arrangement.decision_log_data
    
    # Prepare data for visualization
    @diversity_chart_data = prepare_diversity_chart_data
    @table_scores = calculate_table_scores
    @constraint_satisfaction = calculate_constraint_satisfaction
    
    respond_to do |format|
      format.html
      format.json do
        render json: {
          explanation_data: @explanation_data,
          confidence_scores: @confidence_scores,
          diversity_chart_data: @diversity_chart_data,
          table_scores: @table_scores,
          constraint_satisfaction: @constraint_satisfaction
        }
      end
    end
  end

  # GET /seating_events/:seating_event_id/arrangements/:arrangement_id/explanations/table/:table_number
  def table
    @table_number = params[:table_number].to_i
    @table_explanation = @seating_arrangement.table_explanation(@table_number)
    @table_students = get_table_students(@table_number)
    @table_confidence = @seating_arrangement.table_confidence(@table_number)
    @table_diversity = get_table_diversity_data(@table_number)
    
    respond_to do |format|
      format.html { render partial: 'table_explanation' }
      format.json do
        render json: {
          table_number: @table_number,
          explanation: @table_explanation,
          students: @table_students.map { |s| student_json(s) },
          confidence: @table_confidence,
          diversity: @table_diversity
        }
      end
    end
  end

  # GET /seating_events/:seating_event_id/arrangements/:arrangement_id/explanations/student/:student_id
  def student
    @student = Student.find(params[:student_id])
    @student_explanation = @seating_arrangement.student_explanation(@student)
    @student_confidence = @seating_arrangement.student_confidence(@student)
    @student_assignment = find_student_assignment(@student)
    @alternative_placements = generate_alternative_placements(@student)
    
    respond_to do |format|
      format.html { render partial: 'student_explanation' }
      format.json do
        render json: {
          student: student_json(@student),
          explanation: @student_explanation,
          confidence: @student_confidence,
          current_table: @student_assignment&.table_number,
          alternatives: @alternative_placements
        }
      end
    end
  end

  # GET /seating_events/:seating_event_id/arrangements/:arrangement_id/explanations/diversity
  def diversity
    @diversity_explanation = @seating_arrangement.diversity_explanation
    @diversity_metrics = @seating_arrangement.diversity_metrics
    @table_diversity_breakdown = get_all_table_diversity
    @diversity_heatmap_data = prepare_diversity_heatmap_data
    
    respond_to do |format|
      format.html { render partial: 'diversity_analysis' }
      format.json do
        render json: {
          explanation: @diversity_explanation,
          metrics: @diversity_metrics,
          table_breakdown: @table_diversity_breakdown,
          heatmap_data: @diversity_heatmap_data
        }
      end
    end
  end

  # GET /seating_events/:seating_event_id/arrangements/:arrangement_id/explanations/constraints
  def constraints
    @constraint_explanation = @seating_arrangement.constraint_explanation
    @constraint_violations = get_constraint_violations
    @constraint_satisfaction_data = prepare_constraint_satisfaction_data
    
    respond_to do |format|
      format.html { render partial: 'constraint_analysis' }
      format.json do
        render json: {
          explanation: @constraint_explanation,
          violations: @constraint_violations,
          satisfaction_data: @constraint_satisfaction_data
        }
      end
    end
  end

  # GET /seating_events/:seating_event_id/arrangements/:arrangement_id/explanations/optimization
  def optimization
    @optimization_explanation = @seating_arrangement.optimization_explanation
    @optimization_stats = @seating_arrangement.optimization_scores
    @decision_timeline = prepare_decision_timeline
    @convergence_chart_data = prepare_convergence_chart_data
    
    respond_to do |format|
      format.html { render partial: 'optimization_details' }
      format.json do
        render json: {
          explanation: @optimization_explanation,
          stats: @optimization_stats,
          decision_timeline: @decision_timeline,
          convergence_data: @convergence_chart_data
        }
      end
    end
  end

  # POST /seating_events/:seating_event_id/arrangements/:arrangement_id/explanations/generate
  def generate
    begin
      @seating_arrangement.generate_explanations!
      redirect_to seating_arrangement_explanations_path(@seating_arrangement.seating_event, @seating_arrangement),
                  notice: 'Explanations generated successfully!'
    rescue StandardError => e
      Rails.logger.error "Failed to generate explanations: #{e.message}"
      redirect_back(fallback_location: seating_arrangement_path(@seating_arrangement.seating_event, @seating_arrangement),
                    alert: 'Failed to generate explanations. Please try again.')
    end
  end

  # GET /seating_events/:seating_event_id/arrangements/:arrangement_id/explanations/export
  def export
    @export_format = params[:format] || 'pdf'
    
    case @export_format
    when 'pdf'
      export_pdf
    when 'json'
      export_json
    when 'csv'
      export_csv
    else
      redirect_back(fallback_location: seating_arrangement_explanations_path(@seating_arrangement.seating_event, @seating_arrangement),
                    alert: 'Unsupported export format')
    end
  end

  # GET /seating_events/:seating_event_id/arrangements/:arrangement_id/explanations/interactive_chart
  def interactive_chart
    @chart_type = params[:chart_type] || 'seating_chart'
    @chart_data = prepare_interactive_chart_data(@chart_type)
    
    render json: @chart_data
  end

  # GET /seating_events/:seating_event_id/arrangements/:arrangement_id/explanations/why_not
  # Explain why a student was NOT placed at a specific table
  def why_not
    @student = Student.find(params[:student_id])
    @target_table = params[:table_number].to_i
    @why_not_explanation = generate_why_not_explanation(@student, @target_table)
    
    respond_to do |format|
      format.html { render partial: 'why_not_explanation' }
      format.json do
        render json: {
          student: student_json(@student),
          target_table: @target_table,
          explanation: @why_not_explanation
        }
      end
    end
  end

  private

  def set_seating_arrangement
    @seating_arrangement = SeatingArrangement.find(params[:arrangement_id] || params[:id])
    @seating_event = @seating_arrangement.seating_event
  end

  def set_seating_event
    @seating_event = SeatingEvent.find(params[:seating_event_id])
  end

  def ensure_explanations_exist
    unless @seating_arrangement.has_explanations?
      redirect_to seating_arrangement_path(@seating_event, @seating_arrangement),
                  alert: 'Explanations have not been generated yet. Please generate them first.'
    end
  end

  def prepare_diversity_chart_data
    return {} unless @seating_arrangement.diversity_metrics.present?
    
    metrics = @seating_arrangement.diversity_metrics
    {
      labels: metrics.keys.map(&:humanize),
      data: metrics.values.map { |v| (v.to_f * 100).round(1) },
      backgroundColor: generate_colors(metrics.keys.length)
    }
  end

  def calculate_table_scores
    scores = {}
    generator = ExplanationGeneratorService.new(@seating_arrangement)
    
    @seating_arrangement.table_assignments.group(:table_number).each do |table_number, _|
      scores[table_number] = generator.send(:calculate_table_score, table_number)
    end
    
    scores
  end

  def calculate_constraint_satisfaction
    return 0.0 unless @seating_arrangement.constraint_explanation.present?
    
    constraint_data = @seating_arrangement.constraint_explanation
    constraint_data.dig('constraint_satisfaction')&.values&.map(&:to_f)&.average || 0.0
  end

  def get_table_students(table_number)
    @seating_arrangement.table_assignments
                       .includes(:student)
                       .where(table_number: table_number)
                       .map(&:student)
  end

  def get_table_diversity_data(table_number)
    generator = ExplanationGeneratorService.new(@seating_arrangement)
    generator.send(:calculate_table_diversity, table_number)
  end

  def get_all_table_diversity
    diversity_data = {}
    
    @seating_arrangement.table_assignments.group(:table_number).each do |table_number, _|
      diversity_data[table_number] = get_table_diversity_data(table_number)
    end
    
    diversity_data
  end

  def find_student_assignment(student)
    @seating_arrangement.table_assignments.find_by(student: student)
  end

  def generate_alternative_placements(student)
    # This would analyze alternative placements for the student
    # For now, return placeholder data
    [
      { table: 2, confidence: 0.85, reason: 'Better gender balance' },
      { table: 4, confidence: 0.78, reason: 'Improved diversity score' }
    ]
  end

  def prepare_diversity_heatmap_data
    heatmap_data = []
    
    @seating_arrangement.table_assignments.group(:table_number).each do |table_number, assignments|
      table_data = {
        table: table_number,
        students: assignments.count,
        diversity_score: get_table_diversity_data(table_number).values.map(&:to_f).average || 0
      }
      heatmap_data << table_data
    end
    
    heatmap_data
  end

  def get_constraint_violations
    return [] unless @seating_arrangement.constraint_explanation.present?
    
    @seating_arrangement.constraint_explanation.dig('violations') || []
  end

  def prepare_constraint_satisfaction_data
    return {} unless @seating_arrangement.constraint_explanation.present?
    
    constraint_data = @seating_arrangement.constraint_explanation
    constraint_data.dig('constraint_satisfaction') || {}
  end

  def prepare_decision_timeline
    return [] unless @seating_arrangement.has_decision_log?
    
    decision_log = @seating_arrangement.decision_log_data
    decisions = decision_log.dig('decisions') || []
    
    decisions.map do |decision|
      {
        timestamp: decision['timestamp'],
        type: decision['type']&.humanize,
        description: decision['context']&.dig('description') || "#{decision['type']&.humanize} event"
      }
    end
  end

  def prepare_convergence_chart_data
    return {} unless @seating_arrangement.has_decision_log?
    
    decision_log = @seating_arrangement.decision_log_data
    iterations = decision_log.dig('iterations') || []
    
    {
      labels: iterations.map { |i| "Iteration #{i['iteration_number']}" },
      scores: iterations.map { |i| i['current_score'] },
      improvements: iterations.select { |i| i['accepted'] && i['score_delta'] > 0 }
                              .map { |i| { x: i['iteration_number'], y: i['current_score'] } }
    }
  end

  def export_pdf
    service = ExplanationExportService.new(@seating_arrangement)
    pdf_data = service.export_to_pdf
    
    send_data pdf_data,
              filename: "seating_explanations_#{@seating_arrangement.id}.pdf",
              type: 'application/pdf',
              disposition: 'attachment'
  rescue StandardError => e
    Rails.logger.error "PDF export failed: #{e.message}"
    redirect_back(fallback_location: seating_arrangement_explanations_path(@seating_event, @seating_arrangement),
                  alert: 'PDF export failed. Please try again.')
  end

  def export_json
    data = {
      seating_arrangement: {
        id: @seating_arrangement.id,
        created_at: @seating_arrangement.created_at,
        overall_score: @seating_arrangement.overall_score
      },
      explanations: @seating_arrangement.explanation_data,
      confidence_scores: @seating_arrangement.confidence_scores,
      decision_log: @seating_arrangement.decision_log_data
    }
    
    send_data data.to_json,
              filename: "seating_explanations_#{@seating_arrangement.id}.json",
              type: 'application/json',
              disposition: 'attachment'
  end

  def export_csv
    # This would convert explanation data to CSV format
    # Implementation depends on specific CSV requirements
    csv_data = "CSV export not yet implemented"
    
    send_data csv_data,
              filename: "seating_explanations_#{@seating_arrangement.id}.csv",
              type: 'text/csv',
              disposition: 'attachment'
  end

  def prepare_interactive_chart_data(chart_type)
    case chart_type
    when 'seating_chart'
      prepare_interactive_seating_chart
    when 'diversity_heatmap'
      prepare_interactive_diversity_heatmap
    when 'constraint_network'
      prepare_constraint_network_data
    when 'decision_tree'
      prepare_decision_tree_data
    else
      { error: 'Unknown chart type' }
    end
  end

  def prepare_interactive_seating_chart
    tables = {}
    
    @seating_arrangement.table_assignments.includes(:student).group_by(&:table_number).each do |table_number, assignments|
      tables[table_number] = {
        students: assignments.map do |assignment|
          {
            id: assignment.student.id,
            name: assignment.student.display_name,
            seat_position: assignment.seat_position,
            confidence: @seating_arrangement.student_confidence(assignment.student),
            explanation_summary: @seating_arrangement.student_explanation(assignment.student)&.dig('explanation')&.truncate(100)
          }
        end,
        table_score: @table_scores[table_number] || 0,
        explanation_summary: @seating_arrangement.table_explanation(table_number)&.dig('explanation')&.truncate(100)
      }
    end
    
    {
      chart_type: 'seating_chart',
      tables: tables,
      overall_score: @seating_arrangement.overall_score,
      overall_confidence: @seating_arrangement.overall_confidence
    }
  end

  def prepare_interactive_diversity_heatmap
    {
      chart_type: 'diversity_heatmap',
      data: @diversity_heatmap_data,
      metrics: @seating_arrangement.diversity_metrics,
      color_scale: {
        min: 0,
        max: 1,
        colors: ['#ffebee', '#f44336'] # Light red to dark red
      }
    }
  end

  def prepare_constraint_network_data
    # This would create data for a network diagram showing constraint relationships
    {
      chart_type: 'constraint_network',
      nodes: [],
      edges: [],
      message: 'Constraint network visualization not yet implemented'
    }
  end

  def prepare_decision_tree_data
    # This would create data for a decision tree showing the optimization process
    {
      chart_type: 'decision_tree',
      nodes: [],
      message: 'Decision tree visualization not yet implemented'
    }
  end

  def generate_why_not_explanation(student, target_table)
    # Generate explanation for why student was not placed at target table
    generator = ExplanationGeneratorService.new(@seating_arrangement)
    current_assignment = find_student_assignment(student)
    
    if current_assignment.table_number == target_table
      return "#{student.display_name} is already seated at table #{target_table}."
    end
    
    # This would use the ExplanationGeneratorService to analyze why the placement wasn't made
    # For now, return a placeholder explanation
    "Based on the optimization algorithm, #{student.display_name} was placed at table #{current_assignment.table_number} instead of table #{target_table} to optimize overall diversity and satisfy seating constraints."
  end

  def student_json(student)
    {
      id: student.id,
      name: student.display_name,
      attributes: student.custom_attributes.pluck(:attribute_name, :attribute_value).to_h
    }
  end

  def generate_colors(count)
    # Generate distinct colors for charts
    colors = [
      '#FF6384', '#36A2EB', '#FFCE56', '#4BC0C0', '#9966FF',
      '#FF9F40', '#FF6384', '#C9CBCF', '#4BC0C0', '#FF6384'
    ]
    colors.first(count)
  end
end