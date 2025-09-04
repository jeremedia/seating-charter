class EmailExportJob < ApplicationJob
  queue_as :exports

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(seating_arrangement, format, export_options, recipient_email, user)
    Rails.logger.info "Starting email export job for arrangement #{seating_arrangement.id} to #{recipient_email}"
    
    begin
      # Generate the export
      result = ExportService.export(seating_arrangement, format, export_options)
      
      if result[:file_path] && File.exist?(result[:file_path])
        # Send email with attachment
        ExportMailer.export_attachment(
          recipient_email, 
          user, 
          seating_arrangement, 
          format, 
          result
        ).deliver_now
        
        # Clean up temp file
        File.delete(result[:file_path])
        
        Rails.logger.info "Email export job completed successfully for arrangement #{seating_arrangement.id}"
      else
        raise "Export file was not generated successfully"
      end
      
    rescue StandardError => e
      Rails.logger.error "Email export job failed for arrangement #{seating_arrangement.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Send failure notification
      ExportMailer.email_export_failed(
        recipient_email, 
        user, 
        seating_arrangement, 
        format, 
        e.message
      ).deliver_now
      
      raise e
    end
  end
end