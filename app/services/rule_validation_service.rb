class RuleValidationService
  class << self
    # Validate all rules for a seating event
    def validate_all_rules(seating_event)
      rules = seating_event.seating_rules.active.by_priority
      
      validation_result = {
        valid: true,
        conflicts: [],
        warnings: [],
        suggestions: [],
        feasibility: check_feasibility(rules, seating_event)
      }
      
      # Check for conflicts between rules
      conflicts = detect_conflicts(rules)
      validation_result[:conflicts] = conflicts
      validation_result[:valid] = conflicts.empty?
      
      # Check for warnings (potential issues)
      warnings = detect_warnings(rules, seating_event)
      validation_result[:warnings] = warnings
      
      # Generate suggestions for improvement
      suggestions = generate_suggestions(rules, seating_event)
      validation_result[:suggestions] = suggestions
      
      validation_result
    end
    
    # Validate a single rule
    def validate_single_rule(rule, seating_event = nil)
      seating_event ||= rule.seating_event
      other_rules = seating_event.seating_rules.active.where.not(id: rule.id)
      
      validation_result = {
        valid: true,
        conflicts: [],
        warnings: [],
        feasibility: check_rule_feasibility(rule, seating_event)
      }
      
      # Check conflicts with existing rules
      conflicts = detect_rule_conflicts(rule, other_rules)
      validation_result[:conflicts] = conflicts
      validation_result[:valid] = conflicts.empty?
      
      # Check for rule-specific warnings
      warnings = detect_rule_warnings(rule, seating_event)
      validation_result[:warnings] = warnings
      
      validation_result
    end
    
    # Check if rules are feasible given cohort size and table constraints
    def check_feasibility(rules, seating_event)
      cohort = seating_event.cohort
      total_students = cohort.students.count
      table_size = seating_event.table_size
      total_tables = seating_event.total_tables
      
      feasibility = {
        feasible: true,
        issues: [],
        utilization: calculate_expected_utilization(rules, seating_event)
      }
      
      # Check basic capacity
      if total_students > (table_size * total_tables)
        feasibility[:feasible] = false
        feasibility[:issues] << {
          type: 'capacity_exceeded',
          message: "#{total_students} students exceed capacity of #{table_size * total_tables} seats"
        }
      end
      
      # Check separation rule feasibility
      separation_rules = rules.select { |r| r.rule_type == 'separation' }
      separation_issues = check_separation_feasibility(separation_rules, seating_event)
      feasibility[:issues].concat(separation_issues)
      
      # Check clustering rule feasibility
      clustering_rules = rules.select { |r| r.rule_type == 'clustering' }
      clustering_issues = check_clustering_feasibility(clustering_rules, seating_event)
      feasibility[:issues].concat(clustering_issues)
      
      feasibility[:feasible] = feasibility[:issues].select { |i| i[:type] != 'warning' }.empty?
      feasibility
    end
    
    private
    
    def detect_conflicts(rules)
      conflicts = []
      
      rules.each_with_index do |rule1, i|
        rules[(i+1)..-1].each do |rule2|
          conflict = check_rule_pair_conflict(rule1, rule2)
          conflicts << conflict if conflict
        end
      end
      
      conflicts
    end
    
    def detect_rule_conflicts(rule, other_rules)
      conflicts = []
      
      other_rules.each do |other_rule|
        conflict = check_rule_pair_conflict(rule, other_rule)
        conflicts << conflict if conflict
      end
      
      conflicts
    end
    
    def check_rule_pair_conflict(rule1, rule2)
      # Check for direct conflicts
      
      # Separation vs Clustering conflict
      if rule1.rule_type == 'separation' && rule2.rule_type == 'clustering'
        if rules_target_same_attributes?(rule1, rule2)
          return {
            type: 'separation_clustering_conflict',
            rule1_id: rule1.id,
            rule2_id: rule2.id,
            message: "Rule '#{rule1.natural_language_input}' wants to separate what rule '#{rule2.natural_language_input}' wants to cluster",
            severity: 'high'
          }
        end
      end
      
      # Clustering vs Clustering with different criteria
      if rule1.rule_type == 'clustering' && rule2.rule_type == 'clustering'
        if rules_have_conflicting_clustering?(rule1, rule2)
          return {
            type: 'clustering_conflict',
            rule1_id: rule1.id,
            rule2_id: rule2.id,
            message: "Conflicting clustering rules may create impossible grouping requirements",
            severity: 'medium'
          }
        end
      end
      
      # Distribution conflicts
      if rule1.rule_type == 'distribution' && rule2.rule_type == 'distribution'
        if rules_have_conflicting_distribution?(rule1, rule2)
          return {
            type: 'distribution_conflict',
            rule1_id: rule1.id,
            rule2_id: rule2.id,
            message: "Multiple distribution rules may create conflicting requirements",
            severity: 'medium'
          }
        end
      end
      
      # Priority conflicts (same priority)
      if rule1.priority == rule2.priority && rule1.priority == 1
        return {
          type: 'priority_conflict',
          rule1_id: rule1.id,
          rule2_id: rule2.id,
          message: "Multiple rules with highest priority (1) - consider adjusting priorities",
          severity: 'low'
        }
      end
      
      nil
    end
    
    def detect_warnings(rules, seating_event)
      warnings = []
      
      # Check for too many high-priority rules
      high_priority_rules = rules.select { |r| r.priority <= 2 }
      if high_priority_rules.count > 3
        warnings << {
          type: 'too_many_priorities',
          message: "#{high_priority_rules.count} rules with high priority may be difficult to satisfy simultaneously",
          severity: 'medium'
        }
      end
      
      # Check for low confidence rules
      low_confidence_rules = rules.select { |r| r.confidence_score < 0.7 }
      if low_confidence_rules.any?
        warnings << {
          type: 'low_confidence_rules',
          message: "#{low_confidence_rules.count} rules have low confidence and may need manual review",
          severity: 'low'
        }
      end
      
      # Check for complex rule combinations
      if rules.count > 5
        warnings << {
          type: 'many_rules',
          message: "#{rules.count} rules may be difficult to satisfy - consider consolidating",
          severity: 'medium'
        }
      end
      
      warnings
    end
    
    def detect_rule_warnings(rule, seating_event)
      warnings = []
      
      # Check if target attributes exist in cohort
      if rule.target_attributes.present?
        cohort = seating_event.cohort
        available_fields = get_available_fields(cohort)
        
        rule.target_attributes.keys.each do |field|
          unless available_fields.include?(field)
            warnings << {
              type: 'missing_attribute',
              message: "Target attribute '#{field}' not found in student data",
              severity: 'high'
            }
          end
        end
      end
      
      warnings
    end
    
    def generate_suggestions(rules, seating_event)
      suggestions = []
      
      # Suggest priority adjustments
      if rules.map(&:priority).uniq.count < rules.count / 2
        suggestions << {
          type: 'adjust_priorities',
          message: "Consider spreading rule priorities more evenly for better conflict resolution"
        }
      end
      
      # Suggest rule consolidation
      similar_rules = find_similar_rules(rules)
      if similar_rules.any?
        suggestions << {
          type: 'consolidate_rules',
          message: "Some rules could be consolidated: #{similar_rules.map { |pair| pair.map(&:natural_language_input).join(' and ') }.join('; ')}"
        }
      end
      
      # Suggest attribute refinement
      if rules.any? { |r| r.target_attributes.blank? }
        suggestions << {
          type: 'refine_attributes',
          message: "Some rules lack specific target attributes - consider making them more specific"
        }
      end
      
      suggestions
    end
    
    def check_separation_feasibility(separation_rules, seating_event)
      issues = []
      
      separation_rules.each do |rule|
        affected_students = count_affected_students(rule, seating_event.cohort)
        min_tables_needed = affected_students
        
        if min_tables_needed > seating_event.total_tables
          issues << {
            type: 'separation_impossible',
            message: "Separation rule requires #{min_tables_needed} tables but only #{seating_event.total_tables} available",
            rule_id: rule.id
          }
        end
      end
      
      issues
    end
    
    def check_clustering_feasibility(clustering_rules, seating_event)
      issues = []
      
      clustering_rules.each do |rule|
        affected_students = count_affected_students(rule, seating_event.cohort)
        
        if affected_students > seating_event.table_size
          issues << {
            type: 'clustering_warning',
            message: "Clustering rule affects #{affected_students} students but table size is #{seating_event.table_size}",
            rule_id: rule.id
          }
        end
      end
      
      issues
    end
    
    def check_rule_feasibility(rule, seating_event)
      case rule.rule_type
      when 'separation'
        check_separation_feasibility([rule], seating_event)
      when 'clustering'
        check_clustering_feasibility([rule], seating_event)
      else
        []
      end
    end
    
    def calculate_expected_utilization(rules, seating_event)
      # Simple utilization calculation
      total_capacity = seating_event.table_size * seating_event.total_tables
      actual_students = seating_event.cohort.students.count
      
      (actual_students.to_f / total_capacity * 100).round(1)
    end
    
    def rules_target_same_attributes?(rule1, rule2)
      return false if rule1.target_attributes.blank? || rule2.target_attributes.blank?
      
      (rule1.target_attributes.keys & rule2.target_attributes.keys).any?
    end
    
    def rules_have_conflicting_clustering?(rule1, rule2)
      # Check if clustering rules have overlapping but different criteria
      return false unless rules_target_same_attributes?(rule1, rule2)
      
      rule1.target_attributes.any? do |field, values1|
        values2 = rule2.target_attributes[field]
        values2 && (values1 & values2).empty?
      end
    end
    
    def rules_have_conflicting_distribution?(rule1, rule2)
      # Check if distribution rules conflict
      strategy1 = rule1.constraints&.dig('distribution_strategy')
      strategy2 = rule2.constraints&.dig('distribution_strategy')
      
      strategy1 && strategy2 && strategy1 != strategy2
    end
    
    def find_similar_rules(rules)
      similar_pairs = []
      
      rules.each_with_index do |rule1, i|
        rules[(i+1)..-1].each do |rule2|
          if rules_are_similar?(rule1, rule2)
            similar_pairs << [rule1, rule2]
          end
        end
      end
      
      similar_pairs
    end
    
    def rules_are_similar?(rule1, rule2)
      # Rules are similar if they have the same type and overlapping attributes
      rule1.rule_type == rule2.rule_type && rules_target_same_attributes?(rule1, rule2)
    end
    
    def count_affected_students(rule, cohort)
      return cohort.students.count if rule.target_attributes.blank?
      
      count = 0
      cohort.students.each do |student|
        if rule.applies_to_student?(student)
          count += 1
        end
      end
      
      count
    end
    
    def get_available_fields(cohort)
      students = cohort.students.limit(100)
      
      custom_attrs = students.map { |s| s.student_attributes&.keys || [] }.flatten.uniq
      inference_fields = students.map { |s| s.inferences&.keys || [] }.flatten.uniq
      
      custom_attrs + inference_fields
    end
  end
end