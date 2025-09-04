require 'prawn'
require 'prawn/table'

module Exports
  class NameTagExportService < ExportService
    # Standard name tag formats (dimensions in points - 72 points per inch)
    NAME_TAG_FORMATS = {
      'avery_5395' => { 
        width: 171, height: 108, # 2.375" x 1.5"
        per_page: 30, rows: 10, cols: 3,
        margin_top: 36, margin_left: 36, 
        spacing_x: 18, spacing_y: 0
      },
      'avery_74459' => { 
        width: 252, height: 144, # 3.5" x 2"  
        per_page: 10, rows: 5, cols: 2,
        margin_top: 36, margin_left: 36,
        spacing_x: 18, spacing_y: 18
      },
      'table_tent' => { 
        width: 288, height: 216, # 4" x 3" (folded)
        per_page: 4, rows: 2, cols: 2,
        margin_top: 72, margin_left: 72,
        spacing_x: 36, spacing_y: 36
      },
      'badge_large' => { 
        width: 216, height: 144, # 3" x 2"
        per_page: 8, rows: 4, cols: 2,
        margin_top: 36, margin_left: 108,
        spacing_x: 72, spacing_y: 36
      }
    }.freeze

    def generate
      format_type = @export_options[:name_tag_format] || 'avery_5395'
      
      case @export_options[:name_tag_style] || 'standard'
      when 'table_tent'
        generate_table_tents
      when 'badge'
        generate_name_badges(format_type)
      when 'simple'
        generate_simple_name_tags(format_type)
      else
        generate_standard_name_tags(format_type)
      end
    end

    private

    def generate_standard_name_tags(format_type)
      format_config = NAME_TAG_FORMATS[format_type]
      
      pdf = Prawn::Document.new(
        page_size: paper_size_for_prawn,
        margin: [format_config[:margin_top], 36, 36, format_config[:margin_left]]
      )
      
      current_page_tags = 0
      tags_per_page = format_config[:per_page]
      
      students.each_with_index do |student, index|
        # Start new page if needed
        if current_page_tags >= tags_per_page
          pdf.start_new_page
          current_page_tags = 0
        end
        
        # Calculate position
        row = current_page_tags / format_config[:cols]
        col = current_page_tags % format_config[:cols]
        
        x = col * (format_config[:width] + format_config[:spacing_x])
        y = pdf.bounds.height - (row * (format_config[:height] + format_config[:spacing_y]))
        
        draw_standard_name_tag(pdf, student, x, y - format_config[:height], format_config)
        current_page_tags += 1
      end
      
      temp_path = temp_file_path('pdf')
      pdf.render_file(temp_path)
      
      {
        file_path: temp_path,
        filename: export_filename('pdf').sub('.pdf', '_name_tags.pdf'),
        content_type: 'application/pdf'
      }
    end

    def generate_table_tents
      format_config = NAME_TAG_FORMATS['table_tent']
      
      pdf = Prawn::Document.new(
        page_size: paper_size_for_prawn,
        margin: [format_config[:margin_top], 36, 36, format_config[:margin_left]]
      )
      
      # Group students by table for table tents
      current_page_tents = 0
      tents_per_page = format_config[:per_page]
      
      tables_data.each do |table_number, table_info|
        # Start new page if needed
        if current_page_tents >= tents_per_page
          pdf.start_new_page  
          current_page_tents = 0
        end
        
        # Calculate position
        row = current_page_tents / format_config[:cols]
        col = current_page_tents % format_config[:cols]
        
        x = col * (format_config[:width] + format_config[:spacing_x])
        y = pdf.bounds.height - (row * (format_config[:height] + format_config[:spacing_y]))
        
        draw_table_tent(pdf, table_number, table_info, x, y - format_config[:height], format_config)
        current_page_tents += 1
      end
      
      temp_path = temp_file_path('pdf')
      pdf.render_file(temp_path)
      
      {
        file_path: temp_path,
        filename: export_filename('pdf').sub('.pdf', '_table_tents.pdf'),
        content_type: 'application/pdf'
      }
    end

    def generate_name_badges(format_type)
      format_config = NAME_TAG_FORMATS[format_type]
      
      pdf = Prawn::Document.new(
        page_size: paper_size_for_prawn,
        margin: [format_config[:margin_top], 36, 36, format_config[:margin_left]]
      )
      
      current_page_badges = 0
      badges_per_page = format_config[:per_page]
      
      students.each do |student|
        # Start new page if needed
        if current_page_badges >= badges_per_page
          pdf.start_new_page
          current_page_badges = 0
        end
        
        # Calculate position
        row = current_page_badges / format_config[:cols]
        col = current_page_badges % format_config[:cols]
        
        x = col * (format_config[:width] + format_config[:spacing_x])
        y = pdf.bounds.height - (row * (format_config[:height] + format_config[:spacing_y]))
        
        draw_name_badge(pdf, student, x, y - format_config[:height], format_config)
        current_page_badges += 1
      end
      
      temp_path = temp_file_path('pdf')
      pdf.render_file(temp_path)
      
      {
        file_path: temp_path,
        filename: export_filename('pdf').sub('.pdf', '_badges.pdf'),
        content_type: 'application/pdf'
      }
    end

    def generate_simple_name_tags(format_type)
      format_config = NAME_TAG_FORMATS[format_type]
      
      pdf = Prawn::Document.new(
        page_size: paper_size_for_prawn,
        margin: [format_config[:margin_top], 36, 36, format_config[:margin_left]]
      )
      
      current_page_tags = 0
      tags_per_page = format_config[:per_page]
      
      students.each do |student|
        # Start new page if needed
        if current_page_tags >= tags_per_page
          pdf.start_new_page
          current_page_tags = 0
        end
        
        # Calculate position
        row = current_page_tags / format_config[:cols]
        col = current_page_tags % format_config[:cols]
        
        x = col * (format_config[:width] + format_config[:spacing_x])
        y = pdf.bounds.height - (row * (format_config[:height] + format_config[:spacing_y]))
        
        draw_simple_name_tag(pdf, student, x, y - format_config[:height], format_config)
        current_page_tags += 1
      end
      
      temp_path = temp_file_path('pdf')
      pdf.render_file(temp_path)
      
      {
        file_path: temp_path,
        filename: export_filename('pdf').sub('.pdf', '_simple_tags.pdf'),
        content_type: 'application/pdf'
      }
    end

    def draw_standard_name_tag(pdf, student, x, y, format_config)
      # Get table assignment
      assignment = student.table_assignments.find { |ta| ta.seating_arrangement == @seating_arrangement }
      
      pdf.bounding_box([x, y + format_config[:height]], 
                       width: format_config[:width], 
                       height: format_config[:height]) do
        
        # Border
        pdf.stroke_bounds if @export_options[:include_borders] != false
        
        # Background color based on table (optional)
        if @export_options[:color_by_table]
          pdf.fill_color table_color(assignment.table_number)
          pdf.fill_rectangle([0, format_config[:height]], format_config[:width], format_config[:height])
          pdf.fill_color '000000'
        end
        
        # Organization/Event header
        pdf.move_down 8
        pdf.font 'Helvetica', size: 8
        pdf.fill_color branding_options[:primary_color] || '666666'
        pdf.text branding_options[:organization_name] || 'CHDS', align: :center
        
        # Student name (largest text)
        pdf.move_down 8
        pdf.fill_color '000000'
        name_size = calculate_name_font_size(format_student_name(student), format_config[:width])
        pdf.font 'Helvetica', style: :bold, size: name_size
        pdf.text format_student_name(student), align: :center
        
        # Title
        pdf.move_down 4
        pdf.font 'Helvetica', size: 9
        pdf.text format_student_title(student), 
                 align: :center, 
                 overflow: :truncate,
                 single_line: true
        
        # Organization  
        pdf.move_down 3
        pdf.font 'Helvetica', size: 8
        pdf.text format_student_organization(student),
                 align: :center,
                 overflow: :truncate,
                 single_line: true
        
        # Table number
        if @export_options[:include_table_number] != false
          pdf.move_down 4
          pdf.font 'Helvetica', style: :bold, size: 10
          pdf.fill_color branding_options[:secondary_color] || '3b82f6'
          pdf.text "Table #{assignment.table_number}", align: :center
        end
        
        # QR Code placeholder (if requested)
        if @export_options[:include_qr_code]
          draw_qr_code_placeholder(pdf, 20, 20, format_config)
        end
      end
    end

    def draw_table_tent(pdf, table_number, table_info, x, y, format_config)
      pdf.bounding_box([x, y + format_config[:height]], 
                       width: format_config[:width], 
                       height: format_config[:height]) do
        
        # Border
        pdf.stroke_bounds
        
        # Draw fold line in middle
        fold_y = format_config[:height] / 2
        pdf.dash(2)
        pdf.stroke_horizontal_line(0, format_config[:width], at: fold_y)
        pdf.undash
        
        # Top section (visible when folded)
        pdf.bounding_box([0, format_config[:height]], 
                         width: format_config[:width], 
                         height: format_config[:height] / 2) do
          
          pdf.move_down 10
          pdf.font 'Helvetica', style: :bold, size: 18
          pdf.fill_color branding_options[:secondary_color] || '3b82f6'
          pdf.text "TABLE #{table_number}", align: :center
          
          pdf.move_down 8
          pdf.font 'Helvetica', size: 10
          pdf.fill_color '000000'
          pdf.text seating_event.name, align: :center
          
          if @seating_arrangement.multi_day?
            pdf.move_down 4
            pdf.font 'Helvetica', size: 9
            pdf.text @seating_arrangement.day_name, align: :center
          end
        end
        
        # Bottom section (student list)
        pdf.bounding_box([0, fold_y], 
                         width: format_config[:width], 
                         height: format_config[:height] / 2) do
          
          pdf.move_down 8
          pdf.font 'Helvetica', style: :bold, size: 10
          pdf.text "Students:", align: :center
          
          pdf.move_down 6
          pdf.font 'Helvetica', size: 8
          
          table_info[:students].each_with_index do |student, idx|
            break if idx >= 6 # Limit for space
            
            student_line = format_student_name(student)
            if @export_options[:include_organization_on_tent]
              org = format_student_organization(student)
              student_line += " (#{org[0..15]})" if org.present?
            end
            
            pdf.text "• #{student_line}", align: :left
          end
          
          if table_info[:students].count > 6
            pdf.text "+ #{table_info[:students].count - 6} more", 
                     align: :center, 
                     style: :italic
          end
        end
      end
    end

    def draw_name_badge(pdf, student, x, y, format_config)
      assignment = student.table_assignments.find { |ta| ta.seating_arrangement == @seating_arrangement }
      
      pdf.bounding_box([x, y + format_config[:height]], 
                       width: format_config[:width], 
                       height: format_config[:height]) do
        
        # Border with rounded corners effect
        pdf.stroke_bounds
        
        # Header with organization branding
        header_height = 20
        pdf.fill_color branding_options[:primary_color] || '1f2937'
        pdf.fill_rectangle([0, format_config[:height]], format_config[:width], header_height)
        
        pdf.fill_color 'FFFFFF'
        pdf.font 'Helvetica', style: :bold, size: 10
        pdf.text_box branding_options[:organization_name] || 'CHDS',
                     at: [5, format_config[:height] - 5],
                     width: format_config[:width] - 10,
                     height: header_height - 10,
                     align: :center,
                     valign: :center
        
        # Student name section
        pdf.fill_color '000000'
        name_y = format_config[:height] - header_height - 15
        
        name_size = calculate_name_font_size(format_student_name(student), format_config[:width] - 20)
        pdf.font 'Helvetica', style: :bold, size: name_size
        pdf.text_box format_student_name(student),
                     at: [10, name_y],
                     width: format_config[:width] - 20,
                     height: 30,
                     align: :center,
                     valign: :center
        
        # Title and organization
        info_y = name_y - 40
        pdf.font 'Helvetica', size: 9
        pdf.text_box format_student_title(student),
                     at: [10, info_y],
                     width: format_config[:width] - 20,
                     height: 12,
                     align: :center,
                     overflow: :truncate,
                     single_line: true
        
        pdf.font 'Helvetica', size: 8
        pdf.text_box format_student_organization(student),
                     at: [10, info_y - 15],
                     width: format_config[:width] - 20,
                     height: 12,
                     align: :center,
                     overflow: :truncate,
                     single_line: true
        
        # Table number badge
        if @export_options[:include_table_number] != false
          table_badge_size = 30
          pdf.fill_color branding_options[:secondary_color] || '3b82f6'
          pdf.fill_circle([format_config[:width] - 25, 25], 15)
          
          pdf.fill_color 'FFFFFF'
          pdf.font 'Helvetica', style: :bold, size: 10
          pdf.text_box "#{assignment.table_number}",
                       at: [format_config[:width] - 35, 30],
                       width: 20,
                       height: 10,
                       align: :center
        end
      end
    end

    def draw_simple_name_tag(pdf, student, x, y, format_config)
      pdf.bounding_box([x, y + format_config[:height]], 
                       width: format_config[:width], 
                       height: format_config[:height]) do
        
        # Simple border
        pdf.stroke_bounds if @export_options[:include_borders] != false
        
        # Just name, centered and large
        pdf.move_down format_config[:height] / 3
        
        name_size = calculate_name_font_size(format_student_name(student), format_config[:width] - 20)
        pdf.font 'Helvetica', style: :bold, size: name_size
        pdf.text format_student_name(student), align: :center
        
        # Optional table number
        if @export_options[:include_table_number] != false
          assignment = student.table_assignments.find { |ta| ta.seating_arrangement == @seating_arrangement }
          pdf.move_down 10
          pdf.font 'Helvetica', size: 12
          pdf.fill_color branding_options[:secondary_color] || '666666'
          pdf.text "Table #{assignment.table_number}", align: :center
        end
      end
    end

    def calculate_name_font_size(name, available_width)
      # Calculate appropriate font size based on name length and available width
      base_size = 14
      char_width_ratio = 0.6
      
      estimated_width = name.length * base_size * char_width_ratio
      
      if estimated_width > available_width - 20
        # Scale down the font size
        scale_factor = (available_width - 20) / estimated_width
        [base_size * scale_factor, 8].max.round
      else
        base_size
      end
    end

    def table_color(table_number)
      # Rotate through a set of light colors for table identification
      colors = ['FFE5E5', 'E5F3FF', 'E5FFE5', 'FFF5E5', 'F5E5FF', 'E5FFFF']
      colors[(table_number - 1) % colors.length]
    end

    def draw_qr_code_placeholder(pdf, width, height, format_config)
      # Placeholder for QR code - would need rqrcode gem for actual implementation
      qr_x = format_config[:width] - width - 5
      qr_y = 5
      
      pdf.stroke_rectangle([qr_x, qr_y + height], width, height)
      pdf.font 'Helvetica', size: 6
      pdf.text_box "QR",
                   at: [qr_x + width/2 - 5, qr_y + height/2 + 2],
                   width: 10,
                   height: 8,
                   align: :center
    end

    def page_size_for_prawn
      case paper_size.upcase
      when 'A4'
        'A4'
      when 'LEGAL'
        'LEGAL'
      else
        'LETTER'
      end
    end
  end
end