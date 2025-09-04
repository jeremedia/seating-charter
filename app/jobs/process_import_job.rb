class ProcessImportJob < ApplicationJob
  queue_as :default
  
  def perform(import_session_id, file_path)
    import_session = ImportSession.find(import_session_id)
    import_session.update!(status: :processing)
    
    begin
      # Parse the roster using AiRosterParser
      result = AiRosterParser.parse_roster(
        file_path, 
        import_session.cohort_id,
        user: import_session.user,
        progress_callback: ->(message) { Rails.logger.info "Import progress: #{message}" }
      )
      
      if result[:success]
        # Create student import records for tracking
        result[:students].each do |student|
          import_session.student_import_records.create!(student: student)
        end
        
        # Now run AI attribute inference on all imported students
        students = result[:students]
        inference_results = AttributeInferenceService.batch_infer_attributes(
          students,
          user: import_session.user,
          progress_callback: ->(message) { Rails.logger.info "Inference progress: #{message}" }
        )
        
        # Store inference results in import session metadata
        import_session.update!(
          status: :completed,
          processed_at: Time.current,
          import_metadata: {
            students_count: result[:students_created],
            inference_results: inference_results,
            processed_at: Time.current.iso8601
          }
        )
        
        Rails.logger.info "Import completed successfully: #{result[:students_created]} students imported with AI inferences"
      else
        import_session.update!(
          status: :failed,
          processed_at: Time.current,
          import_metadata: { error: result[:message] || 'Unknown error during import' }
        )
      end
      
    rescue StandardError => e
      Rails.logger.error "Import job failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      import_session.update!(
        status: :failed,
        processed_at: Time.current,
        import_metadata: { error: e.message }
      )
    ensure
      # Clean up temporary file
      File.delete(file_path) if File.exist?(file_path)
    end
  end
end