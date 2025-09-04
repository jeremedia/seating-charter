module Exports
  class PowerpointExportService < ExportService
    def generate
      # Since there's no direct PowerPoint gem, we'll generate an HTML presentation
      # that can be easily imported to PowerPoint or used as-is
      
      case @export_options[:presentation_style] || 'slides'
      when 'handout'
        generate_handout_html
      when 'speaker_notes'
        generate_speaker_notes_html  
      else
        generate_presentation_html
      end
    end

    private

    def generate_presentation_html
      html_content = build_presentation_html
      
      temp_path = temp_file_path('html')
      File.write(temp_path, html_content)
      
      {
        file_path: temp_path,
        filename: export_filename('html').sub('.html', '_presentation.html'),
        content_type: 'text/html'
      }
    end

    def generate_handout_html
      html_content = build_handout_html
      
      temp_path = temp_file_path('html')
      File.write(temp_path, html_content)
      
      {
        file_path: temp_path,
        filename: export_filename('html').sub('.html', '_handout.html'),
        content_type: 'text/html'
      }
    end

    def generate_speaker_notes_html
      html_content = build_speaker_notes_html
      
      temp_path = temp_file_path('html')
      File.write(temp_path, html_content)
      
      {
        file_path: temp_path,
        filename: export_filename('html').sub('.html', '_speaker_notes.html'),
        content_type: 'text/html'
      }
    end

    def build_presentation_html
      <<~HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>#{seating_event.name} - Seating Presentation</title>
            <style>
                #{presentation_css}
            </style>
        </head>
        <body>
            <div class="presentation">
                #{title_slide}
                #{overview_slide}
                #{optimization_slide if optimization_scores.present?}
                #{seating_chart_slides}
                #{diversity_slide if include_diversity_report?}
                #{explanations_slides if include_explanations?}
                #{conclusion_slide}
            </div>
            
            <script>
                #{presentation_javascript}
            </script>
        </body>
        </html>
      HTML
    end

    def build_handout_html
      <<~HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>#{seating_event.name} - Handout</title>
            <style>
                #{handout_css}
            </style>
        </head>
        <body>
            <div class="handout">
                #{handout_header}
                #{handout_seating_chart}
                #{handout_student_list}
                #{handout_diversity_summary if include_diversity_report?}
            </div>
        </body>
        </html>
      HTML
    end

    def build_speaker_notes_html
      <<~HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>#{seating_event.name} - Speaker Notes</title>
            <style>
                #{speaker_notes_css}
            </style>
        </head>
        <body>
            <div class="speaker-notes">
                #{speaker_notes_content}
            </div>
        </body>
        </html>
      HTML
    end

    def presentation_css
      branding = branding_options
      primary_color = branding[:primary_color] || '#1f2937'
      secondary_color = branding[:secondary_color] || '#3b82f6'
      
      <<~CSS
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Helvetica', 'Arial', sans-serif;
            background: #f8f9fa;
            color: #333;
        }

        .presentation {
            width: 100%;
            max-width: 1024px;
            margin: 0 auto;
        }

        .slide {
            width: 100%;
            height: 100vh;
            padding: 60px;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            background: white;
            border-bottom: 3px solid #{primary_color};
            page-break-after: always;
            position: relative;
        }

        .slide h1 {
            font-size: 3rem;
            color: #{primary_color};
            margin-bottom: 2rem;
            text-align: center;
        }

        .slide h2 {
            font-size: 2.5rem;
            color: #{secondary_color};
            margin-bottom: 1.5rem;
            text-align: center;
        }

        .slide h3 {
            font-size: 2rem;
            color: #{primary_color};
            margin-bottom: 1rem;
        }

        .slide p {
            font-size: 1.2rem;
            line-height: 1.6;
            margin-bottom: 1rem;
            text-align: center;
            max-width: 800px;
        }

        .slide-number {
            position: absolute;
            bottom: 20px;
            right: 30px;
            font-size: 1rem;
            color: #{primary_color};
        }

        .tables-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-top: 2rem;
            width: 100%;
        }

        .table-box {
            border: 2px solid #{secondary_color};
            border-radius: 10px;
            padding: 15px;
            background: #f8f9ff;
        }

        .table-box h4 {
            color: #{secondary_color};
            font-size: 1.5rem;
            margin-bottom: 10px;
            text-align: center;
        }

        .table-box ul {
            list-style: none;
        }

        .table-box li {
            padding: 3px 0;
            font-size: 0.9rem;
            border-bottom: 1px dotted #ddd;
        }

        .stats-grid {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 30px;
            margin-top: 2rem;
            width: 100%;
            max-width: 600px;
        }

        .stat-box {
            text-align: center;
            padding: 20px;
            background: #f0f7ff;
            border-radius: 10px;
            border: 2px solid #{secondary_color};
        }

        .stat-value {
            font-size: 2.5rem;
            font-weight: bold;
            color: #{secondary_color};
        }

        .stat-label {
            font-size: 1rem;
            color: #{primary_color};
            margin-top: 5px;
        }

        .diversity-bars {
            display: flex;
            flex-direction: column;
            gap: 15px;
            margin-top: 2rem;
            width: 100%;
            max-width: 600px;
        }

        .diversity-bar {
            display: flex;
            align-items: center;
            gap: 15px;
        }

        .diversity-label {
            min-width: 150px;
            font-weight: bold;
        }

        .bar-container {
            flex: 1;
            height: 30px;
            background: #e5e7eb;
            border-radius: 15px;
            overflow: hidden;
        }

        .bar-fill {
            height: 100%;
            background: #{secondary_color};
            border-radius: 15px;
            transition: width 0.3s ease;
        }

        .bar-value {
            min-width: 50px;
            text-align: right;
            font-weight: bold;
        }

        @media print {
            .slide {
                page-break-after: always;
            }
        }

        @media (max-width: 768px) {
            .slide {
                padding: 30px 20px;
                height: auto;
                min-height: 100vh;
            }
            
            .slide h1 {
                font-size: 2rem;
            }
            
            .slide h2 {
                font-size: 1.5rem;
            }
            
            .tables-grid {
                grid-template-columns: 1fr;
            }
        }
      CSS
    end

    def handout_css
      branding = branding_options
      primary_color = branding[:primary_color] || '#1f2937'
      
      <<~CSS
        body {
            font-family: 'Helvetica', 'Arial', sans-serif;
            margin: 0;
            padding: 20px;
            background: white;
            color: #333;
            line-height: 1.6;
        }

        .handout {
            max-width: 800px;
            margin: 0 auto;
        }

        .header {
            text-align: center;
            border-bottom: 3px solid #{primary_color};
            padding-bottom: 20px;
            margin-bottom: 30px;
        }

        .header h1 {
            color: #{primary_color};
            margin-bottom: 10px;
        }

        .section {
            margin-bottom: 40px;
        }

        .section h2 {
            color: #{primary_color};
            border-bottom: 2px solid #e5e7eb;
            padding-bottom: 10px;
            margin-bottom: 20px;
        }

        .table-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
        }

        .table-card {
            border: 1px solid #e5e7eb;
            border-radius: 8px;
            padding: 15px;
            background: #f9fafb;
        }

        .table-card h3 {
            color: #{primary_color};
            margin-bottom: 10px;
            text-align: center;
        }

        .student-list {
            font-size: 0.9rem;
        }

        .student-list li {
            margin-bottom: 5px;
            padding-left: 10px;
        }

        @media print {
            body { padding: 10px; }
            .section { page-break-inside: avoid; }
        }
      CSS
    end

    def speaker_notes_css
      <<~CSS
        body {
            font-family: 'Helvetica', 'Arial', sans-serif;
            margin: 0;
            padding: 20px;
            background: white;
            color: #333;
            line-height: 1.8;
        }

        .speaker-notes {
            max-width: 1000px;
            margin: 0 auto;
        }

        .note-section {
            margin-bottom: 40px;
            padding: 20px;
            border-left: 4px solid #3b82f6;
            background: #f8f9ff;
        }

        .note-section h2 {
            color: #1f2937;
            margin-bottom: 15px;
        }

        .talking-points {
            margin-left: 20px;
        }

        .talking-points li {
            margin-bottom: 10px;
        }

        .explanation-box {
            background: #fff;
            padding: 15px;
            border-radius: 8px;
            margin: 15px 0;
            border: 1px solid #e5e7eb;
        }
      CSS
    end

    def title_slide
      branding = branding_options
      
      <<~HTML
        <div class="slide">
            <h1>#{seating_event.name}</h1>
            #{@seating_arrangement.multi_day? ? "<p style='font-size: 1.5rem; color: #666;'>#{@seating_arrangement.day_name}</p>" : ""}
            <p style="font-size: 1.4rem;">Optimized Seating Arrangement</p>
            <p>#{seating_event.event_date.strftime("%B %d, %Y")}</p>
            <p style="margin-top: 2rem; font-size: 1rem;">#{branding[:organization_name] || 'CHDS Seating Charter'}</p>
            <div class="slide-number">1</div>
        </div>
      HTML
    end

    def overview_slide
      <<~HTML
        <div class="slide">
            <h2>Event Overview</h2>
            <div class="stats-grid">
                <div class="stat-box">
                    <div class="stat-value">#{students.count}</div>
                    <div class="stat-label">Students</div>
                </div>
                <div class="stat-box">
                    <div class="stat-value">#{tables_data.count}</div>
                    <div class="stat-label">Tables</div>
                </div>
                <div class="stat-box">
                    <div class="stat-value">#{seating_event.table_size}</div>
                    <div class="stat-label">Per Table</div>
                </div>
                <div class="stat-box">
                    <div class="stat-value">#{seating_event.utilization_percentage}%</div>
                    <div class="stat-label">Utilization</div>
                </div>
            </div>
            <div class="slide-number">2</div>
        </div>
      HTML
    end

    def optimization_slide
      return '' unless optimization_scores.present?
      
      score_color = case @seating_arrangement.overall_score
                   when 0.8..1.0 then '#16a34a'
                   when 0.6..0.8 then '#ea580c'
                   else '#dc2626'
                   end
      
      <<~HTML
        <div class="slide">
            <h2>Optimization Results</h2>
            <div style="font-size: 4rem; font-weight: bold; color: #{score_color}; margin: 2rem 0;">
                #{@seating_arrangement.formatted_score}
            </div>
            <div class="stats-grid">
                <div class="stat-box">
                    <div class="stat-value">#{@seating_arrangement.optimization_strategy}</div>
                    <div class="stat-label">Strategy</div>
                </div>
                <div class="stat-box">
                    <div class="stat-value">#{@seating_arrangement.runtime_seconds.round(1)}s</div>
                    <div class="stat-label">Runtime</div>
                </div>
                <div class="stat-box">
                    <div class="stat-value">#{@seating_arrangement.total_improvements}</div>
                    <div class="stat-label">Improvements</div>
                </div>
                #{@seating_arrangement.overall_confidence > 0 ? "<div class='stat-box'><div class='stat-value'>#{(@seating_arrangement.overall_confidence * 100).round(1)}%</div><div class='stat-label'>Confidence</div></div>" : ""}
            </div>
            <div class="slide-number">3</div>
        </div>
      HTML
    end

    def seating_chart_slides
      slides = []
      slide_num = optimization_scores.present? ? 4 : 3
      
      # Overview slide with all tables
      slides << <<~HTML
        <div class="slide">
            <h2>Seating Chart Overview</h2>
            <div class="tables-grid">
                #{tables_data.map { |table_number, table_info| table_overview_card(table_number, table_info) }.join}
            </div>
            <div class="slide-number">#{slide_num}</div>
        </div>
      HTML
      
      slide_num += 1
      
      # Detailed slides for each table (if requested)
      if @export_options[:detailed_table_slides]
        tables_data.each do |table_number, table_info|
          slides << <<~HTML
            <div class="slide">
                <h2>Table #{table_number} Details</h2>
                <div style="max-width: 600px; margin: 2rem auto;">
                    #{table_detail_content(table_info)}
                </div>
                #{include_explanations? && table_info[:explanation] ? "<div class='explanation-box'><strong>Rationale:</strong> #{table_info[:explanation]}</div>" : ""}
                <div class="slide-number">#{slide_num}</div>
            </div>
          HTML
          slide_num += 1
        end
      end
      
      slides.join
    end

    def diversity_slide
      return '' unless include_diversity_report? && formatted_diversity_data.present?
      
      diversity_data = formatted_diversity_data
      slide_num = optimization_scores.present? ? 4 : 3
      slide_num += 1 # After seating overview
      slide_num += @export_options[:detailed_table_slides] ? tables_data.count : 0
      
      <<~HTML
        <div class="slide">
            <h2>Diversity Analysis</h2>
            <div class="diversity-bars">
                <div class="diversity-bar">
                    <div class="diversity-label">Interaction Diversity</div>
                    <div class="bar-container">
                        <div class="bar-fill" style="width: #{(diversity_data[:interaction_diversity_score] * 100).round(1)}%"></div>
                    </div>
                    <div class="bar-value">#{(diversity_data[:interaction_diversity_score] * 100).round(1)}%</div>
                </div>
                <div class="diversity-bar">
                    <div class="diversity-label">Cross-functional</div>
                    <div class="bar-container">
                        <div class="bar-fill" style="width: #{(diversity_data[:cross_functional_score] * 100).round(1)}%"></div>
                    </div>
                    <div class="bar-value">#{(diversity_data[:cross_functional_score] * 100).round(1)}%</div>
                </div>
                #{diversity_breakdown_bars(diversity_data)}
            </div>
            <div class="slide-number">#{slide_num}</div>
        </div>
      HTML
    end

    def explanations_slides
      return '' unless include_explanations? && @seating_arrangement.has_explanations?
      
      slide_num = optimization_scores.present? ? 4 : 3
      slide_num += 1 # After seating overview  
      slide_num += @export_options[:detailed_table_slides] ? tables_data.count : 0
      slide_num += include_diversity_report? ? 1 : 0
      
      <<~HTML
        <div class="slide">
            <h2>Seating Rationale</h2>
            <div style="text-align: left; max-width: 800px;">
                #{@seating_arrangement.explanation_summary ? "<p style='font-size: 1.1rem; margin-bottom: 2rem;'>#{@seating_arrangement.explanation_summary}</p>" : ""}
                
                #{@seating_arrangement.diversity_explanation ? "<div class='explanation-box'><strong>Diversity Focus:</strong><br>#{@seating_arrangement.diversity_explanation}</div>" : ""}
                
                #{@seating_arrangement.constraint_explanation ? "<div class='explanation-box'><strong>Constraints Applied:</strong><br>#{@seating_arrangement.constraint_explanation}</div>" : ""}
                
                #{@seating_arrangement.optimization_explanation ? "<div class='explanation-box'><strong>Optimization Details:</strong><br>#{@seating_arrangement.optimization_explanation}</div>" : ""}
            </div>
            <div class="slide-number">#{slide_num}</div>
        </div>
      HTML
    end

    def conclusion_slide
      slide_num = optimization_scores.present? ? 4 : 3
      slide_num += 1 # After seating overview
      slide_num += @export_options[:detailed_table_slides] ? tables_data.count : 0
      slide_num += include_diversity_report? ? 1 : 0
      slide_num += include_explanations? ? 1 : 0
      
      <<~HTML
        <div class="slide">
            <h2>Ready for #{seating_event.name}!</h2>
            <p style="font-size: 1.5rem;">Optimized seating arrangement complete</p>
            #{@seating_arrangement.multi_day? ? "<p>#{@seating_arrangement.day_name} - Day #{@seating_arrangement.day_number}</p>" : ""}
            <p style="margin-top: 2rem;">Questions or adjustments?</p>
            <div class="slide-number">#{slide_num}</div>
        </div>
      HTML
    end

    def table_overview_card(table_number, table_info)
      student_names = table_info[:students].map { |s| format_student_name(s) }
      
      <<~HTML
        <div class="table-box">
            <h4>Table #{table_number}</h4>
            <ul>
                #{student_names.map { |name| "<li>#{name}</li>" }.join}
            </ul>
        </div>
      HTML
    end

    def table_detail_content(table_info)
      <<~HTML
        <div style="text-align: left;">
            #{table_info[:students].map.with_index { |student, idx| 
              "<div style='margin-bottom: 15px; padding: 10px; background: #f9fafb; border-radius: 8px;'>
                <strong>#{idx + 1}. #{format_student_name(student)}</strong><br>
                <span style='color: #666;'>#{format_student_title(student)}</span><br>
                <span style='color: #888; font-size: 0.9rem;'>#{format_student_organization(student)}</span>
              </div>"
            }.join}
        </div>
      HTML
    end

    def diversity_breakdown_bars(diversity_data)
      bars = []
      
      if diversity_data[:gender_distribution].present?
        bars << create_diversity_bar("Gender Mix", calculate_diversity_score(diversity_data[:gender_distribution]))
      end
      
      if diversity_data[:agency_level_distribution].present?
        bars << create_diversity_bar("Level Mix", calculate_diversity_score(diversity_data[:agency_level_distribution]))
      end
      
      bars.join
    end

    def create_diversity_bar(label, score)
      <<~HTML
        <div class="diversity-bar">
            <div class="diversity-label">#{label}</div>
            <div class="bar-container">
                <div class="bar-fill" style="width: #{score.round(1)}%"></div>
            </div>
            <div class="bar-value">#{score.round(1)}%</div>
        </div>
      HTML
    end

    def calculate_diversity_score(distribution)
      return 0 if distribution.empty?
      
      # Simple evenness calculation
      values = distribution.values.map { |v| v.is_a?(Hash) ? v['percentage'] : v }
      return 0 if values.empty?
      
      # Calculate how evenly distributed the values are (inverse of coefficient of variation)
      mean = values.sum / values.length.to_f
      return 100 if mean == 0
      
      variance = values.map { |v| (v - mean) ** 2 }.sum / values.length.to_f
      std_dev = Math.sqrt(variance)
      cv = std_dev / mean
      
      # Convert to a 0-100 scale where lower CV = higher score
      [100 - (cv * 50), 0].max
    end

    def handout_header
      <<~HTML
        <div class="header">
            <h1>#{seating_event.name}</h1>
            #{@seating_arrangement.multi_day? ? "<h3>#{@seating_arrangement.day_name}</h3>" : ""}
            <p>#{seating_event.event_date.strftime("%B %d, %Y")}</p>
            <p>#{students.count} students • #{tables_data.count} tables • #{seating_event.table_size} per table</p>
        </div>
      HTML
    end

    def handout_seating_chart
      <<~HTML
        <div class="section">
            <h2>Seating Assignments</h2>
            <div class="table-grid">
                #{tables_data.map { |table_number, table_info| handout_table_card(table_number, table_info) }.join}
            </div>
        </div>
      HTML
    end

    def handout_table_card(table_number, table_info)
      <<~HTML
        <div class="table-card">
            <h3>Table #{table_number}</h3>
            <ul class="student-list">
                #{table_info[:students].map { |student| 
                  "<li>#{format_student_name(student)} - #{format_student_organization(student)}</li>"
                }.join}
            </ul>
        </div>
      HTML
    end

    def handout_student_list
      <<~HTML
        <div class="section">
            <h2>Complete Roster</h2>
            <div style="columns: 2; column-gap: 30px;">
                #{table_assignments.order(:table_number, :seat_position).map { |assignment|
                  student = assignment.student
                  "<p><strong>#{format_student_name(student)}</strong> - Table #{assignment.table_number}<br>
                   <small>#{format_student_title(student)}, #{format_student_organization(student)}</small></p>"
                }.join}
            </div>
        </div>
      HTML
    end

    def handout_diversity_summary
      return '' unless include_diversity_report? && formatted_diversity_data.present?
      
      diversity_data = formatted_diversity_data
      
      <<~HTML
        <div class="section">
            <h2>Diversity Summary</h2>
            <p><strong>Interaction Diversity Score:</strong> #{(diversity_data[:interaction_diversity_score] * 100).round(1)}%</p>
            <p><strong>Cross-functional Score:</strong> #{(diversity_data[:cross_functional_score] * 100).round(1)}%</p>
        </div>
      HTML
    end

    def speaker_notes_content
      notes = []
      
      notes << <<~HTML
        <div class="note-section">
            <h2>Introduction (Slide 1-2)</h2>
            <ul class="talking-points">
                <li>Welcome everyone to #{seating_event.name}</li>
                <li>Today we have #{students.count} participants arranged at #{tables_data.count} tables</li>
                <li>Each table seats #{seating_event.table_size} people for optimal interaction</li>
                #{@seating_arrangement.multi_day? ? "<li>This is #{@seating_arrangement.day_name} of our multi-day series</li>" : ""}
                <li>The seating has been optimized for diversity and engagement</li>
            </ul>
        </div>
      HTML
      
      if optimization_scores.present?
        notes << <<~HTML
          <div class="note-section">
              <h2>Optimization Results (Slide 3)</h2>
              <ul class="talking-points">
                  <li>Our optimization achieved a #{@seating_arrangement.formatted_score} success rate</li>
                  <li>We used the #{@seating_arrangement.optimization_strategy} strategy</li>
                  <li>The algorithm made #{@seating_arrangement.total_improvements} improvements</li>
                  <li>Processing completed in #{@seating_arrangement.runtime_seconds.round(2)} seconds</li>
                  #{@seating_arrangement.overall_confidence > 0 ? "<li>We have #{(@seating_arrangement.overall_confidence * 100).round(1)}% confidence in these placements</li>" : ""}
              </ul>
          </div>
        HTML
      end
      
      notes << <<~HTML
        <div class="note-section">
            <h2>Seating Arrangement Discussion</h2>
            <ul class="talking-points">
                <li>Each table has been carefully balanced for maximum diversity</li>
                <li>We've mixed participants from different organizations and levels</li>
                <li>The arrangement promotes cross-functional collaboration</li>
                <li>If anyone has specific seating needs, please let us know</li>
            </ul>
            #{include_explanations? && @seating_arrangement.explanation_summary ? 
              "<div class='explanation-box'>#{@seating_arrangement.explanation_summary}</div>" : ""}
        </div>
      HTML
      
      if include_diversity_report?
        notes << <<~HTML
          <div class="note-section">
              <h2>Diversity Highlights</h2>
              <ul class="talking-points">
                  <li>Our diversity analysis shows strong cross-functional mixing</li>
                  <li>Each table represents multiple perspectives and experiences</li>
                  <li>This arrangement maximizes learning opportunities</li>
                  <li>Participants will interact with colleagues they might not normally work with</li>
              </ul>
          </div>
        HTML
      end
      
      notes.join
    end

    def presentation_javascript
      <<~JS
        // Simple presentation navigation
        document.addEventListener('keydown', function(e) {
            const slides = document.querySelectorAll('.slide');
            let currentSlide = 0;
            
            // Find current visible slide
            slides.forEach((slide, index) => {
                if (slide.offsetTop <= window.scrollY + 100) {
                    currentSlide = index;
                }
            });
            
            if (e.key === 'ArrowRight' || e.key === ' ') {
                // Next slide
                if (currentSlide < slides.length - 1) {
                    slides[currentSlide + 1].scrollIntoView({ behavior: 'smooth' });
                }
            } else if (e.key === 'ArrowLeft') {
                // Previous slide
                if (currentSlide > 0) {
                    slides[currentSlide - 1].scrollIntoView({ behavior: 'smooth' });
                }
            }
        });

        // Add click navigation
        document.addEventListener('click', function(e) {
            if (e.target.closest('.slide') && !e.target.closest('a')) {
                const slides = document.querySelectorAll('.slide');
                let currentSlide = 0;
                
                slides.forEach((slide, index) => {
                    if (slide.offsetTop <= window.scrollY + 100) {
                        currentSlide = index;
                    }
                });
                
                if (currentSlide < slides.length - 1) {
                    slides[currentSlide + 1].scrollIntoView({ behavior: 'smooth' });
                }
            }
        });
      JS
    end
  end
end