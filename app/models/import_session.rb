class ImportSession < ApplicationRecord
  # Associations
  belongs_to :cohort
  belongs_to :user
  has_many :student_import_records, dependent: :destroy

  # Enums
  enum :status, {
    pending: 0,
    processing: 1,
    completed: 2,
    failed: 3
  }

  # Validations
  validates :file_name, presence: true
  validates :file_size, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true

  # Scopes
  scope :by_cohort, ->(cohort) { where(cohort: cohort) }
  scope :by_user, ->(user) { where(user: user) }
  scope :recent, -> { order(created_at: :desc) }

  # Instance methods
  def file_size_human
    ActiveSupport::NumberHelper.number_to_human_size(file_size)
  end

  def processing_time
    return nil unless processed_at && created_at
    processed_at - created_at
  end

  def students_imported
    student_import_records.count
  end

  def success_rate
    return 0 if student_import_records.empty?
    successful_records = student_import_records.joins(:student).count
    (successful_records.to_f / student_import_records.count * 100).round(1)
  end
end
