module ApplicationHelper
  def rule_type_color(rule_type)
    case rule_type
    when 'separation'
      'bg-red-100 text-red-800'
    when 'clustering'
      'bg-green-100 text-green-800'
    when 'distribution'
      'bg-blue-100 text-blue-800'
    when 'proximity'
      'bg-purple-100 text-purple-800'
    when 'custom'
      'bg-gray-100 text-gray-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end

  def instruction_border_color(status)
    case status
    when 'completed'
      'border-green-400'
    when 'processing'
      'border-blue-400'
    when 'pending'
      'border-gray-400'
    when 'failed'
      'border-red-400'
    when 'needs_review'
      'border-yellow-400'
    else
      'border-gray-400'
    end
  end

  # Export format helpers
  def format_icon(format)
    case format.to_s
    when 'pdf'
      content_tag(:svg, class: 'w-4 h-4 text-red-600', fill: 'currentColor', viewBox: '0 0 20 20') do
        content_tag(:path, '', d: 'M4 4a2 2 0 00-2 2v8a2 2 0 002 2h12a2 2 0 002-2V6a2 2 0 00-2-2h-5L9 2H4z')
      end
    when 'excel'
      content_tag(:svg, class: 'w-4 h-4 text-green-600', fill: 'currentColor', viewBox: '0 0 20 20') do
        content_tag(:path, '', d: 'M3 4a1 1 0 011-1h12a1 1 0 011 1v2a1 1 0 01-1 1H4a1 1 0 01-1-1V4zM3 10a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H4a1 1 0 01-1-1v-6zM14 9a1 1 0 00-1 1v6a1 1 0 001 1h2a1 1 0 001-1v-6a1 1 0 00-1-1h-2z')
      end
    when 'csv'
      content_tag(:svg, class: 'w-4 h-4 text-blue-600', fill: 'currentColor', viewBox: '0 0 20 20') do
        content_tag(:path, '', 'fill-rule': 'evenodd', d: 'M3 4a1 1 0 011-1h4a1 1 0 010 2H6.414l2.293 2.293a1 1 0 11-1.414 1.414L5 6.414V8a1 1 0 01-2 0V4zm9 1a1 1 0 010-2h4a1 1 0 011 1v4a1 1 0 01-2 0V6.414l-2.293 2.293a1 1 0 11-1.414-1.414L13.586 5H12zm-9 7a1 1 0 012 0v1.586l2.293-2.293a1 1 0 111.414 1.414L6.414 15H8a1 1 0 010 2H4a1 1 0 01-1-1v-4zm13-1a1 1 0 011 1v4a1 1 0 01-1 1h-4a1 1 0 010-2h1.586l-2.293-2.293a1 1 0 111.414-1.414L15 13.586V12a1 1 0 011-1z', 'clip-rule': 'evenodd')
      end
    when 'name_tags'
      content_tag(:svg, class: 'w-4 h-4 text-purple-600', fill: 'currentColor', viewBox: '0 0 20 20') do
        content_tag(:path, '', 'fill-rule': 'evenodd', d: 'M17.707 9.293a1 1 0 010 1.414l-7 7a1 1 0 01-1.414 0l-7-7A.997.997 0 012 10V5a3 3 0 013-3h5c.256 0 .512.098.707.293l7 7zM5 6a1 1 0 100-2 1 1 0 000 2z', 'clip-rule': 'evenodd')
      end
    when 'powerpoint'
      content_tag(:svg, class: 'w-4 h-4 text-orange-600', fill: 'currentColor', viewBox: '0 0 20 20') do
        content_tag(:path, '', d: 'M4 3a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V5a2 2 0 00-2-2H4zm12 12H4l4-8 3 6 2-4 3 6z')
      end
    else
      content_tag(:svg, class: 'w-4 h-4 text-gray-600', fill: 'currentColor', viewBox: '0 0 20 20') do
        content_tag(:path, '', d: 'M3 4a1 1 0 011-1h12a1 1 0 011 1v2a1 1 0 01-1 1H4a1 1 0 01-1-1V4zM3 10a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H4a1 1 0 01-1-1v-6zM14 9a1 1 0 00-1 1v6a1 1 0 001 1h2a1 1 0 001-1v-6a1 1 0 00-1-1h-2z')
      end
    end
  end

  def format_description(format)
    case format.to_s
    when 'pdf'
      'Professional seating chart with visual layout and detailed information'
    when 'excel'
      'Comprehensive spreadsheet with multiple worksheets for analysis'
    when 'csv'
      'Simple data format compatible with all spreadsheet applications'
    when 'name_tags'
      'Printable name tags and table tents for events'
    when 'powerpoint'
      'Interactive presentation slides for event introduction'
    else
      'Export format'
    end
  end

  def format_features(format)
    case format.to_s
    when 'pdf'
      'Print-ready'
    when 'excel'
      'Multi-sheet'
    when 'csv'
      'Universal'
    when 'name_tags'
      'Printable'
    when 'powerpoint'
      'Interactive'
    else
      'Standard'
    end
  end
end
