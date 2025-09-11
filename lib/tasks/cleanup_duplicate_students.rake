namespace :students do
  desc "Remove duplicate students and clean up their associations"
  task cleanup_duplicates: :environment do
    puts "Starting duplicate student cleanup..."
    
    # Process each cohort
    Cohort.find_each do |cohort|
      puts "\nProcessing Cohort: #{cohort.name} (ID: #{cohort.id})"
      
      # Find duplicate students in this cohort
      duplicate_groups = cohort.students
                               .group(:name)
                               .having('COUNT(*) > 1')
                               .count
      
      if duplicate_groups.empty?
        puts "  ✓ No duplicates found"
        next
      end
      
      puts "  Found #{duplicate_groups.size} names with duplicates"
      
      total_deleted = 0
      duplicate_groups.each do |name, count|
        puts "    Processing '#{name}' (#{count} records)..."
        
        # Get all students with this name in this cohort
        students = cohort.students.where(name: name).order(:id)
        
        # Keep the first one (lowest ID)
        keeper = students.first
        duplicates = students.where.not(id: keeper.id)
        
        # Count affected table assignments
        assignment_count = TableAssignment.where(student_id: duplicates.pluck(:id)).count
        
        # Delete table assignments for duplicates
        TableAssignment.where(student_id: duplicates.pluck(:id)).destroy_all
        
        # Delete duplicate students
        deleted_count = duplicates.destroy_all.size
        total_deleted += deleted_count
        
        puts "      ✓ Kept ID #{keeper.id}, deleted #{deleted_count} duplicates, cleaned #{assignment_count} table assignments"
      end
      
      puts "  Summary: Deleted #{total_deleted} duplicate students from #{cohort.name}"
    end
    
    # Final report
    puts "\n" + "="*50
    puts "CLEANUP COMPLETE"
    puts "="*50
    
    Cohort.find_each do |cohort|
      puts "#{cohort.name}: #{cohort.students.count} students (#{cohort.students.pluck(:name).uniq.count} unique)"
    end
  end
  
  desc "Preview duplicate students without deleting"
  task preview_duplicates: :environment do
    puts "Previewing duplicate students..."
    
    total_duplicates = 0
    Cohort.find_each do |cohort|
      duplicate_groups = cohort.students
                               .group(:name)
                               .having('COUNT(*) > 1')
                               .count
      
      if duplicate_groups.any?
        puts "\nCohort: #{cohort.name} (ID: #{cohort.id})"
        puts "  Current: #{cohort.students.count} records, #{cohort.students.pluck(:name).uniq.count} unique names"
        puts "  Duplicates: #{duplicate_groups.size} names have duplicates"
        
        duplicate_count = duplicate_groups.values.sum - duplicate_groups.size
        total_duplicates += duplicate_count
        puts "  Would delete: #{duplicate_count} duplicate records"
      end
    end
    
    puts "\n" + "="*50
    puts "Total duplicate records that would be deleted: #{total_duplicates}"
  end
end