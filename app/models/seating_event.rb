class SeatingEvent < ApplicationRecord
  # Associations
  belongs_to :cohort
  has_many :seating_arrangements, dependent: :destroy
  has_many :seating_instructions, dependent: :destroy
  has_many :seating_rules, dependent: :destroy
  has_many :natural_language_instructions, dependent: :destroy
  has_many :interaction_trackings, dependent: :destroy

  # Enums
  enum :event_type, {
    single_day: 0,
    multi_day: 1,
    workshop: 2
  }

  # Validations
  validates :name, presence: true, length: { maximum: 255 }
  validates :event_type, presence: true
  validates :event_date, presence: true
  validates :table_size, presence: true, numericality: { greater_than: 2, less_than_or_equal_to: 8 }
  validates :total_tables, presence: true, numericality: { greater_than: 0 }

  # Callbacks
  before_validation :set_defaults, on: :create

  # Scopes
  scope :by_cohort, ->(cohort) { where(cohort: cohort) }
  scope :upcoming, -> { where('event_date >= ?', Date.current) }
  scope :past, -> { where('event_date < ?', Date.current) }
  scope :today, -> { where(event_date: Date.current) }

  # Instance methods
  def max_students_capacity
    table_size * total_tables
  end

  def current_arrangement
    seating_arrangements.order(created_at: :desc).first
  end

  def has_arrangement?
    seating_arrangements.exists?
  end

  def students_assigned
    current_arrangement&.table_assignments&.count || 0
  end

  def utilization_percentage
    return 0 if max_students_capacity.zero?
    (students_assigned.to_f / max_students_capacity * 100).round(1)
  end

  def upcoming?
    event_date >= Date.current
  end

  def past?
    event_date < Date.current
  end

  def today?
    event_date == Date.current
  end

  private

  def set_defaults
    self.table_size ||= ENV.fetch('CHDS_DEFAULT_TABLE_SIZE', 4).to_i
    self.event_type ||= :single_day
  end
end
