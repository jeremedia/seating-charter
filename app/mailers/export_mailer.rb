class ExportMailer < ApplicationMailer
  default from: ENV.fetch('CHDS_FROM_EMAIL', 'noreply@chds-seating.com')

  def export_ready(user, export_record)
    @user = user
    @export_record = export_record
    @arrangement = SeatingArrangement.find(@export_record[:seating_arrangement_id])
    @download_url = generate_download_url(@export_record[:id])
    
    mail(
      to: user.email,
      subject: "Your seating chart export is ready"
    )
  end

  def export_failed(user, seating_arrangement, format, error_message)
    @user = user
    @seating_arrangement = seating_arrangement
    @format = format.humanize
    @error_message = error_message
    
    mail(
      to: user.email,
      subject: "Export failed - #{@seating_arrangement.seating_event.name}"
    )
  end

  def bulk_export_ready(user, export_record, file_count)
    @user = user
    @export_record = export_record
    @file_count = file_count
    @seating_event = SeatingEvent.find(@export_record[:seating_event_id])
    @download_url = generate_download_url(@export_record[:id])
    
    mail(
      to: user.email,
      subject: "Your bulk export is ready (#{@file_count} files)"
    )
  end

  def bulk_export_failed(user, arrangement_ids, format, error_message)
    @user = user
    @arrangement_count = arrangement_ids.count
    @format = format.humanize
    @error_message = error_message
    
    # Get event name from first arrangement if possible
    first_arrangement = SeatingArrangement.find_by(id: arrangement_ids.first)
    @event_name = first_arrangement&.seating_event&.name || "Multiple Events"
    
    mail(
      to: user.email,
      subject: "Bulk export failed - #{@event_name}"
    )
  end

  def export_attachment(recipient_email, user, seating_arrangement, format, export_result)
    @user = user
    @recipient_email = recipient_email
    @seating_arrangement = seating_arrangement
    @format = format.humanize
    
    # Attach the export file
    attachments[export_result[:filename]] = File.read(export_result[:file_path])
    
    mail(
      to: recipient_email,
      subject: "Seating chart export - #{@seating_arrangement.seating_event.name}"
    )
  end

  def email_export_failed(recipient_email, user, seating_arrangement, format, error_message)
    @user = user
    @recipient_email = recipient_email
    @seating_arrangement = seating_arrangement
    @format = format.humanize
    @error_message = error_message
    
    mail(
      to: recipient_email,
      cc: user.email, # CC the requester
      subject: "Export failed - #{@seating_arrangement.seating_event.name}"
    )
  end

  private

  def generate_download_url(export_id)
    # This would generate a secure download URL
    # For now, return a placeholder that would work with the controller
    Rails.application.routes.url_helpers.download_export_url(
      token: export_id,
      host: default_url_options[:host] || 'localhost:3000'
    )
  rescue
    # Fallback if URL generation fails
    "#{default_url_options[:host] || 'localhost:3000'}/exports/download?token=#{export_id}"
  end
end