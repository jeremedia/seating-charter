require 'zip'

class BulkExportJob < ApplicationJob
  queue_as :exports

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(arrangement_ids, format, export_options, user)
    Rails.logger.info "Starting bulk export job for arrangements #{arrangement_ids.join(', ')}, format: #{format}"
    
    begin
      arrangements = SeatingArrangement.where(id: arrangement_ids).includes(:seating_event, :created_by)
      
      if arrangements.empty?
        raise "No arrangements found for bulk export"
      end
      
      # Create temporary directory for exports
      temp_dir = Rails.root.join('tmp', 'bulk_exports', SecureRandom.hex(8))
      FileUtils.mkdir_p(temp_dir)
      
      exported_files = []
      
      # Generate individual exports
      arrangements.each do |arrangement|
        Rails.logger.info "Exporting arrangement #{arrangement.id}"
        
        result = ExportService.export(arrangement, format, export_options)
        
        if result[:file_path] && File.exist?(result[:file_path])
          # Copy to temp directory with descriptive name
          safe_name = safe_filename(arrangement.seating_event.name)
          day_suffix = arrangement.multi_day? ? "_day#{arrangement.day_number}" : ""
          timestamp = arrangement.created_at.strftime("%Y%m%d_%H%M")
          
          new_filename = "#{safe_name}#{day_suffix}_#{timestamp}.#{format}"
          destination = File.join(temp_dir, new_filename)
          
          FileUtils.cp(result[:file_path], destination)
          exported_files << {
            original_path: result[:file_path],
            zip_path: new_filename,
            arrangement: arrangement
          }
          
          # Clean up original temp file
          File.delete(result[:file_path])
        else
          Rails.logger.error "Failed to export arrangement #{arrangement.id}"
        end
      end
      
      if exported_files.empty?
        raise "No files were successfully exported"
      end
      
      # Create ZIP file
      zip_filename = generate_zip_filename(arrangements.first.seating_event, format)
      zip_path = Rails.root.join('tmp', zip_filename)
      
      create_zip_file(zip_path, temp_dir, exported_files)
      
      # Create export record
      export_record = create_bulk_export_record(arrangements, format, zip_path, zip_filename, user)
      
      # Send email notification
      ExportMailer.bulk_export_ready(user, export_record, exported_files.count).deliver_now
      
      # Clean up temp directory
      FileUtils.rm_rf(temp_dir)
      
      Rails.logger.info "Bulk export job completed successfully for #{exported_files.count} arrangements"
      
    rescue StandardError => e
      Rails.logger.error "Bulk export job failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Clean up on failure
      FileUtils.rm_rf(temp_dir) if temp_dir && Dir.exist?(temp_dir)
      File.delete(zip_path) if zip_path && File.exist?(zip_path)
      
      # Send failure notification
      ExportMailer.bulk_export_failed(user, arrangement_ids, format, e.message).deliver_now
      
      raise e
    end
  end

  private

  def create_zip_file(zip_path, temp_dir, exported_files)
    Zip::File.open(zip_path, Zip::File::CREATE) do |zipfile|
      # Add a README file
      readme_content = generate_readme_content(exported_files)
      zipfile.get_output_stream("README.txt") { |os| os.write readme_content }
      
      # Add all exported files
      exported_files.each do |file_info|
        source_path = File.join(temp_dir, file_info[:zip_path])
        zipfile.add(file_info[:zip_path], source_path)
      end
    end
  end

  def generate_readme_content(exported_files)
    content = []
    content << "CHDS Seating Charter - Bulk Export"
    content << "=" * 40
    content << ""
    content << "Export generated on: #{Time.current.strftime('%B %d, %Y at %I:%M %p')}"
    content << "Total files: #{exported_files.count}"
    content << ""
    content << "Files included:"
    content << "-" * 20
    
    exported_files.each do |file_info|
      arrangement = file_info[:arrangement]
      content << "#{file_info[:zip_path]}:"
      content << "  Event: #{arrangement.seating_event.name}"
      content << "  Created: #{arrangement.created_at.strftime('%B %d, %Y')}"
      content << "  Students: #{arrangement.students_count}"
      content << "  Tables: #{arrangement.tables_count}"
      content << "  Score: #{arrangement.formatted_score}"
      if arrangement.multi_day?
        content << "  Day: #{arrangement.day_name}"
      end
      content << ""
    end
    
    content << "For support, please contact your system administrator."
    content << ""
    
    content.join("\n")
  end

  def generate_zip_filename(seating_event, format)
    safe_name = safe_filename(seating_event.name)
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    "#{safe_name}_bulk_export_#{format}_#{timestamp}.zip"
  end

  def safe_filename(filename)
    filename.gsub(/[^0-9A-Za-z.\-]/, '_').squeeze('_').strip
  end

  def create_bulk_export_record(arrangements, format, zip_path, zip_filename, user)
    export_data = {
      id: SecureRandom.hex(16),
      type: 'bulk',
      arrangement_ids: arrangements.pluck(:id),
      seating_event_id: arrangements.first.seating_event.id,
      format: format,
      filename: zip_filename,
      file_path: zip_path.to_s,
      content_type: 'application/zip',
      user_id: user.id,
      arrangements_count: arrangements.count,
      created_at: Time.current,
      expires_at: 48.hours.from_now # Bulk exports expire after 48 hours
    }
    
    # Store in Rails cache for temporary access
    Rails.cache.write("export_#{export_data[:id]}", export_data, expires_in: 48.hours)
    
    export_data
  end
end