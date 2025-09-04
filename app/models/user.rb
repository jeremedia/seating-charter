class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Roles
  enum :role, {
    instructor: 0,
    admin: 1
  }

  # Associations
  has_many :cohorts, dependent: :destroy
  has_many :import_sessions, dependent: :destroy
  has_many :inference_feedbacks, dependent: :destroy
  has_many :cost_trackings, dependent: :destroy
  has_many :created_arrangements, class_name: 'SeatingArrangement', foreign_key: 'created_by_id', dependent: :destroy

  # Validations
  validates :role, presence: true
  
  # Callbacks
  after_initialize :set_default_role, if: :new_record?

  # Scopes
  scope :instructors, -> { where(role: :instructor) }
  scope :admins, -> { where(role: :admin) }

  # Class methods
  def self.instructor_count
    instructors.count
  end

  def self.can_add_instructor?
    instructor_count < (ENV.fetch('CHDS_MAX_INSTRUCTORS', 5).to_i)
  end

  # Instance methods
  def instructor?
    role == 'instructor'
  end

  def admin?
    role == 'admin'
  end

  def full_name
    [first_name, last_name].compact.join(' ').presence || email
  end

  private

  def set_default_role
    self.role ||= :instructor
  end
end
