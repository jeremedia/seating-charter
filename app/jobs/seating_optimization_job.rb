# frozen_string_literal: true

class SeatingOptimizationJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(seating_event_id, user_id, optimization_params = {})
    seating_event = SeatingEvent.find(seating_event_id)
    user = User.find(user_id)
    
    Rails.logger.info "Starting background seating optimization for event #{seating_event_id}"
    
    # Track job progress (would require additional infrastructure for real-time updates)
    update_progress(0, "Initializing optimization...")
    
    begin
      # Initialize optimization service
      optimization_service = SeatingOptimizationService.new(seating_event, optimization_params)
      
      update_progress(10, "Setting up optimization parameters...")
      
      # Extract parameters
      strategy = optimization_params[:strategy]&.to_sym || :simulated_annealing
      max_runtime = optimization_params[:max_runtime]&.to_i&.seconds || 30.seconds
      
      update_progress(20, "Starting #{strategy} optimization...")
      
      # Run optimization with progress tracking
      results = optimization_service.optimize(strategy: strategy, max_runtime: max_runtime)
      
      update_progress(80, "Saving optimized arrangement...")
      
      if results[:success]
        # Save the arrangement
        seating_arrangement = optimization_service.save_arrangement(results, user)
        
        if seating_arrangement
          update_progress(100, "Optimization completed successfully!")
          
          # Send notification (would require notification system)
          notify_user_of_completion(user, seating_event, seating_arrangement, results)
          
          Rails.logger.info "Background optimization completed successfully for event #{seating_event_id}"
        else
          update_progress(100, "Failed to save arrangement")
          notify_user_of_error(user, seating_event, "Failed to save the optimized arrangement")
          Rails.logger.error "Failed to save optimized arrangement for event #{seating_event_id}"
        end
      else
        update_progress(100, "Optimization failed")
        notify_user_of_error(user, seating_event, results[:error] || "Optimization failed")
        Rails.logger.error "Optimization failed for event #{seating_event_id}: #{results[:error]}"
      end
      
    rescue StandardError => e
      update_progress(100, "Error during optimization")
      notify_user_of_error(user, seating_event, "An error occurred: #{e.message}")
      Rails.logger.error "Error in background optimization for event #{seating_event_id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    end
  end

  private

  def update_progress(percentage, message)
    # In a real implementation, this would update a job status record
    # or broadcast to a WebSocket channel for real-time UI updates
    Rails.logger.info "Optimization Progress: #{percentage}% - #{message}"
    
    # Example: Update job status in Redis or database
    # Rails.cache.write("optimization_job_#{job_id}", {
    #   status: percentage == 100 ? 'completed' : 'processing',
    #   progress: percentage,
    #   message: message,
    #   updated_at: Time.current
    # }, expires_in: 1.hour)
  end

  def notify_user_of_completion(user, seating_event, seating_arrangement, results)
    # This would send an email, push notification, or in-app notification
    Rails.logger.info "Sending completion notification to user #{user.id}"
    
    # Example email notification:
    # OptimizationMailer.optimization_completed(
    #   user: user,
    #   seating_event: seating_event,
    #   seating_arrangement: seating_arrangement,
    #   score: results[:score],
    #   improvements: results[:optimization_stats][:improvements]
    # ).deliver_now
    
    # Example in-app notification:
    # user.notifications.create!(
    #   title: "Seating Optimization Complete",
    #   message: "Your seating arrangement for '#{seating_event.name}' has been optimized with a score of #{(results[:score] * 100).round(1)}%",
    #   notification_type: 'optimization_complete',
    #   data: {
    #     seating_event_id: seating_event.id,
    #     seating_arrangement_id: seating_arrangement.id,
    #     score: results[:score]
    #   }
    # )
  end

  def notify_user_of_error(user, seating_event, error_message)
    # This would send an error notification
    Rails.logger.info "Sending error notification to user #{user.id}"
    
    # Example error notification:
    # user.notifications.create!(
    #   title: "Seating Optimization Failed",
    #   message: "Optimization for '#{seating_event.name}' failed: #{error_message}",
    #   notification_type: 'optimization_error',
    #   data: {
    #     seating_event_id: seating_event.id,
    #     error: error_message
    #   }
    # )
  end
end