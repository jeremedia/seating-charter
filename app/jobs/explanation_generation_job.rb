# frozen_string_literal: true

class ExplanationGenerationJob < ApplicationJob
  queue_as :default
  
  def perform(seating_arrangement)
    Rails.logger.info "Generating explanations for seating arrangement #{seating_arrangement.id}"
    
    begin
      # Generate explanations using the service
      seating_arrangement.generate_explanations!
      
      Rails.logger.info "Successfully generated explanations for seating arrangement #{seating_arrangement.id}"
    rescue StandardError => e
      Rails.logger.error "Failed to generate explanations for seating arrangement #{seating_arrangement.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    end
  end
end