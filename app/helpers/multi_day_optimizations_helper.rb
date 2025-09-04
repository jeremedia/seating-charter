# frozen_string_literal: true

module MultiDayOptimizationsHelper
  def rotation_strategy_description(strategy)
    RotationStrategyService::ROTATION_STRATEGIES[strategy.to_sym] || 'Unknown strategy'
  end

  def format_interaction_coverage(percentage)
    case percentage
    when 0...50
      content_tag(:span, "#{percentage.round(1)}%", class: "text-red-600 font-medium")
    when 50...75
      content_tag(:span, "#{percentage.round(1)}%", class: "text-yellow-600 font-medium")
    else
      content_tag(:span, "#{percentage.round(1)}%", class: "text-green-600 font-medium")
    end
  end

  def format_diversity_score(score)
    percentage = (score * 100).round(1)
    css_class = case percentage
                when 0...60
                  "text-red-600"
                when 60...80
                  "text-yellow-600"
                else
                  "text-green-600"
                end
    
    content_tag(:span, "#{percentage}%", class: css_class)
  end

  def interaction_strength_badge(strength)
    css_classes = {
      high: "bg-red-100 text-red-800",
      medium: "bg-yellow-100 text-yellow-800",
      low: "bg-green-100 text-green-800",
      none: "bg-gray-100 text-gray-800"
    }

    content_tag(
      :span,
      strength.to_s.capitalize,
      class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{css_classes[strength.to_sym]}"
    )
  end

  def day_score_indicator(score)
    percentage = (score * 100).round(0)
    
    content_tag(
      :div,
      percentage.to_s,
      class: "w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold text-white #{score_background_color(score)}"
    )
  end

  def workshop_day_calendar_class(day_number, arrangement_present, score = nil)
    base_classes = ["p-2", "border", "border-gray-200", "rounded", "min-h-[100px]"]
    
    if arrangement_present
      base_classes << "bg-purple-50 border-purple-300"
      
      if score
        if score > 0.8
          base_classes << "ring-2 ring-green-400"
        elsif score < 0.6
          base_classes << "ring-2 ring-red-400"
        end
      end
    else
      base_classes << "bg-gray-50"
    end
    
    base_classes.join(" ")
  end

  def format_runtime(seconds)
    if seconds < 60
      "#{seconds.round(1)}s"
    else
      minutes = (seconds / 60).floor
      remaining_seconds = (seconds % 60).round(0)
      "#{minutes}m #{remaining_seconds}s"
    end
  end

  def progress_bar(percentage, message = nil)
    content_tag :div, class: "w-full bg-gray-200 rounded-full h-2.5" do
      content_tag :div, "", 
                  class: "bg-purple-600 h-2.5 rounded-full transition-all duration-300",
                  style: "width: #{[percentage, 100].min}%"
    end + (message ? content_tag(:p, message, class: "text-sm text-gray-600 mt-1") : "")
  end

  def multi_day_breadcrumb(cohort, seating_event, current_page = nil)
    breadcrumbs = []
    breadcrumbs << link_to("Dashboard", root_path, class: "text-purple-600 hover:text-purple-800")
    breadcrumbs << link_to(cohort.name, cohort_path(cohort), class: "text-purple-600 hover:text-purple-800")
    breadcrumbs << link_to(seating_event.name, cohort_seating_event_path(cohort, seating_event), class: "text-purple-600 hover:text-purple-800")
    
    if current_page
      breadcrumbs << content_tag(:span, current_page, class: "text-gray-900")
    end
    
    safe_join(breadcrumbs, content_tag(:span, " / ", class: "mx-2 text-gray-400"))
  end

  def student_interaction_summary(student, interaction_data)
    return "No interactions" unless interaction_data

    total = interaction_data[:total_interactions] || 0
    partners = interaction_data[:unique_partners] || 0
    
    "#{total} interactions with #{pluralize(partners, 'student')}"
  end

  def table_diversity_indicator(table_number, diversity_score)
    score_class = case diversity_score
                  when 0...0.5
                    "bg-red-100 text-red-800 border-red-300"
                  when 0.5...0.75
                    "bg-yellow-100 text-yellow-800 border-yellow-300"
                  else
                    "bg-green-100 text-green-800 border-green-300"
                  end

    content_tag(
      :div,
      "#{(diversity_score * 100).round(0)}%",
      class: "inline-flex items-center px-2 py-1 rounded-md text-xs font-medium border #{score_class}",
      title: "Table #{table_number} diversity score"
    )
  end

  def optimization_status_badge(status)
    badge_classes = {
      'processing' => 'bg-blue-100 text-blue-800 animate-pulse',
      'completed' => 'bg-green-100 text-green-800',
      'failed' => 'bg-red-100 text-red-800',
      'pending' => 'bg-yellow-100 text-yellow-800'
    }

    content_tag(
      :span,
      status.humanize,
      class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{badge_classes[status] || 'bg-gray-100 text-gray-800'}"
    )
  end

  def workshop_timeline_marker(day_number, is_active: false, is_completed: false)
    base_classes = ["w-4", "h-4", "rounded-full", "border-2"]
    
    if is_completed
      base_classes += ["bg-green-500", "border-green-500"]
    elsif is_active
      base_classes += ["bg-purple-500", "border-purple-500", "animate-pulse"]
    else
      base_classes += ["bg-white", "border-gray-300"]
    end

    content_tag(:div, "", class: base_classes.join(" "))
  end

  # Helper methods for calendar view
  def get_workshop_day_for_date(date)
    # This would be implemented to match dates with workshop days
    # For now, return nil as placeholder
    nil
  end

  def calculate_day_interactions(tables)
    total_interactions = 0
    tables.each do |table_number, students|
      total_interactions += students.combination(2).count if students.respond_to?(:combination)
    end
    total_interactions
  end

  def get_student_interaction_count(student, day_number)
    # This would query actual interaction data
    # For now, return placeholder
    rand(1..5)
  end

  private

  def score_background_color(score)
    case score
    when 0...0.6
      "bg-red-500"
    when 0.6...0.8
      "bg-yellow-500"
    else
      "bg-green-500"
    end
  end
end