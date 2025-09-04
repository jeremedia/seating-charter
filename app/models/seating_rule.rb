class SeatingRule < ApplicationRecord
  belongs_to :seating_event

  # Rule type constants
  RULE_TYPES = %w[
    separation
    clustering 
    distribution
    proximity
    custom
  ].freeze

  # Validations
  validates :rule_type, presence: true, inclusion: { in: RULE_TYPES }
  validates :natural_language_input, presence: true, length: { minimum: 5 }
  validates :priority, presence: true, numericality: { greater_than: 0 }
  validates :confidence_score, numericality: { in: 0.0..1.0 }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_type, ->(type) { where(rule_type: type) }
  scope :by_priority, -> { order(:priority) }
  scope :high_confidence, -> { where('confidence_score >= ?', 0.8) }

  # Instance methods
  def rule_description
    case rule_type
    when 'separation'
      "Keep specified groups or individuals apart"
    when 'clustering'
      "Group similar people together"
    when 'distribution'
      "Spread people evenly across tables"
    when 'proximity'
      "Place people near or far from others"
    when 'custom'
      "Custom rule with specific constraints"
    else
      "Unknown rule type"
    end
  end

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
      'text-green-600 bg-green-50'
    when 'medium'
      'text-yellow-600 bg-yellow-50'
    when 'low'
      'text-orange-600 bg-orange-50'
    else
      'text-red-600 bg-red-50'
    end
  end

  def formatted_constraints
    return {} unless constraints.present?
    
    constraints.deep_symbolize_keys
  end

  def target_fields
    return [] unless target_attributes.present?
    
    target_attributes.keys
  end

  def applies_to_student?(student)
    return true if target_attributes.blank?
    
    target_attributes.any? do |field, values|
      student_value = student.get_attribute(field) || student.get_inference_value(field)
      Array(values).include?(student_value)
    end
  end
end
