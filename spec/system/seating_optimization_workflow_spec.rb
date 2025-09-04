require 'rails_helper'

RSpec.describe 'Seating Optimization Workflow', type: :system do
  let(:user) { create(:user, :confirmed) }
  let(:cohort) { create(:cohort, user: user, :with_students, students_count: 20) }
  let(:seating_event) { create(:seating_event, cohort: cohort, :ready_for_optimization) }

  before do
    # Mock OpenAI service to avoid API calls in tests
    allow(OpenaiService).to receive(:configured?).and_return(true)
    allow(OpenaiService).to receive(:call).and_return('{"instructions": []}')
    
    sign_in user
  end

  describe 'Full optimization workflow' do
    it 'allows user to create and optimize a seating arrangement', :js do
      visit cohort_seating_event_path(cohort, seating_event)
      
      # Should see the seating event details
      expect(page).to have_content(seating_event.name)
      expect(page).to have_content("#{seating_event.cohort.students.count} students")
      
      # Start optimization
      click_button 'Optimize Seating'
      
      # Should see optimization in progress
      expect(page).to have_content('Optimization in progress')
      
      # Wait for optimization to complete (mocked to be fast)
      expect(page).to have_content('Optimization completed', wait: 10)
      
      # Should see the results
      expect(page).to have_content('Final Score')
      expect(page).to have_content('Diversity Metrics')
      
      # Should be able to save the arrangement
      click_button 'Save Arrangement'
      expect(page).to have_content('Arrangement saved successfully')
    end
  end

  describe 'Multi-day optimization workflow' do
    let(:seating_event) { create(:seating_event, :multi_day, cohort: cohort) }

    it 'creates multi-day arrangements with interaction tracking' do
      visit cohort_seating_event_path(cohort, seating_event)
      
      click_button 'Create Multi-Day Series'
      
      # Configure multi-day settings
      fill_in 'Number of Days', with: '3'
      select 'Maximum Interaction Novelty', from: 'Rotation Strategy'
      
      click_button 'Generate Series'
      
      # Should create arrangements for each day
      expect(page).to have_content('Day 1 Arrangement')
      expect(page).to have_content('Day 2 Arrangement')  
      expect(page).to have_content('Day 3 Arrangement')
      
      # Should show interaction novelty metrics
      expect(page).to have_content('New Interactions')
      expect(page).to have_content('Repeated Interactions')
    end
  end

  describe 'Natural language rule creation' do
    it 'allows users to create rules using natural language' do
      visit cohort_seating_event_path(cohort, seating_event)
      
      click_link 'Add Rules'
      
      # Use natural language input
      fill_in 'Natural Language Rule', with: 'Keep federal agents separate from local police'
      
      click_button 'Parse and Create Rule'
      
      # Should parse the rule and create seating rule
      expect(page).to have_content('Rule created successfully')
      expect(page).to have_content('separation')
      
      # Should apply rule in optimization
      click_button 'Optimize with Rules'
      
      expect(page).to have_content('Rules applied during optimization')
    end
  end

  describe 'Drag and drop seating editor' do
    let!(:arrangement) { create(:seating_arrangement, seating_event: seating_event, :with_table_assignments) }

    it 'allows manual editing of seating arrangements', :js do
      visit edit_cohort_seating_event_seating_arrangement_path(cohort, seating_event, arrangement)
      
      # Should show interactive seating chart
      expect(page).to have_css('.seating-chart')
      expect(page).to have_css('.table-container')
      expect(page).to have_css('.student-card')
      
      # Should be able to drag students between tables
      student_card = first('.student-card')
      target_table = all('.table-container').last
      
      student_card.drag_to(target_table)
      
      # Should show live diversity metrics
      expect(page).to have_css('.diversity-metrics')
      expect(page).to have_content('Diversity Score')
      
      # Should be able to save changes
      click_button 'Save Changes'
      expect(page).to have_content('Arrangement updated successfully')
    end
  end

  describe 'Export functionality' do
    let!(:arrangement) { create(:seating_arrangement, seating_event: seating_event, :with_explanations) }

    it 'exports seating arrangement to PDF' do
      visit cohort_seating_event_seating_arrangement_path(cohort, seating_event, arrangement)
      
      click_link 'Export PDF'
      
      # Should generate and download PDF
      expect(page.response_headers['Content-Type']).to eq('application/pdf')
    end

    it 'exports seating arrangement to Excel' do
      visit cohort_seating_event_seating_arrangement_path(cohort, seating_event, arrangement)
      
      click_link 'Export Excel'
      
      # Should generate and download Excel file
      expect(page.response_headers['Content-Type']).to include('spreadsheet')
    end
  end

  describe 'Error handling' do
    context 'when optimization fails' do
      before do
        allow_any_instance_of(SeatingOptimizationService).to receive(:optimize).and_return({ success: false, error: 'Optimization failed' })
      end

      it 'displays error message gracefully' do
        visit cohort_seating_event_path(cohort, seating_event)
        
        click_button 'Optimize Seating'
        
        expect(page).to have_content('Optimization failed')
        expect(page).to have_content('Please try again')
      end
    end

    context 'when insufficient students' do
      let(:cohort) { create(:cohort, user: user) }  # No students
      
      it 'prevents optimization with helpful message' do
        visit cohort_seating_event_path(cohort, seating_event)
        
        expect(page).to have_content('Need at least 2 students')
        expect(page).not_to have_button('Optimize Seating')
      end
    end
  end

  describe 'Performance monitoring' do
    it 'tracks optimization performance metrics' do
      visit cohort_seating_event_path(cohort, seating_event)
      
      click_button 'Optimize Seating'
      
      # Should display performance metrics
      expect(page).to have_content('Runtime:', wait: 10)
      expect(page).to have_content('Iterations:')
      expect(page).to have_content('Improvements:')
    end
  end

  describe 'Accessibility features' do
    it 'provides accessible navigation and controls' do
      visit cohort_seating_event_path(cohort, seating_event)
      
      # Check for ARIA labels and roles
      expect(page).to have_css('[role="main"]')
      expect(page).to have_css('[aria-label]')
      
      # Should be keyboard navigable
      find('button', text: 'Optimize Seating').send_keys(:enter)
      expect(page).to have_content('Optimization in progress')
    end

    it 'provides screen reader friendly content' do
      visit cohort_seating_event_path(cohort, seating_event)
      
      # Should have descriptive headings and labels
      expect(page).to have_css('h1, h2, h3')
      expect(page).to have_css('label[for]')
      
      # Should provide status updates for screen readers
      expect(page).to have_css('[aria-live]')
    end
  end
end