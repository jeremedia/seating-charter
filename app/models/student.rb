class Student < ApplicationRecord
  # Associations
  belongs_to :cohort
  has_many :student_import_records, dependent: :destroy
  has_many :table_assignments, dependent: :destroy
  has_many :seating_arrangements, through: :table_assignments
  has_many :student_a_interactions, class_name: 'InteractionTracking', foreign_key: 'student_a_id', dependent: :destroy
  has_many :student_b_interactions, class_name: 'InteractionTracking', foreign_key: 'student_b_id', dependent: :destroy

  # Validations
  validates :name, presence: true, length: { maximum: 255 }
  validates :title, length: { maximum: 500 }
  validates :organization, length: { maximum: 500 }
  validates :location, length: { maximum: 255 }

  # Callbacks
  before_save :normalize_data

  # Scopes
  scope :by_cohort, ->(cohort) { where(cohort: cohort) }
  scope :with_attribute, ->(attr_name, value) { where("student_attributes->>'#{attr_name}' = ?", value) }
  scope :with_inference, ->(field, value) { where("inferences->>'#{field}' @> ?", { value: value }.to_json) }

  # Instance methods
  def full_name
    name
  end

  def display_organization
    organization.present? ? organization : 'Unknown Organization'
  end

  def display_location
    location.present? ? location : 'Unknown Location'
  end

  def get_attribute(attr_name)
    student_attributes&.dig(attr_name)
  end

  def set_attribute(attr_name, value)
    self.student_attributes ||= {}
    self.student_attributes[attr_name] = value
  end

  def get_inference(field)
    inferences&.dig(field)
  end

  def get_inference_value(field)
    get_inference(field)&.dig('value')
  end

  def get_inference_confidence(field)
    get_inference(field)&.dig('confidence')&.to_f || 0.0
  end

  def set_inference(field, value, confidence = nil)
    self.inferences ||= {}
    self.inferences[field] = { 'value' => value }
    self.inferences[field]['confidence'] = confidence if confidence
  end

  def high_confidence_inferences
    return [] unless inferences
    
    inferences.select do |field, data|
      data.is_a?(Hash) && data['confidence'].to_f >= 0.9
    end
  end

  def low_confidence_inferences
    return [] unless inferences
    
    inferences.select do |field, data|
      data.is_a?(Hash) && data['confidence'].to_f < 0.7
    end
  end

  def confidence_score(field)
    get_inference_confidence(field)
  end

  def confidence_color_class(field)
    confidence = get_inference_confidence(field)
    case confidence
    when 0.9..1.0
      'text-green-600'
    when 0.7..0.89
      'text-yellow-600'
    else
      'text-red-600'
    end
  end

  # Core inference fields based on specification
  def gender
    get_inference_value('gender')
  end

  def gender_confidence
    get_inference_confidence('gender')
  end

  def agency_level
    get_inference_value('agency_level')
  end

  def agency_level_confidence
    get_inference_confidence('agency_level')
  end

  def department_type
    get_inference_value('department_type')
  end

  def department_type_confidence
    get_inference_confidence('department_type')
  end

  def seniority_level
    get_inference_value('seniority_level')
  end

  def seniority_level_confidence
    get_inference_confidence('seniority_level')
  end

  def all_interactions
    InteractionTracking.where(
      '(student_a_id = :id OR student_b_id = :id) AND cohort_id = :cohort_id',
      id: id, cohort_id: cohort_id
    )
  end

  private

  def normalize_data
    self.name = name&.strip&.titleize
    self.organization = organization&.strip
    self.location = location&.strip
    self.title = title&.strip
  end
end
