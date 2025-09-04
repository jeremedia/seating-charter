require 'rails_helper'

RSpec.describe Student, type: :model do
  let(:cohort) { create(:cohort) }
  let(:student) { create(:student, cohort: cohort) }

  describe 'associations' do
    it { should belong_to(:cohort) }
    it { should have_many(:student_import_records).dependent(:destroy) }
    it { should have_many(:table_assignments).dependent(:destroy) }
    it { should have_many(:seating_arrangements).through(:table_assignments) }
    it { should have_many(:student_a_interactions).class_name('InteractionTracking').with_foreign_key('student_a_id').dependent(:destroy) }
    it { should have_many(:student_b_interactions).class_name('InteractionTracking').with_foreign_key('student_b_id').dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(255) }
    it { should validate_length_of(:title).is_at_most(500) }
    it { should validate_length_of(:organization).is_at_most(500) }
    it { should validate_length_of(:location).is_at_most(255) }
  end

  describe 'scopes' do
    let!(:student1) { create(:student, cohort: cohort) }
    let!(:student2) { create(:student) }

    describe '.by_cohort' do
      it 'returns students for specified cohort' do
        result = Student.by_cohort(cohort)
        expect(result).to include(student1)
        expect(result).not_to include(student2)
      end
    end

    describe '.with_attribute' do
      before do
        student1.set_attribute('department', 'IT')
        student1.save!
        student2.set_attribute('department', 'HR')
        student2.save!
      end

      it 'returns students with matching attribute' do
        result = Student.with_attribute('department', 'IT')
        expect(result).to include(student1)
        expect(result).not_to include(student2)
      end
    end

    describe '.with_inference' do
      before do
        student1.set_inference('gender', 'male', 0.9)
        student1.save!
        student2.set_inference('gender', 'female', 0.8)
        student2.save!
      end

      it 'returns students with matching inference value' do
        result = Student.with_inference('gender', 'male')
        expect(result).to include(student1)
        expect(result).not_to include(student2)
      end
    end
  end

  describe 'callbacks' do
    describe '#normalize_data' do
      it 'normalizes name with titleize' do
        student = create(:student, name: 'john doe')
        expect(student.name).to eq('John Doe')
      end

      it 'strips whitespace from organization' do
        student = create(:student, organization: '  FBI  ')
        expect(student.organization).to eq('FBI')
      end

      it 'strips whitespace from location' do
        student = create(:student, location: '  Washington, DC  ')
        expect(student.location).to eq('Washington, DC')
      end

      it 'strips whitespace from title' do
        student = create(:student, title: '  Special Agent  ')
        expect(student.title).to eq('Special Agent')
      end
    end
  end

  describe 'instance methods' do
    describe '#full_name' do
      it 'returns the name' do
        expect(student.full_name).to eq(student.name)
      end
    end

    describe '#display_organization' do
      context 'when organization is present' do
        let(:student) { create(:student, organization: 'FBI') }

        it 'returns the organization' do
          expect(student.display_organization).to eq('FBI')
        end
      end

      context 'when organization is blank' do
        let(:student) { create(:student, organization: '') }

        it 'returns Unknown Organization' do
          expect(student.display_organization).to eq('Unknown Organization')
        end
      end
    end

    describe '#display_location' do
      context 'when location is present' do
        let(:student) { create(:student, location: 'Washington, DC') }

        it 'returns the location' do
          expect(student.display_location).to eq('Washington, DC')
        end
      end

      context 'when location is blank' do
        let(:student) { create(:student, location: '') }

        it 'returns Unknown Location' do
          expect(student.display_location).to eq('Unknown Location')
        end
      end
    end

    describe 'attribute methods' do
      describe '#get_attribute and #set_attribute' do
        it 'sets and gets custom attributes' do
          student.set_attribute('department', 'Law Enforcement')
          student.save!

          expect(student.get_attribute('department')).to eq('Law Enforcement')
        end

        it 'returns nil for non-existent attributes' do
          expect(student.get_attribute('nonexistent')).to be_nil
        end

        it 'initializes student_attributes hash if nil' do
          student.student_attributes = nil
          student.set_attribute('test', 'value')

          expect(student.student_attributes).to eq({ 'test' => 'value' })
        end
      end
    end

    describe 'inference methods' do
      before do
        student.set_inference('gender', 'male', 0.95)
        student.set_inference('agency_level', 'federal', 0.87)
        student.save!
      end

      describe '#get_inference' do
        it 'returns inference hash' do
          inference = student.get_inference('gender')
          expect(inference).to eq({ 'value' => 'male', 'confidence' => 0.95 })
        end
      end

      describe '#get_inference_value' do
        it 'returns inference value' do
          expect(student.get_inference_value('gender')).to eq('male')
        end

        it 'returns nil for non-existent inference' do
          expect(student.get_inference_value('nonexistent')).to be_nil
        end
      end

      describe '#get_inference_confidence' do
        it 'returns inference confidence' do
          expect(student.get_inference_confidence('gender')).to eq(0.95)
        end

        it 'returns 0.0 for non-existent inference' do
          expect(student.get_inference_confidence('nonexistent')).to eq(0.0)
        end
      end

      describe '#set_inference' do
        it 'sets inference with value and confidence' do
          student.set_inference('department_type', 'law_enforcement', 0.82)

          inference = student.get_inference('department_type')
          expect(inference['value']).to eq('law_enforcement')
          expect(inference['confidence']).to eq(0.82)
        end

        it 'sets inference with value only' do
          student.set_inference('seniority_level', 'senior')

          inference = student.get_inference('seniority_level')
          expect(inference['value']).to eq('senior')
          expect(inference).not_to have_key('confidence')
        end
      end

      describe '#high_confidence_inferences' do
        before do
          student.set_inference('low_conf', 'value1', 0.6)
          student.set_inference('high_conf', 'value2', 0.95)
        end

        it 'returns inferences with confidence >= 0.9' do
          high_conf = student.high_confidence_inferences
          expect(high_conf).to have_key('high_conf')
          expect(high_conf).to have_key('gender')  # 0.95 from before block
          expect(high_conf).not_to have_key('low_conf')
        end
      end

      describe '#low_confidence_inferences' do
        before do
          student.set_inference('low_conf', 'value1', 0.6)
          student.set_inference('high_conf', 'value2', 0.95)
        end

        it 'returns inferences with confidence < 0.7' do
          low_conf = student.low_confidence_inferences
          expect(low_conf).to have_key('low_conf')
          expect(low_conf).not_to have_key('high_conf')
          expect(low_conf).not_to have_key('gender')  # 0.95 from before block
        end
      end
    end

    describe 'inference field helpers' do
      before do
        student.set_inference('gender', 'female', 0.88)
        student.set_inference('agency_level', 'state', 0.91)
        student.set_inference('department_type', 'emergency_services', 0.79)
        student.set_inference('seniority_level', 'mid', 0.83)
        student.save!
      end

      describe '#gender and #gender_confidence' do
        it 'returns gender value and confidence' do
          expect(student.gender).to eq('female')
          expect(student.gender_confidence).to eq(0.88)
        end
      end

      describe '#agency_level and #agency_level_confidence' do
        it 'returns agency level value and confidence' do
          expect(student.agency_level).to eq('state')
          expect(student.agency_level_confidence).to eq(0.91)
        end
      end

      describe '#department_type and #department_type_confidence' do
        it 'returns department type value and confidence' do
          expect(student.department_type).to eq('emergency_services')
          expect(student.department_type_confidence).to eq(0.79)
        end
      end

      describe '#seniority_level and #seniority_level_confidence' do
        it 'returns seniority level value and confidence' do
          expect(student.seniority_level).to eq('mid')
          expect(student.seniority_level_confidence).to eq(0.83)
        end
      end
    end

    describe '#confidence_color_class' do
      it 'returns green class for high confidence' do
        student.set_inference('test', 'value', 0.95)
        expect(student.confidence_color_class('test')).to eq('text-green-600')
      end

      it 'returns yellow class for medium confidence' do
        student.set_inference('test', 'value', 0.8)
        expect(student.confidence_color_class('test')).to eq('text-yellow-600')
      end

      it 'returns red class for low confidence' do
        student.set_inference('test', 'value', 0.5)
        expect(student.confidence_color_class('test')).to eq('text-red-600')
      end
    end

    describe '#all_interactions' do
      let(:other_student) { create(:student, cohort: cohort) }
      let!(:interaction1) { create(:interaction_tracking, student_a: student, student_b: other_student, cohort: cohort) }
      let!(:interaction2) { create(:interaction_tracking, student_a: other_student, student_b: student, cohort: cohort) }
      let!(:unrelated_interaction) { create(:interaction_tracking) }

      it 'returns all interactions involving the student in the same cohort' do
        interactions = student.all_interactions
        expect(interactions).to include(interaction1, interaction2)
        expect(interactions).not_to include(unrelated_interaction)
      end
    end
  end

  describe 'edge cases' do
    context 'with nil inferences' do
      let(:student) { create(:student, inferences: nil) }

      it 'handles nil inferences gracefully' do
        expect(student.get_inference_value('gender')).to be_nil
        expect(student.get_inference_confidence('gender')).to eq(0.0)
        expect(student.high_confidence_inferences).to eq([])
        expect(student.low_confidence_inferences).to eq([])
      end
    end

    context 'with malformed inference data' do
      it 'handles malformed inference data' do
        student.inferences = { 'gender' => 'invalid_structure' }
        student.save!

        expect(student.get_inference_confidence('gender')).to eq(0.0)
      end
    end
  end
end