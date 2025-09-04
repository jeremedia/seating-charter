FactoryBot.define do
  factory :seating_arrangement do
    association :seating_event
    association :created_by, factory: :user
    
    arrangement_data do
      {
        1 => build_list(:student, 4, cohort: seating_event.cohort),
        2 => build_list(:student, 4, cohort: seating_event.cohort),
        3 => build_list(:student, 4, cohort: seating_event.cohort)
      }
    end
    
    optimization_scores do
      {
        'strategy' => 'simulated_annealing',
        'iterations' => 500,
        'improvements' => 25,
        'runtime' => 2.5,
        'initial_score' => 0.45,
        'final_score' => 0.78,
        'improvement' => 73.3
      }
    end
    
    diversity_metrics do
      {
        'age_diversity' => 0.75,
        'gender_diversity' => 0.82,
        'agency_diversity' => 0.68,
        'department_diversity' => 0.71,
        'overall_diversity' => 0.74
      }
    end
    
    decision_log_data { {} }
    explanation_data { {} }
    confidence_scores { {} }
    multi_day_metadata { {} }

    trait :with_high_score do
      optimization_scores do
        {
          'strategy' => 'simulated_annealing',
          'iterations' => 800,
          'improvements' => 45,
          'runtime' => 3.2,
          'initial_score' => 0.52,
          'final_score' => 0.91,
          'improvement' => 75.0
        }
      end
    end

    trait :with_low_score do
      optimization_scores do
        {
          'strategy' => 'random_swap',
          'iterations' => 200,
          'improvements' => 5,
          'runtime' => 1.1,
          'initial_score' => 0.35,
          'final_score' => 0.42,
          'improvement' => 20.0
        }
      end
    end

    trait :with_explanations do
      explanation_data do
        {
          'overall_summary' => 'This arrangement optimizes for diversity while respecting constraints.',
          'student_explanations' => {
            '1' => 'Student placed to balance gender diversity at table 1',
            '2' => 'Student positioned to enhance agency level mixing'
          },
          'table_explanations' => {
            '1' => 'Table 1 has optimal gender and agency balance',
            '2' => 'Table 2 maximizes department type diversity'
          },
          'diversity_analysis' => 'Strong gender balance achieved across all tables',
          'constraint_analysis' => 'All hard constraints satisfied with minimal soft constraint violations',
          'optimization_details' => 'Simulated annealing converged to high-quality solution'
        }
      end
      
      confidence_scores do
        {
          'overall_confidence' => 0.87,
          'table_confidences' => {
            '1' => 0.89,
            '2' => 0.85,
            '3' => 0.88
          },
          'placement_confidences' => {
            '1' => 0.92,
            '2' => 0.84,
            '3' => 0.88
          }
        }
      end
    end

    trait :with_decision_log do
      decision_log_data do
        {
          'decision_summary' => 'Optimization process logged 500 iterations with 25 improvements',
          'key_decisions' => [
            {
              'iteration' => 100,
              'decision' => 'Accepted arrangement improving gender balance',
              'score_change' => 0.05
            },
            {
              'iteration' => 300,
              'decision' => 'Rejected arrangement violating agency separation rule',
              'penalty_applied' => 2.0
            }
          ],
          'constraint_evaluations' => 15,
          'diversity_analyses' => 8,
          'final_statistics' => {
            'total_iterations' => 500,
            'accepted_moves' => 125,
            'rejected_moves' => 375
          }
        }
      end
    end

    trait :multi_day do
      day_number { Faker::Number.between(from: 1, to: 5) }
      
      multi_day_metadata do
        {
          'day_name' => "Day #{day_number}",
          'rotation_strategy' => 'maximum_interaction_novelty',
          'interaction_novelty_score' => 0.82,
          'students_with_new_interactions' => 15,
          'repeated_interactions_count' => 3,
          'constraints' => [
            'maintain_gender_balance',
            'rotate_agency_types'
          ]
        }
      end
    end

    trait :with_table_assignments do
      transient do
        students_per_table { 4 }
        number_of_tables { 3 }
      end

      after(:create) do |arrangement, evaluator|
        # Create students for this arrangement
        total_students = evaluator.students_per_table * evaluator.number_of_tables
        students = create_list(:student, total_students, cohort: arrangement.seating_event.cohort)
        
        # Create table assignments
        students.each_with_index do |student, index|
          table_number = (index / evaluator.students_per_table) + 1
          seat_position = (index % evaluator.students_per_table) + 1
          
          create(:table_assignment,
            seating_arrangement: arrangement,
            student: student,
            table_number: table_number,
            seat_position: seat_position
          )
        end
        
        # Update arrangement_data to reflect actual assignments
        arrangement_data = {}
        arrangement.table_assignments.group_by(&:table_number).each do |table_num, assignments|
          arrangement_data[table_num] = assignments.map(&:student)
        end
        arrangement.update!(arrangement_data: arrangement_data)
      end
    end

    trait :locked do
      is_locked { true }
      association :locked_by, factory: :user
      locked_at { Time.current }
    end

    trait :recent do
      created_at { 1.hour.ago }
    end

    trait :with_modifications do
      association :last_modified_by, factory: :user
      last_modified_at { 30.minutes.ago }
      modification_notes { "Updated table 2 arrangement for better balance" }
    end
  end
end