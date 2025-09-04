class InteractionTracking < ApplicationRecord
  belongs_to :student_a, class_name: 'Student'
  belongs_to :student_b, class_name: 'Student'
  belongs_to :seating_event
  
  # Validations
  validates :interaction_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :student_a_id, uniqueness: { scope: [:student_b_id, :seating_event_id] }
  validate :different_students
  
  # Scopes
  scope :for_student, ->(student) { where('student_a_id = ? OR student_b_id = ?', student.id, student.id) }
  scope :between_students, ->(student1, student2) {
    where(
      '(student_a_id = ? AND student_b_id = ?) OR (student_a_id = ? AND student_b_id = ?)',
      student1.id, student2.id, student2.id, student1.id
    )
  }
  scope :recent, -> { where('last_interaction > ?', 30.days.ago) }
  scope :frequent, -> { where('interaction_count >= ?', 3) }
  scope :multi_day, -> { where('interaction_details IS NOT NULL') }
  scope :by_day_count, ->(count) { where('json_array_length(interaction_details) >= ?', count) }
  
  # Instance methods
  def other_student(current_student)
    current_student.id == student_a_id ? student_b : student_a
  end
  
  def increment_interaction!(day_number = nil, table_number = nil)
    self.interaction_count += 1
    self.last_interaction = Date.current
    
    # Track multi-day interaction details
    if day_number
      add_day_interaction(day_number, table_number)
    end
    
    save!
  end
  
  # Multi-day specific methods
  def interaction_days
    return [] unless interaction_details.present?
    interaction_details.map { |detail| detail['day'] }.uniq.sort
  end
  
  def interactions_on_day(day_number)
    return [] unless interaction_details.present?
    interaction_details.select { |detail| detail['day'] == day_number }
  end
  
  def interaction_frequency_score
    return 0 if interaction_count.zero?
    
    # Calculate penalty based on frequency - more interactions = higher penalty for optimization
    base_penalty = interaction_count.to_f
    
    # Additional penalty if interactions happened on consecutive days
    if consecutive_day_interactions?
      base_penalty *= 1.5
    end
    
    # Normalize to 0-1 scale (higher = more penalty)
    [base_penalty / 10.0, 1.0].min
  end
  
  def consecutive_day_interactions?
    days = interaction_days
    return false if days.length < 2
    
    days.each_cons(2).any? { |day1, day2| day2 - day1 == 1 }
  end
  
  def interaction_strength
    # Calculate relationship strength based on interaction patterns
    return :none if interaction_count.zero?
    return :low if interaction_count <= 1
    return :medium if interaction_count <= 3
    :high
  end
  
  def days_since_last_interaction
    return Float::INFINITY unless last_interaction
    (Date.current - last_interaction.to_date).to_i
  end
  
  # Class methods for multi-day analysis
  def self.interaction_matrix_for_event(seating_event)
    matrix = {}
    
    where(seating_event: seating_event).includes(:student_a, :student_b).each do |interaction|
      key = [interaction.student_a_id, interaction.student_b_id].sort.join('-')
      matrix[key] = {
        students: [interaction.student_a, interaction.student_b],
        count: interaction.interaction_count,
        days: interaction.interaction_days,
        strength: interaction.interaction_strength,
        frequency_score: interaction.interaction_frequency_score,
        last_interaction: interaction.last_interaction
      }
    end
    
    matrix
  end
  
  def self.coverage_report_for_event(seating_event)
    students = seating_event.cohort.students
    total_possible_pairs = students.count * (students.count - 1) / 2
    actual_interactions = where(seating_event: seating_event).where('interaction_count > 0').count
    
    {
      total_possible_pairs: total_possible_pairs,
      actual_interactions: actual_interactions,
      coverage_percentage: (actual_interactions.to_f / total_possible_pairs * 100).round(2),
      never_interacted_pairs: total_possible_pairs - actual_interactions,
      average_interactions_per_pair: where(seating_event: seating_event).average(:interaction_count).to_f.round(2)
    }
  end
  
  def self.diversity_metrics_for_day(seating_event, day_number)
    day_interactions = where(seating_event: seating_event)
                      .where("interaction_details::jsonb @> ?", [{ day: day_number }].to_json)
    
    {
      interactions_count: day_interactions.count,
      unique_students_count: day_interactions.joins(:student_a, :student_b)
                                           .select('student_a_id, student_b_id')
                                           .map { |i| [i.student_a_id, i.student_b_id] }
                                           .flatten.uniq.count,
      average_table_diversity: calculate_table_diversity_for_day(seating_event, day_number)
    }
  end
  
  private
  
  def add_day_interaction(day_number, table_number = nil)
    self.interaction_details ||= []
    
    interaction_detail = {
      day: day_number,
      table: table_number,
      recorded_at: Time.current.iso8601
    }
    
    self.interaction_details = (interaction_details + [interaction_detail])
  end
  
  def different_students
    if student_a_id == student_b_id
      errors.add(:student_b_id, "must be different from student A")
    end
  end
  
  def self.calculate_table_diversity_for_day(seating_event, day_number)
    # This would need to query the actual seating arrangements for the specific day
    # For now, return a placeholder
    0.0
  end
end
