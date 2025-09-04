# frozen_string_literal: true

class MultiDayOptimizationJob < ApplicationJob
  queue_as :default
  
  # Retry configuration for optimization jobs
  retry_on StandardError, wait: 30.seconds, attempts: 3 do |job, error|
    Rails.logger.error "MultiDayOptimizationJob failed: #{error.message}"
    # Could send notification to user about failure
    notify_optimization_failure(job.arguments[0], job.arguments[2], error.message)
  end

  def perform(seating_event_id, multi_day_config, user_id)
    Rails.logger.info "Starting MultiDayOptimizationJob for event #{seating_event_id}"
    
    # Set up job tracking
    @seating_event = SeatingEvent.find(seating_event_id)
    @user = User.find(user_id)
    @multi_day_config = multi_day_config.with_indifferent_access
    @job_id = job_id
    
    # Initialize progress tracking
    update_job_progress(0, "Initializing multi-day optimization...")
    
    begin
      # Validate configuration
      update_job_progress(5, "Validating configuration...")
      validate_optimization_config
      
      # Initialize optimization service
      update_job_progress(10, "Setting up optimization service...")
      optimization_service = MultiDayOptimizationService.new(@seating_event, @multi_day_config)
      
      # Convert config to days_config format expected by service
      days_config = build_days_config_from_params
      rotation_strategy = @multi_day_config[:rotation_strategy]&.to_sym || :maximum_diversity
      max_runtime_per_day = @multi_day_config[:max_runtime_per_day]&.to_i || 20
      
      update_job_progress(15, "Starting optimization for #{days_config.length} days...")
      
      # Track progress through days
      total_days = days_config.length
      progress_per_day = 70.0 / total_days # Reserve 70% for optimization, rest for processing
      
      # Hook into optimization service to update progress per day
      optimization_result = optimization_service.optimize_multiple_days(
        days_config: days_config,
        rotation_strategy: rotation_strategy,
        max_runtime_per_day: max_runtime_per_day
      ) do |day_number, day_status|
        # Progress callback for each day
        day_progress = 15 + (day_number * progress_per_day)
        update_job_progress(day_progress.to_i, "Optimizing #{day_status}...")
      end
      
      if optimization_result[:success]
        update_job_progress(85, "Saving optimization results...")
        
        # Save the optimization result
        saved_arrangements = optimization_service.save_multi_day_arrangement(optimization_result, @user)
        
        if saved_arrangements
          update_job_progress(90, "Generating analytics and insights...")
          
          # Generate comprehensive analytics
          analytics_service = MultiDayAnalyticsService.new(@seating_event, optimization_result)
          analytics_report = analytics_service.generate_comprehensive_report
          
          # Store analytics in session or cache for immediate access
          store_analytics_report(analytics_report)
          
          update_job_progress(95, "Updating interaction tracking...")
          
          # Update interaction tracking records
          update_interaction_tracking(optimization_result)
          
          update_job_progress(100, "Optimization completed successfully!")
          
          # Notify user of completion
          notify_optimization_success(saved_arrangements, analytics_report)
          
          Rails.logger.info "MultiDayOptimizationJob completed successfully for event #{seating_event_id}"
        else
          raise StandardError, "Failed to save optimization arrangements"
        end
      else
        raise StandardError, optimization_result[:error] || "Optimization failed"
      end
      
    rescue StandardError => e
      Rails.logger.error "MultiDayOptimizationJob failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      update_job_progress(-1, "Optimization failed: #{e.message}")
      notify_optimization_failure(@seating_event.id, @user.id, e.message)
      
      raise e
    end
  end

  private

  def validate_optimization_config
    errors = []
    
    # Basic validation
    total_days = @multi_day_config[:total_days].to_i
    errors << "Invalid number of days" if total_days < 2 || total_days > 10
    
    max_runtime = @multi_day_config[:max_runtime_per_day].to_i
    errors << "Invalid runtime per day" if max_runtime < 5 || max_runtime > 300
    
    # Validate rotation strategy
    valid_strategies = RotationStrategyService::ROTATION_STRATEGIES.keys.map(&:to_s)
    strategy = @multi_day_config[:rotation_strategy].to_s
    errors << "Invalid rotation strategy" unless valid_strategies.include?(strategy)
    
    # Check student count
    student_count = @seating_event.cohort.students.count
    errors << "Insufficient students for multi-day optimization" if student_count < 4
    
    if errors.any?
      raise StandardError, "Configuration validation failed: #{errors.join(', ')}"
    end
  end

  def build_days_config_from_params
    total_days = @multi_day_config[:total_days].to_i
    days_config_params = @multi_day_config[:days_config] || []
    
    (1..total_days).map do |day_number|
      day_config = days_config_params.find { |config| config[:day_number].to_i == day_number } || {}
      
      {
        day_number: day_number,
        day_name: day_config[:day_name] || "Day #{day_number}",
        absent_student_ids: (day_config[:absent_student_ids] || []).map(&:to_i),
        constraints: parse_day_constraints(day_config[:special_constraints]),
        preferences: parse_day_preferences(day_config[:preferences] || [])
      }
    end
  end

  def parse_day_constraints(constraints_string)
    return [] if constraints_string.blank?
    
    # Parse natural language constraints into structured format
    constraints = []
    
    # Simple pattern matching for common constraints
    if constraints_string.downcase.include?('keep') && constraints_string.downcase.include?('together')
      constraints << { type: 'group_together', description: constraints_string }
    end
    
    if constraints_string.downcase.include?('separate') || constraints_string.downcase.include?('apart')
      constraints << { type: 'keep_apart', description: constraints_string }
    end
    
    constraints
  end

  def parse_day_preferences(preferences_array)
    preferences_array.map do |pref|
      {
        type: 'preference',
        description: pref,
        weight: 1.0
      }
    end
  end

  def update_job_progress(percentage, message)
    # Store progress in Redis or similar cache for real-time updates
    Rails.cache.write(
      "multi_day_optimization_progress:#{@job_id}",
      {
        percentage: percentage,
        message: message,
        updated_at: Time.current,
        seating_event_id: @seating_event.id,
        user_id: @user.id,
        status: percentage < 0 ? 'failed' : (percentage >= 100 ? 'completed' : 'processing')
      },
      expires_in: 1.hour
    )
    
    Rails.logger.info "MultiDayOptimizationJob progress: #{percentage}% - #{message}"
  end

  def store_analytics_report(analytics_report)
    # Store analytics report for immediate access after job completion
    Rails.cache.write(
      "multi_day_analytics:#{@seating_event.id}",
      analytics_report,
      expires_in: 24.hours
    )
  end

  def update_interaction_tracking(optimization_result)
    daily_arrangements = optimization_result[:daily_arrangements] || {}
    
    daily_arrangements.each do |day_number, arrangement|
      arrangement.each do |table_number, students|
        # Record all pairwise interactions at this table for this day
        students.combination(2).each do |student_a, student_b|
          interaction = InteractionTracking.find_or_initialize_by(
            student_a: [student_a, student_b].min_by(&:id),
            student_b: [student_a, student_b].max_by(&:id),
            seating_event: @seating_event
          )
          
          interaction.increment_interaction!(day_number, table_number)
        end
      end
    end
    
    Rails.logger.info "Updated interaction tracking for #{daily_arrangements.keys.count} days"
  end

  def notify_optimization_success(saved_arrangements, analytics_report)
    # Send success notification (email, in-app notification, etc.)
    begin
      # Could integrate with ActionMailer or notification system
      Rails.logger.info "Optimization completed successfully - would send success notification to user #{@user.id}"
      
      # Store success notification
      store_user_notification(
        type: 'optimization_success',
        title: 'Multi-Day Optimization Completed',
        message: "Your workshop seating optimization for '#{@seating_event.name}' has been completed successfully.",
        data: {
          seating_event_id: @seating_event.id,
          total_days: saved_arrangements.keys.count,
          average_score: analytics_report.dig(:optimization_performance, :quality_metrics, :average_daily_score),
          interaction_coverage: analytics_report.dig(:interaction_analysis, :coverage_report, :coverage_percentage)
        }
      )
      
    rescue StandardError => e
      Rails.logger.error "Failed to send success notification: #{e.message}"
    end
  end

  def notify_optimization_failure(seating_event_id, user_id, error_message)
    begin
      Rails.logger.info "Optimization failed - would send failure notification to user #{user_id}"
      
      store_user_notification(
        type: 'optimization_failure',
        title: 'Multi-Day Optimization Failed',
        message: "Your workshop seating optimization encountered an error: #{error_message}",
        data: {
          seating_event_id: seating_event_id,
          error_message: error_message,
          timestamp: Time.current
        }
      )
      
    rescue StandardError => e
      Rails.logger.error "Failed to send failure notification: #{e.message}"
    end
  end

  def store_user_notification(notification_data)
    # Store notification in cache or database for user to see
    notifications_key = "user_notifications:#{@user.id}"
    existing_notifications = Rails.cache.read(notifications_key) || []
    
    new_notification = notification_data.merge(
      id: SecureRandom.uuid,
      created_at: Time.current,
      read: false
    )
    
    existing_notifications.unshift(new_notification)
    existing_notifications = existing_notifications.first(50) # Keep only recent notifications
    
    Rails.cache.write(notifications_key, existing_notifications, expires_in: 7.days)
  end

  # Class method to check job status
  def self.check_job_status(job_id)
    progress_data = Rails.cache.read("multi_day_optimization_progress:#{job_id}")
    
    if progress_data
      {
        status: progress_data[:status],
        percentage: progress_data[:percentage],
        message: progress_data[:message],
        updated_at: progress_data[:updated_at],
        seating_event_id: progress_data[:seating_event_id]
      }
    else
      {
        status: 'not_found',
        percentage: 0,
        message: 'Job not found or expired',
        updated_at: nil
      }
    end
  end

  # Class method to get user notifications
  def self.get_user_notifications(user_id, mark_as_read: false)
    notifications_key = "user_notifications:#{user_id}"
    notifications = Rails.cache.read(notifications_key) || []
    
    if mark_as_read && notifications.any?
      notifications.each { |n| n[:read] = true }
      Rails.cache.write(notifications_key, notifications, expires_in: 7.days)
    end
    
    notifications
  end

  # Class method to estimate job duration
  def self.estimate_duration(total_days, students_count, max_runtime_per_day)
    # Base estimation formula
    base_time_per_day = max_runtime_per_day
    setup_time = 10 # seconds
    processing_time = total_days * 5 # seconds per day for processing
    
    # Adjust for student count (more students = slightly longer optimization)
    student_factor = [1.0 + (students_count - 20) * 0.01, 2.0].min if students_count > 20
    student_factor ||= 1.0
    
    estimated_seconds = setup_time + (base_time_per_day * total_days * student_factor) + processing_time
    
    {
      estimated_seconds: estimated_seconds.round,
      estimated_minutes: (estimated_seconds / 60.0).round(1),
      breakdown: {
        setup: setup_time,
        optimization: (base_time_per_day * total_days * student_factor).round,
        processing: processing_time
      }
    }
  end
end