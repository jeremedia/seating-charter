class AiConfiguration < ApplicationRecord
  # Validations
  validates :ai_model_name, presence: true
  validates :temperature, presence: true, numericality: { in: 0.0..2.0 }
  validates :max_tokens, presence: true, numericality: { greater_than: 0 }
  validates :batch_size, presence: true, numericality: { greater_than: 0 }
  validates :retry_attempts, presence: true, numericality: { greater_than: 0 }
  validates :cost_per_token, presence: true, numericality: { greater_than: 0 }
  
  # Ensure only one active configuration at a time
  validate :only_one_active_configuration
  
  # Scopes
  scope :active, -> { where(active: true) }
  
  # Callbacks
  before_save :deactivate_others_if_active
  
  # Class methods
  def self.active_configuration
    active.first
  end
  
  def self.available_models
    [
      'gpt-4o',
      'gpt-4o-mini', 
      'gpt-4-turbo',
      'gpt-4',
      'gpt-3.5-turbo',
      'gpt-3.5-turbo-16k'
    ]
  end
  
  # Instance methods
  def display_name
    "#{ai_model_name} (#{active? ? 'Active' : 'Inactive'})"
  end
  
  def estimated_cost_per_request(tokens = 1000)
    (tokens * cost_per_token).round(4)
  end
  
  private
  
  def only_one_active_configuration
    if active? && AiConfiguration.where(active: true).where.not(id: id).exists?
      errors.add(:active, "There can only be one active configuration")
    end
  end
  
  def deactivate_others_if_active
    if active_changed? && active?
      AiConfiguration.where.not(id: id).update_all(active: false)
    end
  end
end
