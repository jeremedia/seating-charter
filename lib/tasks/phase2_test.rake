namespace :phase2 do
  desc "Set up test data and test all Phase 2 services"
  task test: :environment do
    puts "🚀 Starting Phase 2 Test Suite..."
    
    begin
      # Step 1: Create test user
      puts "\n1. Creating test user..."
      test_user = User.find_or_create_by(email: 'test@chds.edu') do |user|
        user.password = 'password123'
        user.password_confirmation = 'password123'
      end
      puts "✅ Test user created/found: #{test_user.email}"
      
      # Step 2: Create AI configuration
      puts "\n2. Creating AI configuration..."
      ai_config = AiConfiguration.find_or_create_by(ai_model_name: 'gpt-4o-mini') do |config|
        config.temperature = 0.1
        config.max_tokens = 500
        config.batch_size = 5
        config.retry_attempts = 3
        config.cost_per_token = 0.00003
        config.active = true
      end
      puts "✅ AI configuration created/found: #{ai_config.ai_model_name} (Active: #{ai_config.active?})"
      
      # Step 3: Test OpenAI service
      puts "\n3. Testing OpenAI service..."
      if ENV['OPENAI_API_KEY'].present?
        test_result = OpenaiService.test_interface("Test prompt: What is 2+2?", test_user)
        if test_result[:success]
          puts "✅ OpenAI service test successful"
          puts "   Response: #{test_result[:response]}"
        else
          puts "❌ OpenAI service test failed: #{test_result[:error]}"
        end
      else
        puts "⚠️ OPENAI_API_KEY not set, skipping OpenAI service test"
      end
      
      # Step 4: Use existing cohort or create test cohort
      puts "\n4. Finding test cohort..."
      test_cohort = Cohort.first
      if test_cohort.nil?
        test_cohort = Cohort.create!(
          name: 'Test Cohort 2024',
          description: 'Test cohort for Phase 2 services',
          start_date: Date.current,
          end_date: Date.current + 6.months
        )
        puts "✅ Test cohort created: #{test_cohort.name}"
      else
        puts "✅ Using existing cohort: #{test_cohort.name}"
      end
      
      # Step 5: Test roster parser with sample data
      puts "\n5. Testing roster parser with sample data..."
      if ENV['OPENAI_API_KEY'].present?
        roster_result = AiRosterParser.test_with_sample_data(test_cohort.id, user: test_user)
        if roster_result[:success]
          puts "✅ Roster parser test successful"
          puts "   Students created: #{roster_result[:result][:students_created]}"
        else
          puts "❌ Roster parser test failed: #{roster_result[:error]}"
        end
      else
        puts "⚠️ OPENAI_API_KEY not set, creating sample students manually"
        sample_students = [
          { name: "John Smith", title: "Supervisory Special Agent", organization: "FBI", location: "Washington, DC" },
          { name: "Sarah Johnson", title: "Captain", organization: "U.S. Army", location: "Fort Bragg, NC" },
          { name: "Michael Davis", title: "Emergency Management Director", organization: "City of Phoenix", location: "Phoenix, AZ" }
        ]
        
        sample_students.each do |student_data|
          student = Student.find_by(name: student_data[:name], cohort_id: test_cohort.id)
          unless student
            student = Student.create!(
              cohort_id: test_cohort.id,
              name: student_data[:name],
              title: student_data[:title],
              organization: student_data[:organization],
              location: student_data[:location]
            )
          end
        end
        puts "✅ Sample students created manually"
      end
      
      # Step 6: Test attribute inference
      puts "\n6. Testing attribute inference..."
      students = test_cohort.students.limit(3)
      
      if students.any?
        if ENV['OPENAI_API_KEY'].present?
          inference_result = AttributeInferenceService.test_with_sample_students(test_cohort.id, user: test_user)
          if inference_result[:success]
            puts "✅ Attribute inference test successful"
            puts "   Students processed: #{inference_result[:students_processed]}"
            
            # Show inference results
            students.each do |student|
              puts "   #{student.name}:"
              puts "     Gender: #{student.gender || 'unknown'} (conf: #{student.gender_confidence || 0})"
              puts "     Agency Level: #{student.agency_level || 'unknown'} (conf: #{student.agency_level_confidence || 0})"
            end
          else
            puts "❌ Attribute inference test failed: #{inference_result[:error]}"
          end
        else
          puts "⚠️ OPENAI_API_KEY not set, testing rule-based inference only"
          students.each do |student|
            # Test rule-based inference
            gender_result = AttributeInferenceService.send(:infer_gender_rule_based, 
                                      AttributeInferenceService.send(:extract_first_name, student.name))
            agency_result = AttributeInferenceService.send(:infer_agency_level_rule_based, student.organization || "")
            
            student.set_inference('gender', gender_result[:value], gender_result[:confidence])
            student.set_inference('agency_level', agency_result[:value], agency_result[:confidence])
            student.save!
            
            puts "   #{student.name}: Gender=#{gender_result[:value]} (#{gender_result[:confidence]}), Agency=#{agency_result[:value]} (#{agency_result[:confidence]})"
          end
          puts "✅ Rule-based attribute inference completed"
        end
      else
        puts "❌ No students found to test attribute inference"
      end
      
      # Step 7: Check cost tracking
      puts "\n7. Checking cost tracking..."
      total_cost = CostTracking.sum(:cost_estimate)
      total_requests = CostTracking.count
      puts "✅ Cost tracking summary:"
      puts "   Total requests tracked: #{total_requests}"
      puts "   Total estimated cost: $#{total_cost}"
      
      # Final summary
      puts "\n🎉 Phase 2 Test Suite Completed!"
      puts "\n📊 Summary:"
      puts "   ✅ OpenAI Service: #{OpenaiService.configured? ? 'Configured' : 'Not configured'}"
      puts "   ✅ AI Configurations: #{AiConfiguration.count} (Active: #{AiConfiguration.active.count})"
      puts "   ✅ Test Cohort: #{test_cohort.name}"
      puts "   ✅ Sample Students: #{test_cohort.students.count}"
      puts "   ✅ Cost Records: #{CostTracking.count}"
      
      puts "\n🌐 Admin URLs to test:"
      puts "   - AI Configurations: http://localhost:3000/admin/ai_configurations"
      puts "   - Cost Tracking: http://localhost:3000/admin/cost_trackings"
      
    rescue StandardError => e
      puts "❌ Test suite failed with error: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end
  
  desc "Clean up test data"
  task clean: :environment do
    puts "🧹 Cleaning up test data..."
    
    # Clean up only test students, not the whole cohort
    test_students = Student.where(name: ['John Smith', 'Sarah Johnson', 'Michael Davis', 'John Test'])
    if test_students.any?
      test_students.destroy_all
      puts "✅ Test students cleaned up"
    end
    
    test_user = User.find_by(email: 'test@chds.edu')
    if test_user
      test_user.destroy
      puts "✅ Test user cleaned up"
    end
    
    puts "🎉 Cleanup completed!"
  end
end