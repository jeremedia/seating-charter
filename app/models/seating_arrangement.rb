class SeatingArrangement < ApplicationRecord
  belongs_to :seating_event
  belongs_to :created_by, class_name: 'User'
  belongs_to :last_modified_by, class_name: 'User', optional: true
  belongs_to :locked_by, class_name: 'User', optional: true
  has_many :table_assignments, dependent: :destroy
  
  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_event, ->(event) { where(seating_event: event) }
  scope :with_good_scores, -> { where('(optimization_scores->>''final_score'')::float >= ?', 0.7) }
  scope :with_explanations, -> { where.not(explanation_data: {}) }
  scope :multi_day, -> { where.not(day_number: nil) }
  scope :single_day, -> { where(day_number: nil) }
  scope :for_day, ->(day_number) { where(day_number: day_number) }
  scope :by_day_order, -> { order(:day_number, :created_at) }
  
  # Validations
  validates :arrangement_data, presence: true
  validates :diversity_metrics, presence: true
  validates :day_number, uniqueness: { scope: :seating_event_id }, allow_nil: true
  
  # Callbacks
  after_create :generate_explanations_async, if: -> { should_generate_explanations? }
  
  def overall_score
    return 0.0 unless optimization_scores&.dig('final_score')
    optimization_scores['final_score'].to_f
  end
  
  def formatted_score
    "#{(overall_score * 100).round(1)}%"
  end
  
  def optimization_strategy
    optimization_scores&.dig('strategy')&.humanize || 'Unknown'
  end
  
  def total_improvements
    optimization_scores&.dig('improvements') || 0
  end
  
  def runtime_seconds
    optimization_scores&.dig('runtime')&.to_f || 0.0
  end
  
  def students_count
    table_assignments.count
  end
  
  def tables_count
    table_assignments.select(:table_number).distinct.count
  end
  
  # Explanation methods
  def has_explanations?
    explanation_data.present? && explanation_data.any?
  end
  
  def explanation_summary
    return nil unless has_explanations?
    explanation_data.dig('overall_summary') || 'Explanations available'
  end
  
  def student_explanation(student)
    return nil unless has_explanations?
    student_id = student.is_a?(Student) ? student.id : student.to_i
    explanation_data.dig('student_explanations', student_id.to_s)
  end
  
  def table_explanation(table_number)
    return nil unless has_explanations?
    explanation_data.dig('table_explanations', table_number.to_s)
  end
  
  def diversity_explanation
    return nil unless has_explanations?
    explanation_data.dig('diversity_analysis')
  end
  
  def constraint_explanation
    return nil unless has_explanations?
    explanation_data.dig('constraint_analysis')
  end
  
  def optimization_explanation
    return nil unless has_explanations?
    explanation_data.dig('optimization_details')
  end
  
  def overall_confidence
    return 0.0 unless confidence_scores.present?
    confidence_scores.dig('overall_confidence') || 0.0
  end
  
  def table_confidence(table_number)
    return 0.0 unless confidence_scores.present?
    confidence_scores.dig('table_confidences', table_number.to_s) || 0.0
  end
  
  def student_confidence(student)
    return 0.0 unless confidence_scores.present?
    student_id = student.is_a?(Student) ? student.id : student.to_i
    confidence_scores.dig('placement_confidences', student_id.to_s) || 0.0
  end
  
  def has_decision_log?
    decision_log_data.present? && decision_log_data.any?
  end
  
  def decision_summary
    return nil unless has_decision_log?
    decision_log_data.dig('decision_summary') || 'Decision log available'
  end
  
  def generate_explanations!
    generator = ExplanationGeneratorService.new(self)
    explanations = generator.generate_complete_explanations
    
    update!(
      explanation_data: explanations,
      confidence_scores: explanations[:confidence_scores]
    )
    
    explanations
  end
  
  def regenerate_explanations!
    generate_explanations!
  end
  
  private
  
  def should_generate_explanations?
    # Only generate explanations for arrangements with decent scores
    overall_score >= 0.5 && OpenaiService.configured?
  end
  
  def generate_explanations_async
    # Queue background job to generate explanations
    ExplanationGenerationJob.perform_later(self) if defined?(ExplanationGenerationJob)
  end

  # Multi-day specific methods
  def multi_day?
    day_number.present?
  end
  
  def day_name
    if multi_day?
      multi_day_metadata&.dig('day_name') || "Day #{day_number}"
    else
      'Single Day'
    end
  end
  
  def is_part_of_multi_day_series?
    return false unless multi_day?
    seating_event.seating_arrangements.multi_day.count > 1
  end
  
  def other_days_in_series
    return SeatingArrangement.none unless multi_day?
    seating_event.seating_arrangements.multi_day.where.not(id: id).by_day_order
  end
  
  def previous_day_arrangement
    return nil unless multi_day? && day_number > 1
    seating_event.seating_arrangements.for_day(day_number - 1).first
  end
  
  def next_day_arrangement
    return nil unless multi_day?
    seating_event.seating_arrangements.for_day(day_number + 1).first
  end
  
  def day_specific_constraints
    multi_day_metadata&.dig('constraints') || []
  end
  
  def rotation_strategy_used
    multi_day_metadata&.dig('rotation_strategy') || optimization_scores&.dig('strategy')
  end
  
  def interaction_novelty_score
    multi_day_metadata&.dig('interaction_novelty_score') || 0.0
  end
  
  def students_with_new_interactions_count
    multi_day_metadata&.dig('students_with_new_interactions') || 0
  end
  
  def repeated_interactions_count
    multi_day_metadata&.dig('repeated_interactions_count') || 0
  end
  
  # Class methods for multi-day analysis
  def self.multi_day_series_for_event(seating_event)
    multi_day.where(seating_event: seating_event).by_day_order
  end
  
  def self.latest_multi_day_series
    multi_day.group(:seating_event_id)
           .select('seating_event_id, MAX(created_at) as latest_created_at')
           .includes(:seating_event)
  end
  
  def self.with_day_metadata
    where.not("multi_day_metadata = '{}'::jsonb")
  end
  
  def self.average_score_for_multi_day_series(seating_event)
    arrangements = multi_day_series_for_event(seating_event)
    return 0 if arrangements.empty?
    
    total_score = arrangements.sum(&:overall_score)
    total_score / arrangements.count.to_f
  end
end
