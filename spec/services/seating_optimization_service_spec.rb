require 'rails_helper'

RSpec.describe SeatingOptimizationService do
  let(:cohort) { create(:cohort) }
  let(:seating_event) { create(:seating_event, cohort: cohort, table_size: 4, total_tables: 3) }
  let(:students) { create_list(:student, 10, cohort: cohort) }
  let(:service) { described_class.new(seating_event) }

  before do
    students # Ensure students are created
  end

  describe '#initialize' do
    it 'initializes with a seating event' do
      expect(service.seating_event).to eq(seating_event)
      expect(service.optimization_params).to eq({})
      expect(service.results).to eq({})
    end

    it 'accepts optimization parameters' do
      params = { max_iterations: 1000, temperature: 0.5 }
      service_with_params = described_class.new(seating_event, params)
      expect(service_with_params.optimization_params).to eq(params.with_indifferent_access)
    end
  end

  describe '#optimize' do
    context 'with sufficient students' do
      it 'successfully optimizes seating arrangement' do
        result = service.optimize(max_runtime: 1.second)

        expect(result[:success]).to be true
        expect(result[:arrangement]).to be_a(Hash)
        expect(result[:score]).to be >= 0
        expect(result[:optimization_stats]).to include(:strategy, :iterations, :runtime)
      end

      it 'respects max runtime' do
        start_time = Time.current
        result = service.optimize(max_runtime: 2.seconds)
        runtime = Time.current - start_time

        expect(runtime).to be <= 3.seconds # Allow some buffer
        expect(result[:optimization_stats][:runtime]).to be <= 3.0
      end

      it 'uses simulated annealing by default' do
        result = service.optimize(max_runtime: 0.5.seconds)
        expect(result[:optimization_stats][:strategy]).to eq(:simulated_annealing)
      end

      it 'supports different optimization strategies' do
        result = service.optimize(strategy: :random_swap, max_runtime: 0.5.seconds)
        expect(result[:optimization_stats][:strategy]).to eq(:random_swap)
      end

      it 'includes diversity metrics in results' do
        result = service.optimize(max_runtime: 0.5.seconds)
        expect(result[:diversity_metrics]).to be_a(Hash)
      end

      it 'includes constraint violations in results' do
        result = service.optimize(max_runtime: 0.5.seconds)
        expect(result[:constraint_violations]).to be_an(Array)
      end

      it 'includes decision log in results' do
        result = service.optimize(max_runtime: 0.5.seconds)
        expect(result[:decision_log]).to be_a(Hash)
      end
    end

    context 'with insufficient students' do
      let(:students) { [] }

      it 'returns failure for no students' do
        result = service.optimize

        expect(result[:success]).to be false
        expect(result[:error]).to eq("No students found")
        expect(result[:arrangement]).to eq({})
      end
    end

    context 'with only one student' do
      let(:students) { create_list(:student, 1, cohort: cohort) }

      it 'returns failure for insufficient students' do
        result = service.optimize

        expect(result[:success]).to be false
        expect(result[:error]).to eq("Insufficient students for optimization")
      end
    end

    context 'with existing seating rules' do
      let!(:seating_rule) do
        create(:seating_rule, cohort: cohort, rule_type: 'separate',
               attribute_name: 'gender', created_by: create(:user))
      end

      it 'considers seating rules during optimization' do
        result = service.optimize(max_runtime: 1.second)

        expect(result[:success]).to be true
        # The constraint evaluator should have been called
        expect(result[:constraint_violations]).to be_an(Array)
      end
    end
  end

  describe '#save_arrangement' do
    let(:arrangement_data) do
      {
        arrangement: { 1 => students[0..3], 2 => students[4..7] },
        optimization_stats: { score: 0.8, iterations: 100 },
        diversity_metrics: { age_diversity: 0.7 },
        decision_log: { summary: "optimization completed" }
      }
    end
    let(:user) { create(:user) }

    it 'saves a valid arrangement' do
      seating_arrangement = service.save_arrangement(arrangement_data, user)

      expect(seating_arrangement).to be_persisted
      expect(seating_arrangement.arrangement_data).to eq(arrangement_data[:arrangement])
      expect(seating_arrangement.optimization_scores).to eq(arrangement_data[:optimization_stats])
      expect(seating_arrangement.diversity_metrics).to eq(arrangement_data[:diversity_metrics])
      expect(seating_arrangement.created_by).to eq(user)
    end

    it 'creates table assignments for the arrangement' do
      seating_arrangement = service.save_arrangement(arrangement_data, user)

      expect(seating_arrangement.table_assignments.count).to eq(8)
      
      table_1_assignments = seating_arrangement.table_assignments.where(table_number: 1)
      expect(table_1_assignments.count).to eq(4)
      expect(table_1_assignments.pluck(:seat_position)).to match_array([1, 2, 3, 4])
    end

    it 'returns nil for invalid arrangement data' do
      invalid_data = arrangement_data.merge(arrangement: nil)
      result = service.save_arrangement(invalid_data, user)

      expect(result).to be_nil
    end
  end

  describe '#compare_arrangements' do
    let(:arrangements) do
      [
        { id: 1, data: { 1 => students[0..3] } },
        { id: 2, data: { 1 => students[4..7] } }
      ]
    end

    it 'compares and ranks arrangements' do
      results = service.compare_arrangements(arrangements)

      expect(results).to be_an(Array)
      expect(results.length).to eq(2)
      
      results.each do |result|
        expect(result).to include(:score, :detailed_metrics)
        expect(result[:score]).to be >= 0
      end
      
      # Results should be sorted by score (descending)
      expect(results.first[:score]).to be >= results.last[:score]
    end
  end

  describe 'private methods' do
    describe '#generate_initial_arrangement' do
      it 'distributes students evenly across tables' do
        arrangement = service.send(:generate_initial_arrangement, students)

        expect(arrangement).to be_a(Hash)
        expect(arrangement.keys).to match_array([1, 2, 3])
        
        total_students_assigned = arrangement.values.sum(&:count)
        expect(total_students_assigned).to eq(students.count)
      end

      it 'respects table size limits' do
        arrangement = service.send(:generate_initial_arrangement, students)

        arrangement.each do |table_number, table_students|
          expect(table_students.count).to be <= seating_event.table_size
        end
      end
    end

    describe '#calculate_constraint_penalty' do
      let(:hard_violations) { [{ severity: :hard, message: "Hard constraint violated" }] }
      let(:soft_violations) { [{ severity: :soft, message: "Soft constraint violated" }] }

      it 'calculates penalty for hard constraints' do
        penalty = service.send(:calculate_constraint_penalty, hard_violations)
        expect(penalty).to eq(10.0)
      end

      it 'calculates penalty for soft constraints' do
        penalty = service.send(:calculate_constraint_penalty, soft_violations)
        expect(penalty).to eq(1.0)
      end

      it 'calculates combined penalty for mixed violations' do
        mixed_violations = hard_violations + soft_violations
        penalty = service.send(:calculate_constraint_penalty, mixed_violations)
        expect(penalty).to eq(11.0)
      end
    end

    describe '#determine_acceptance_reason' do
      it 'returns "improvement" for better scores' do
        reason = service.send(:determine_acceptance_reason, 0.5, 0.8, true)
        expect(reason).to eq('improvement')
      end

      it 'returns "equal_score" for same scores' do
        reason = service.send(:determine_acceptance_reason, 0.5, 0.5, true)
        expect(reason).to eq('equal_score')
      end

      it 'returns "exploration" for accepted worse scores' do
        reason = service.send(:determine_acceptance_reason, 0.8, 0.5, true)
        expect(reason).to eq('exploration')
      end

      it 'returns "rejected" for rejected arrangements' do
        reason = service.send(:determine_acceptance_reason, 0.8, 0.5, false)
        expect(reason).to eq('rejected')
      end
    end
  end

  describe 'error handling' do
    it 'raises error for unknown optimization strategy' do
      expect {
        service.optimize(strategy: :unknown_strategy)
      }.to raise_error(ArgumentError, /Unknown optimization strategy/)
    end
  end
end