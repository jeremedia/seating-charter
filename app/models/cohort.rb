class Cohort < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :students, dependent: :destroy
  has_many :import_sessions, dependent: :destroy
  has_many :seating_events, dependent: :destroy

  # Validations
  validates :name, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 2000 }
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :max_students, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 40 }
  validate :end_date_after_start_date

  # Callbacks
  before_validation :set_defaults, on: :create

  # Scopes
  scope :active, -> { where('start_date <= ? AND end_date >= ?', Date.current, Date.current) }
  scope :upcoming, -> { where('start_date > ?', Date.current) }
  scope :past, -> { where('end_date < ?', Date.current) }
  scope :by_instructor, ->(user) { where(user: user) }

  # Instance methods
  def active?
    Date.current.between?(start_date, end_date)
  end

  def upcoming?
    start_date > Date.current
  end

  def past?
    end_date < Date.current
  end

  def duration_in_days
    return 0 unless start_date && end_date
    (end_date - start_date).to_i + 1
  end

  def students_count
    students.count
  end

  def can_add_students?
    students_count < max_students
  end

  def available_spots
    max_students - students_count
  end

  def instructor
    user
  end

  private

  def end_date_after_start_date
    return unless start_date && end_date
    
    if end_date < start_date
      errors.add(:end_date, "must be after start date")
    end
  end

  def set_defaults
    self.max_students ||= ENV.fetch('CHDS_MAX_COHORT_SIZE', 40).to_i
  end
end
