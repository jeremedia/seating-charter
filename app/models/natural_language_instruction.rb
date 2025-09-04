class NaturalLanguageInstruction < ApplicationRecord
  belongs_to :seating_event
  belongs_to :created_by, class_name: 'User'

  # Status constants
  PARSING_STATUSES = %w[
    pending
    processing
    completed
    failed
    needs_review
  ].freeze

  # Validations
  validates :instruction_text, presence: true, length: { minimum: 5 }
  validates :parsing_status, inclusion: { in: PARSING_STATUSES }
  validates :confidence_score, numericality: { in: 0.0..1.0 }

  # Scopes
  scope :completed, -> { where(parsing_status: 'completed') }
  scope :pending, -> { where(parsing_status: 'pending') }
  scope :failed, -> { where(parsing_status: 'failed') }
  scope :needs_review, -> { where(parsing_status: 'needs_review') }
  scope :high_confidence, -> { where('confidence_score >= ?', 0.8) }

  # State machine methods
  def mark_as_processing!
    update!(parsing_status: 'processing')
  end

  def mark_as_completed!(parsed_rules, ai_interpretation, confidence)
    update!(
      parsing_status: 'completed',
      parsed_rules: parsed_rules,
      ai_interpretation: ai_interpretation,
      confidence_score: confidence,
      error_message: nil
    )
  end

  def mark_as_failed!(error_message)
    update!(
      parsing_status: 'failed',
      error_message: error_message
    )
  end

  def mark_as_needs_review!(reason)
    update!(
      parsing_status: 'needs_review',
      error_message: reason
    )
  end

  # Status checks
  def pending?
    parsing_status == 'pending'
  end

  def processing?
    parsing_status == 'processing'
  end

  def completed?
    parsing_status == 'completed'
  end

  def failed?
    parsing_status == 'failed'
  end

  def needs_review?
    parsing_status == 'needs_review'
  end

  # Confidence helpers
  def confidence_level
    case confidence_score
    when 0.9..1.0
      'high'
    when 0.7..0.89
      'medium'
    when 0.5..0.69
      'low'
    else
      'very_low'
    end
  end

  def confidence_color_class
    case confidence_level
    when 'high'
      'text-green-600'
    when 'medium'
      'text-yellow-600'
    when 'low'
      'text-orange-600'
    else
      'text-red-600'
    end
  end

  def status_color_class
    case parsing_status
    when 'completed'
      'text-green-600 bg-green-50'
    when 'processing'
      'text-blue-600 bg-blue-50'
    when 'pending'
      'text-gray-600 bg-gray-50'
    when 'failed'
      'text-red-600 bg-red-50'
    when 'needs_review'
      'text-yellow-600 bg-yellow-50'
    else
      'text-gray-600 bg-gray-50'
    end
  end

  # Parsed rules helpers
  def rule_count
    parsed_rules&.length || 0
  end

  def has_rules?
    rule_count > 0
  end
end
