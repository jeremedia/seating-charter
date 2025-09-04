require 'rails_helper'

RSpec.describe NaturalLanguageParsingService do
  let(:cohort) { create(:cohort) }
  let(:user) { create(:user) }
  let(:service) { described_class.new(cohort, user) }

  describe '#initialize' do
    it 'initializes with cohort and user' do
      expect(service.cohort).to eq(cohort)
      expect(service.user).to eq(user)
    end
  end

  describe '#parse_instructions' do
    let(:instruction_text) { "Keep John and Mary at the same table, but separate Mike from Sarah" }

    context 'with valid instruction text' do
      let(:mock_ai_response) do
        {
          "instructions" => [
            {
              "type" => "keep_together",
              "students" => ["John", "Mary"],
              "reason" => "friendship requirement"
            },
            {
              "type" => "separate",
              "students" => ["Mike", "Sarah"],
              "reason" => "behavioral management"
            }
          ]
        }
      end

      before do
        allow(OpenaiService).to receive(:call).and_return(mock_ai_response.to_json)
      end

      it 'parses instructions successfully' do
        result = service.parse_instructions(instruction_text)

        expect(result[:success]).to be true
        expect(result[:parsed_instructions]).to be_an(Array)
        expect(result[:parsed_instructions]).to have(2).items
      end

      it 'creates natural language instruction records' do
        expect {
          service.parse_instructions(instruction_text)
        }.to change { NaturalLanguageInstruction.count }.by(1)

        instruction = NaturalLanguageInstruction.last
        expect(instruction.cohort).to eq(cohort)
        expect(instruction.raw_text).to eq(instruction_text)
        expect(instruction.parsed_data).to eq(mock_ai_response)
        expect(instruction.created_by).to eq(user)
      end

      it 'includes processing metadata in result' do
        result = service.parse_instructions(instruction_text)

        expect(result[:metadata]).to include(
          :ai_model_used,
          :processing_time,
          :confidence_score
        )
      end
    end

    context 'with invalid AI response' do
      before do
        allow(OpenaiService).to receive(:call).and_return("invalid json response")
      end

      it 'handles JSON parsing errors gracefully' do
        result = service.parse_instructions(instruction_text)

        expect(result[:success]).to be false
        expect(result[:error]).to include("Failed to parse")
        expect(result[:parsed_instructions]).to be_empty
      end
    end

    context 'with OpenAI service errors' do
      before do
        allow(OpenaiService).to receive(:call).and_raise(StandardError.new("API Error"))
      end

      it 'handles service errors gracefully' do
        result = service.parse_instructions(instruction_text)

        expect(result[:success]).to be false
        expect(result[:error]).to include("API Error")
        expect(result[:parsed_instructions]).to be_empty
      end
    end

    context 'with empty instruction text' do
      it 'returns error for empty text' do
        result = service.parse_instructions("")

        expect(result[:success]).to be false
        expect(result[:error]).to include("Instruction text cannot be empty")
      end

      it 'returns error for nil text' do
        result = service.parse_instructions(nil)

        expect(result[:success]).to be false
        expect(result[:error]).to include("Instruction text cannot be empty")
      end
    end
  end

  describe '#convert_to_seating_rules' do
    let(:parsed_instructions) do
      [
        {
          "type" => "keep_together",
          "students" => ["Alice Johnson", "Bob Smith"],
          "reason" => "study partners"
        },
        {
          "type" => "separate",
          "students" => ["Carol Davis", "Dave Wilson"],
          "reason" => "behavioral issues"
        },
        {
          "type" => "balance_attribute",
          "attribute" => "grade_level",
          "reason" => "academic diversity"
        }
      ]
    end

    let!(:alice) { create(:student, cohort: cohort, first_name: "Alice", last_name: "Johnson") }
    let!(:bob) { create(:student, cohort: cohort, first_name: "Bob", last_name: "Smith") }
    let!(:carol) { create(:student, cohort: cohort, first_name: "Carol", last_name: "Davis") }
    let!(:dave) { create(:student, cohort: cohort, first_name: "Dave", last_name: "Wilson") }

    it 'converts parsed instructions to seating rules' do
      result = service.convert_to_seating_rules(parsed_instructions)

      expect(result[:success]).to be true
      expect(result[:rules_created]).to eq(3)
      expect(SeatingRule.count).to eq(3)
    end

    it 'creates keep_together rules correctly' do
      service.convert_to_seating_rules(parsed_instructions)

      keep_together_rule = SeatingRule.find_by(rule_type: 'keep_together')
      expect(keep_together_rule).to be_present
      expect(keep_together_rule.target_students).to include(alice.id, bob.id)
      expect(keep_together_rule.ai_reasoning).to eq("study partners")
      expect(keep_together_rule.created_by).to eq(user)
    end

    it 'creates separate rules correctly' do
      service.convert_to_seating_rules(parsed_instructions)

      separate_rule = SeatingRule.find_by(rule_type: 'separate')
      expect(separate_rule).to be_present
      expect(separate_rule.target_students).to include(carol.id, dave.id)
      expect(separate_rule.ai_reasoning).to eq("behavioral issues")
    end

    it 'creates balance_attribute rules correctly' do
      service.convert_to_seating_rules(parsed_instructions)

      balance_rule = SeatingRule.find_by(rule_type: 'balance')
      expect(balance_rule).to be_present
      expect(balance_rule.attribute_name).to eq("grade_level")
      expect(balance_rule.ai_reasoning).to eq("academic diversity")
    end

    context 'with students not found' do
      let(:parsed_instructions) do
        [
          {
            "type" => "keep_together",
            "students" => ["NonExistent Student", "Alice Johnson"],
            "reason" => "test rule"
          }
        ]
      end

      it 'handles missing students gracefully' do
        result = service.convert_to_seating_rules(parsed_instructions)

        expect(result[:success]).to be true
        expect(result[:warnings]).to include("Student not found: NonExistent Student")
        
        rule = SeatingRule.last
        expect(rule.target_students).to include(alice.id)
        expect(rule.target_students).not_to include("NonExistent Student")
      end
    end

    context 'with invalid instruction types' do
      let(:parsed_instructions) do
        [
          {
            "type" => "invalid_type",
            "students" => ["Alice Johnson"],
            "reason" => "test"
          }
        ]
      end

      it 'skips invalid instruction types' do
        result = service.convert_to_seating_rules(parsed_instructions)

        expect(result[:success]).to be true
        expect(result[:rules_created]).to eq(0)
        expect(result[:warnings]).to include("Unknown instruction type: invalid_type")
      end
    end
  end

  describe '#process_full_workflow' do
    let(:instruction_text) { "Keep Alice and Bob together, separate Carol from Dave" }
    let(:mock_ai_response) do
      {
        "instructions" => [
          {
            "type" => "keep_together",
            "students" => ["Alice Johnson", "Bob Smith"],
            "reason" => "friendship"
          }
        ]
      }
    end

    let!(:alice) { create(:student, cohort: cohort, first_name: "Alice", last_name: "Johnson") }
    let!(:bob) { create(:student, cohort: cohort, first_name: "Bob", last_name: "Smith") }

    before do
      allow(OpenaiService).to receive(:call).and_return(mock_ai_response.to_json)
    end

    it 'processes full workflow from text to rules' do
      result = service.process_full_workflow(instruction_text)

      expect(result[:success]).to be true
      expect(result[:parsing_result][:success]).to be true
      expect(result[:rule_conversion_result][:success]).to be true
      expect(result[:total_rules_created]).to eq(1)
    end

    it 'creates both instruction record and seating rules' do
      expect {
        service.process_full_workflow(instruction_text)
      }.to change { NaturalLanguageInstruction.count }.by(1)
       .and change { SeatingRule.count }.by(1)
    end

    it 'includes comprehensive metadata in result' do
      result = service.process_full_workflow(instruction_text)

      expect(result).to include(
        :success,
        :parsing_result,
        :rule_conversion_result,
        :total_rules_created,
        :processing_summary
      )
    end

    context 'when parsing fails' do
      before do
        allow(OpenaiService).to receive(:call).and_raise(StandardError.new("API Error"))
      end

      it 'stops workflow and returns parsing error' do
        result = service.process_full_workflow(instruction_text)

        expect(result[:success]).to be false
        expect(result[:parsing_result][:success]).to be false
        expect(result).not_to have_key(:rule_conversion_result)
      end
    end
  end

  describe '#build_ai_prompt' do
    let(:instruction_text) { "Test instruction text" }

    it 'builds comprehensive AI prompt' do
      prompt = service.send(:build_ai_prompt, instruction_text)

      expect(prompt).to include(instruction_text)
      expect(prompt).to include("JSON format")
      expect(prompt).to include("keep_together")
      expect(prompt).to include("separate")
      expect(prompt).to include("balance_attribute")
    end

    it 'includes student context from cohort' do
      create(:student, cohort: cohort, first_name: "Alice", last_name: "Johnson")
      create(:student, cohort: cohort, first_name: "Bob", last_name: "Smith")

      prompt = service.send(:build_ai_prompt, instruction_text)

      expect(prompt).to include("Alice Johnson")
      expect(prompt).to include("Bob Smith")
    end
  end

  describe '#find_student_by_name' do
    let!(:alice) { create(:student, cohort: cohort, first_name: "Alice", last_name: "Johnson") }
    let!(:bob) { create(:student, cohort: cohort, first_name: "Bob", last_name: "Smith-Jones") }

    it 'finds student by exact full name match' do
      student = service.send(:find_student_by_name, "Alice Johnson")
      expect(student).to eq(alice)
    end

    it 'finds student by case-insensitive match' do
      student = service.send(:find_student_by_name, "alice johnson")
      expect(student).to eq(alice)
    end

    it 'finds student with hyphenated last name' do
      student = service.send(:find_student_by_name, "Bob Smith-Jones")
      expect(student).to eq(bob)
    end

    it 'handles partial name matches' do
      student = service.send(:find_student_by_name, "Alice")
      expect(student).to eq(alice)
    end

    it 'returns nil for non-existent student' do
      student = service.send(:find_student_by_name, "NonExistent Student")
      expect(student).to be_nil
    end
  end

  describe 'error handling and edge cases' do
    it 'handles malformed AI responses' do
      allow(OpenaiService).to receive(:call).and_return('{"malformed": json}')
      
      result = service.parse_instructions("test instruction")
      
      expect(result[:success]).to be false
      expect(result[:error]).to include("Failed to parse")
    end

    it 'handles empty AI responses' do
      allow(OpenaiService).to receive(:call).and_return('{}')
      
      result = service.parse_instructions("test instruction")
      
      expect(result[:success]).to be false
      expect(result[:error]).to include("No instructions found")
    end

    it 'handles AI responses with empty instructions array' do
      allow(OpenaiService).to receive(:call).and_return('{"instructions": []}')
      
      result = service.parse_instructions("test instruction")
      
      expect(result[:success]).to be false
      expect(result[:error]).to include("No instructions found")
    end
  end
end