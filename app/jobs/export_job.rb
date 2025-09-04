class ExportJob < ApplicationJob
  queue_as :exports

  # Retry failed jobs with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(seating_arrangement, format, export_options, user)
    Rails.logger.info "Starting export job for arrangement #{seating_arrangement.id}, format: #{format}"
    
    begin
      # Generate the export
      result = ExportService.export(seating_arrangement, format, export_options)
      
      # Store the result temporarily and send notification
      if result[:file_path] && File.exist?(result[:file_path])
        # Create a secure temporary storage entry
        export_record = create_export_record(seating_arrangement, format, result, user)
        
        # Send email notification with download link
        ExportMailer.export_ready(user, export_record).deliver_now
        
        Rails.logger.info "Export job completed successfully for arrangement #{seating_arrangement.id}"
      else
        raise "Export file was not generated successfully"
      end
      
    rescue StandardError => e
      Rails.logger.error "Export job failed for arrangement #{seating_arrangement.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Send failure notification
      ExportMailer.export_failed(user, seating_arrangement, format, e.message).deliver_now
      
      raise e # Re-raise to trigger retry logic
    end
  end

  private

  def create_export_record(seating_arrangement, format, result, user)
    # This would create a record in an ExportRecord model
    # For now, we'll create a simple hash that could be stored
    export_data = {
      id: SecureRandom.hex(16),
      seating_arrangement_id: seating_arrangement.id,
      format: format,
      filename: result[:filename],
      file_path: result[:file_path],
      content_type: result[:content_type],
      user_id: user.id,
      created_at: Time.current,
      expires_at: 24.hours.from_now # Files expire after 24 hours
    }
    
    # Store in Rails cache for temporary access
    Rails.cache.write("export_#{export_data[:id]}", export_data, expires_in: 24.hours)
    
    export_data
  end
end