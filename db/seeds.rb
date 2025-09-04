# CHDS Seating Charter - Seed Data
# This file creates initial data for development and testing

puts "Creating CHDS Seating Charter seed data..."

# Create admin user
admin = User.find_or_create_by!(email: "admin@chds.edu") do |user|
  user.password = "password"
  user.password_confirmation = "password"
  user.role = "admin"
  user.first_name = "System"
  user.last_name = "Administrator"
end
puts "✓ Created admin user: #{admin.email}"

# Create instructor user
instructor = User.find_or_create_by!(email: "instructor@chds.edu") do |user|
  user.password = "password"  
  user.password_confirmation = "password"
  user.role = "instructor"
  user.first_name = "Dr. Jane"
  user.last_name = "Smith"
end
puts "✓ Created instructor user: #{instructor.email}"

# Create AI Configuration
ai_config = AiConfiguration.find_or_create_by!(ai_model_name: "gpt-4o") do |config|
  config.api_endpoint = "https://api.openai.com/v1/chat/completions"
  config.temperature = 0.1
  config.max_tokens = 4000
  config.batch_size = 8
  config.retry_attempts = 3
  config.cost_per_token = 0.00001
  config.active = true
end
puts "✓ Created AI configuration"

# Create Custom Attributes for CHDS
custom_attributes = [
  {
    name: "Security_Clearance",
    description: "Security clearance level (None, Secret, Top Secret)",
    inference_enabled: true,
    inference_prompt: "Infer security clearance level based on organization and title",
    weight_in_optimization: 0.3,
    display_color: "#1f2937",
    active: true
  },
  {
    name: "Years_Experience",
    description: "Years of experience in emergency management",
    inference_enabled: true,
    inference_prompt: "Infer years of experience based on title and seniority",
    weight_in_optimization: 0.2,
    display_color: "#059669",
    active: true
  },
  {
    name: "Geographic_Region",
    description: "Geographic region (West, Central, East, International)",
    inference_enabled: true,
    inference_prompt: "Determine geographic region based on location",
    weight_in_optimization: 0.4,
    display_color: "#dc2626",
    active: true
  }
]

custom_attributes.each do |attr|
  CustomAttribute.find_or_create_by!(name: attr[:name]) do |ca|
    ca.assign_attributes(attr)
  end
end
puts "✓ Created #{custom_attributes.length} custom attributes"

# Create Emergence Cohort
emergence_cohort = Cohort.find_or_create_by!(name: "Emergence 2501") do |cohort|
  cohort.description = "CHDS Emergence Program - January 2025 Cohort focusing on emerging threats and innovative emergency management strategies"
  cohort.start_date = Date.parse("2025-01-13")
  cohort.end_date = Date.parse("2025-01-17")
  cohort.user = instructor
  cohort.max_students = 40
end
puts "✓ Created Emergence 2501 cohort"

# Emergence 2501 Student Data (based on specification sample)
emergence_students = [
  {
    name: "Paul Adcox",
    title: "Mobilization Officer", 
    organization: "Nevada Army National Guard",
    location: "Reno, NV",
    inferences: {
      gender: { value: "male", confidence: 0.92 },
      agency_level: { value: "state", confidence: 0.95 },
      department_type: { value: "military", confidence: 0.98 },
      seniority_level: { value: "mid", confidence: 0.75 }
    }
  },
  {
    name: "David Baker",
    title: "Deportation Officer",
    organization: "DHS – Immigration and Customs Enforcement",
    location: "Nashville, TN",
    inferences: {
      gender: { value: "male", confidence: 0.94 },
      agency_level: { value: "federal", confidence: 0.98 },
      department_type: { value: "law_enforcement", confidence: 0.95 },
      seniority_level: { value: "mid", confidence: 0.80 }
    }
  },
  {
    name: "Evan Bart",
    title: "Security Manager",
    organization: "The Walt Disney Company",
    location: "Clermont, FL",
    inferences: {
      gender: { value: "male", confidence: 0.88 },
      agency_level: { value: "private", confidence: 0.99 },
      department_type: { value: "security", confidence: 0.92 },
      seniority_level: { value: "senior", confidence: 0.85 }
    }
  },
  {
    name: "Sarah Chen",
    title: "Emergency Management Director",
    organization: "Santa Clara County",
    location: "San Jose, CA",
    inferences: {
      gender: { value: "female", confidence: 0.96 },
      agency_level: { value: "local", confidence: 0.95 },
      department_type: { value: "emergency_management", confidence: 0.98 },
      seniority_level: { value: "executive", confidence: 0.90 }
    }
  },
  {
    name: "Michael Rodriguez",
    title: "Fire Chief",
    organization: "Austin Fire Department",
    location: "Austin, TX",
    inferences: {
      gender: { value: "male", confidence: 0.93 },
      agency_level: { value: "local", confidence: 0.97 },
      department_type: { value: "fire", confidence: 0.99 },
      seniority_level: { value: "executive", confidence: 0.95 }
    }
  },
  {
    name: "Jennifer Williams",
    title: "Intelligence Analyst",
    organization: "FBI",
    location: "Washington, DC",
    inferences: {
      gender: { value: "female", confidence: 0.95 },
      agency_level: { value: "federal", confidence: 0.99 },
      department_type: { value: "law_enforcement", confidence: 0.96 },
      seniority_level: { value: "mid", confidence: 0.78 }
    }
  },
  {
    name: "Robert Johnson",
    title: "Coast Guard Commander",
    organization: "US Coast Guard",
    location: "Miami, FL",
    inferences: {
      gender: { value: "male", confidence: 0.91 },
      agency_level: { value: "federal", confidence: 0.98 },
      department_type: { value: "military", confidence: 0.97 },
      seniority_level: { value: "senior", confidence: 0.88 }
    }
  },
  {
    name: "Lisa Thompson",
    title: "Public Health Emergency Coordinator",
    organization: "CDC",
    location: "Atlanta, GA",
    inferences: {
      gender: { value: "female", confidence: 0.94 },
      agency_level: { value: "federal", confidence: 0.99 },
      department_type: { value: "public_health", confidence: 0.95 },
      seniority_level: { value: "senior", confidence: 0.82 }
    }
  },
  {
    name: "James Davis",
    title: "Police Captain",
    organization: "LAPD",
    location: "Los Angeles, CA",
    inferences: {
      gender: { value: "male", confidence: 0.92 },
      agency_level: { value: "local", confidence: 0.96 },
      department_type: { value: "law_enforcement", confidence: 0.98 },
      seniority_level: { value: "senior", confidence: 0.89 }
    }
  },
  {
    name: "Maria Garcia",
    title: "Emergency Management Specialist",
    organization: "FEMA Region IX",
    location: "Oakland, CA",
    inferences: {
      gender: { value: "female", confidence: 0.97 },
      agency_level: { value: "federal", confidence: 0.98 },
      department_type: { value: "emergency_management", confidence: 0.96 },
      seniority_level: { value: "mid", confidence: 0.75 }
    }
  },
  {
    name: "Kevin Lee",
    title: "Cybersecurity Director",
    organization: "State of Oregon",
    location: "Salem, OR",
    inferences: {
      gender: { value: "male", confidence: 0.89 },
      agency_level: { value: "state", confidence: 0.95 },
      department_type: { value: "cybersecurity", confidence: 0.97 },
      seniority_level: { value: "executive", confidence: 0.91 }
    }
  },
  {
    name: "Amanda Wilson",
    title: "Disaster Recovery Manager",
    organization: "American Red Cross",
    location: "Phoenix, AZ",
    inferences: {
      gender: { value: "female", confidence: 0.96 },
      agency_level: { value: "nonprofit", confidence: 0.94 },
      department_type: { value: "emergency_management", confidence: 0.93 },
      seniority_level: { value: "senior", confidence: 0.86 }
    }
  },
  {
    name: "Daniel Brown",
    title: "Homeland Security Advisor",
    organization: "State of Florida",
    location: "Tallahassee, FL",
    inferences: {
      gender: { value: "male", confidence: 0.93 },
      agency_level: { value: "state", confidence: 0.97 },
      department_type: { value: "homeland_security", confidence: 0.95 },
      seniority_level: { value: "executive", confidence: 0.88 }
    }
  },
  {
    name: "Rachel Martinez",
    title: "Emergency Communications Manager",
    organization: "King County",
    location: "Seattle, WA",
    inferences: {
      gender: { value: "female", confidence: 0.95 },
      agency_level: { value: "local", confidence: 0.96 },
      department_type: { value: "emergency_management", confidence: 0.89 },
      seniority_level: { value: "senior", confidence: 0.83 }
    }
  },
  {
    name: "Christopher Taylor",
    title: "Special Agent",
    organization: "ATF",
    location: "Denver, CO",
    inferences: {
      gender: { value: "male", confidence: 0.91 },
      agency_level: { value: "federal", confidence: 0.98 },
      department_type: { value: "law_enforcement", confidence: 0.96 },
      seniority_level: { value: "mid", confidence: 0.79 }
    }
  },
  {
    name: "Nicole Anderson",
    title: "Public Safety Director",
    organization: "City of Portland",
    location: "Portland, OR", 
    inferences: {
      gender: { value: "female", confidence: 0.94 },
      agency_level: { value: "local", confidence: 0.95 },
      department_type: { value: "public_safety", confidence: 0.92 },
      seniority_level: { value: "executive", confidence: 0.90 }
    }
  },
  {
    name: "Matthew Clark",
    title: "Border Patrol Agent",
    organization: "US Customs and Border Protection",
    location: "El Paso, TX",
    inferences: {
      gender: { value: "male", confidence: 0.92 },
      agency_level: { value: "federal", confidence: 0.98 },
      department_type: { value: "law_enforcement", confidence: 0.96 },
      seniority_level: { value: "entry", confidence: 0.72 }
    }
  },
  {
    name: "Jessica White",
    title: "Emergency Preparedness Coordinator",
    organization: "University of California System",
    location: "Oakland, CA",
    inferences: {
      gender: { value: "female", confidence: 0.96 },
      agency_level: { value: "state", confidence: 0.87 },
      department_type: { value: "emergency_management", confidence: 0.94 },
      seniority_level: { value: "mid", confidence: 0.76 }
    }
  },
  {
    name: "Andrew Young",
    title: "Deputy Sheriff",
    organization: "Maricopa County Sheriff's Office",
    location: "Phoenix, AZ",
    inferences: {
      gender: { value: "male", confidence: 0.90 },
      agency_level: { value: "local", confidence: 0.95 },
      department_type: { value: "law_enforcement", confidence: 0.97 },
      seniority_level: { value: "mid", confidence: 0.81 }
    }
  },
  {
    name: "Stephanie King",
    title: "Risk Management Director",
    organization: "Boeing Company",
    location: "Seattle, WA",
    inferences: {
      gender: { value: "female", confidence: 0.95 },
      agency_level: { value: "private", confidence: 0.98 },
      department_type: { value: "risk_management", confidence: 0.91 },
      seniority_level: { value: "executive", confidence: 0.89 }
    }
  },
  {
    name: "Thomas Scott",
    title: "Fire Marshal",
    organization: "State Fire Marshal's Office",
    location: "Sacramento, CA",
    inferences: {
      gender: { value: "male", confidence: 0.93 },
      agency_level: { value: "state", confidence: 0.96 },
      department_type: { value: "fire", confidence: 0.98 },
      seniority_level: { value: "executive", confidence: 0.87 }
    }
  },
  {
    name: "Linda Green",
    title: "Disaster Services Director",
    organization: "Salvation Army",
    location: "Dallas, TX",
    inferences: {
      gender: { value: "female", confidence: 0.97 },
      agency_level: { value: "nonprofit", confidence: 0.95 },
      department_type: { value: "emergency_management", confidence: 0.93 },
      seniority_level: { value: "executive", confidence: 0.86 }
    }
  },
  {
    name: "Ryan Adams",
    title: "Counterterrorism Analyst",
    organization: "Joint Terrorism Task Force",
    location: "New York, NY",
    inferences: {
      gender: { value: "male", confidence: 0.88 },
      agency_level: { value: "federal", confidence: 0.97 },
      department_type: { value: "intelligence", confidence: 0.94 },
      seniority_level: { value: "mid", confidence: 0.77 }
    }
  },
  {
    name: "Karen Nelson",
    title: "Public Health Director",
    organization: "Multnomah County Health Department", 
    location: "Portland, OR",
    inferences: {
      gender: { value: "female", confidence: 0.96 },
      agency_level: { value: "local", confidence: 0.94 },
      department_type: { value: "public_health", confidence: 0.97 },
      seniority_level: { value: "executive", confidence: 0.91 }
    }
  },
  {
    name: "Brian Carter",
    title: "Emergency Management Officer",
    organization: "US Air Force",
    location: "Colorado Springs, CO",
    inferences: {
      gender: { value: "male", confidence: 0.91 },
      agency_level: { value: "federal", confidence: 0.98 },
      department_type: { value: "military", confidence: 0.97 },
      seniority_level: { value: "senior", confidence: 0.84 }
    }
  },
  {
    name: "Heather Mitchell",
    title: "Security Specialist",
    organization: "Port of Los Angeles",
    location: "Los Angeles, CA",
    inferences: {
      gender: { value: "female", confidence: 0.94 },
      agency_level: { value: "local", confidence: 0.92 },
      department_type: { value: "security", confidence: 0.95 },
      seniority_level: { value: "mid", confidence: 0.78 }
    }
  },
  {
    name: "Mark Roberts",
    title: "Critical Infrastructure Protection Manager",
    organization: "Pacific Gas & Electric",
    location: "San Francisco, CA",
    inferences: {
      gender: { value: "male", confidence: 0.92 },
      agency_level: { value: "private", confidence: 0.98 },
      department_type: { value: "infrastructure", confidence: 0.94 },
      seniority_level: { value: "senior", confidence: 0.85 }
    }
  }
]

emergence_students.each do |student_data|
  student = Student.find_or_create_by!(
    name: student_data[:name], 
    cohort: emergence_cohort
  ) do |s|
    s.title = student_data[:title]
    s.organization = student_data[:organization]
    s.location = student_data[:location]
    s.inferences = student_data[:inferences]
    s.confidence_scores = student_data[:inferences].transform_values { |v| v[:confidence] }
  end
end
puts "✓ Created #{emergence_students.length} students for Emergence 2501"

# Create a seating event for the cohort
seating_event = SeatingEvent.find_or_create_by!(name: "Day 1 - Opening Session") do |event|
  event.cohort = emergence_cohort
  event.event_type = "single_day"
  event.event_date = emergence_cohort.start_date
  event.table_size = 4
  event.total_tables = 7 # 27 students / 4 per table ≈ 7 tables
end
puts "✓ Created seating event for Day 1"

puts "\n🎉 CHDS Seating Charter seed data created successfully!"
puts "👤 Admin login: admin@chds.edu / password"
puts "👨‍🏫 Instructor login: instructor@chds.edu / password"
puts "📚 Emergence 2501 cohort created with #{emergence_students.length} students"
puts "🪑 Ready for seating optimization!"
