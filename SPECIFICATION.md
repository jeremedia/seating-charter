# CHDS Seating Charter Application Specification

## Executive Summary

Seating Charter is a specialized web application for the Center for Homeland Defense and Security (CHDS) at the Naval Postgraduate School. It uses AI to parse class rosters and generate optimally diverse seating arrangements for emergency management professionals, maximizing cross-agency and cross-jurisdictional interaction.

## Context & Constraints

- **Organization**: CHDS at Naval Postgraduate School
- **Users**: Maximum 5 instructors
- **Cohort Size**: Maximum 40 students per cohort
- **API Billing**: Single CHDS OpenAI project key
- **Deployment**: Internal NPS infrastructure

## Core Features

### 1. AI-Powered Roster Import

#### Document Parsing
- Support PDF, Excel, and CSV roster formats
- Extract: Name, Title, Organization, Location
- Handle various formatting styles common in government documents
- Batch processing (5-10 students per API call for efficiency)

#### Intelligent Inference Engine
- **Core Attributes** (AI-inferred with confidence scores):
  - Gender (based on first name)
  - Agency Level (federal/state/local/military/private)
  - Department Type (law enforcement/emergency management/fire/etc.)
  - Seniority Level (executive/senior/mid/entry)
  
- **Custom Attributes** (admin-defined):
  - Additional fields specific to CHDS needs
  - Configurable inference rules
  - Optional manual entry

#### Natural Language Seating Instructions
- Instructors can provide plain English requirements:
  - "Keep the FBI agents distributed across tables"
  - "Ensure each table has someone from emergency management"
  - "Place new students with experienced professionals"
- AI interprets and incorporates into optimization

### 2. Review & Correction Interface

- Side-by-side view of AI inferences with confidence indicators
- Color coding: Green (>90% confidence), Yellow (70-90%), Red (<70%)
- Bulk editing capabilities
- Track corrections for cost and accuracy analysis
- One-click acceptance of high-confidence inferences

### 3. Diversity Optimization Engine

#### Optimization Dimensions
- **Standard**: Gender, Agency Level, Department Type, Location
- **Custom**: Admin-defined attributes
- **Instructor Preferences**: Natural language constraints

#### Explainable Decisions
- Show why each seating decision was made
- Diversity score breakdown by attribute
- Highlight constraint satisfaction
- Alternative arrangement suggestions

#### Performance Targets
- Generate optimal arrangement in <2 seconds for 40 students
- Support tables of 3-8 students (default: 4)
- Real-time re-optimization during manual adjustments

### 4. Multi-Day Workshop Support

- Track interactions across 5-day programs
- Minimize repeated pairings
- Ensure maximum networking opportunities
- Daily arrangement variations
- Interaction coverage analytics (% of possible pairings achieved)

### 5. Interactive Seating Editor

- Drag-and-drop interface
- Real-time diversity score updates
- Visual attribute badges
- Constraint violation warnings
- Undo/redo support
- Lock specific seats

### 6. Export Capabilities

- **PDF**: Professional seating charts for printing
- **Excel**: Data export with diversity metrics
- **Name Tags**: Formatted for standard badge printers
- **Text Summary**: Plain text for email distribution

## Technical Architecture

### AI Configuration System

```yaml
Admin UI Settings:
  - Model Selection (dropdown: gpt-4o, gpt-4-turbo, etc.)
  - API Endpoint (for future Azure OpenAI migration)
  - Temperature (0.0-1.0 slider)
  - Max Tokens (1000-4000)
  - Batch Size (5-10 students)
  - Retry Logic (attempts, delays)
  - Cost Tracking (per request, daily, monthly)
  - Custom Prompts (editable templates)
  - Natural Language Instruction Parser
```

### Cost Management

```ruby
CostTracking:
  - request_id
  - instructor_id
  - model_used
  - input_tokens
  - output_tokens
  - cost_estimate
  - purpose (import/inference/instruction_parsing)
  - timestamp
  
Monthly Reports:
  - Total cost by instructor
  - Cost by operation type
  - Token usage trends
  - Model efficiency comparison
```

### Database Schema Highlights

```ruby
# Custom attributes defined by admin
CustomAttribute:
  - name
  - description
  - inference_enabled (boolean)
  - inference_prompt (text)
  - weight_in_optimization (float)
  - display_color
  - active

# Natural language instructions
SeatingInstruction:
  - seating_event_id
  - instruction_text
  - parsed_constraints (JSONB)
  - ai_interpretation (JSONB)
  - applied (boolean)
```

## User Workflows

### Typical Instructor Flow
1. Upload roster PDF (Emergence 2501 format)
2. Review AI extractions and inferences (<2 min)
3. Add natural language instructions (optional)
4. Generate seating arrangement (<5 sec)
5. Make manual adjustments if needed
6. Export PDF for classroom use

### Admin Configuration Flow
1. Set up OpenAI API key (one-time)
2. Configure AI model preferences
3. Define custom attributes for CHDS needs
4. Set optimization weights
5. Monitor usage and costs

## Implementation Phases (8 Weeks Total)

### Phase 1: Foundation (Week 1)
- Rails 8 setup with PostgreSQL
- Devise authentication for 5 instructors
- Basic cohort and student models
- Admin interface scaffold
- CHDS branding

### Phase 2: AI Integration & Configuration (Week 2)
- OpenAI integration with configurable models
- Admin UI for AI settings
- Cost tracking system
- Roster parsing for standard formats
- Inference engine with confidence scoring

### Phase 3: Review Interface (Week 3)
- Import review UI
- Confidence visualization
- Correction workflow
- Feedback tracking
- Bulk operations

### Phase 4: Optimization Engine (Week 4)
- Core diversity algorithm
- Natural language instruction parser
- Constraint system
- Explainability features
- Performance optimization for 40 students

### Phase 5: Multi-Day Support (Week 5)
- Interaction tracking
- Pairing minimization algorithm
- Coverage analytics
- Daily variations

### Phase 6: Interactive Editor (Week 6)
- Drag-and-drop interface
- Real-time scoring
- Visual feedback
- Manual overrides
- Attribute badges

### Phase 7: Export System & Polish (Week 7)
- PDF generation
- Excel export
- Name tags
- Final UI polish
- Instructor documentation

### Phase 8: Testing & Deployment (Week 8)
- CHDS instructor testing
- Bug fixes
- Performance tuning
- Deployment to NPS infrastructure
- Training session

## Success Metrics

### Must Have (Launch Requirements)
- ✅ Parse Emergence cohort rosters with >95% accuracy
- ✅ Generate diverse arrangements in <5 seconds
- ✅ Support 5-day workshop formats
- ✅ Export professional PDFs
- ✅ Track API costs per operation
- ✅ Allow model switching without code changes

### Nice to Have (Post-Launch)
- Historical arrangement analysis
- Student preference incorporation
- Mobile-responsive design
- Batch cohort operations

## Risk Mitigation

### Technical Risks
- **OpenAI API Changes**: Abstraction layer for easy model switching
- **Cost Overruns**: Real-time monitoring and alerts
- **Parsing Failures**: Manual entry fallback

### Operational Risks
- **Low Adoption**: Focus on time savings and ease of use
- **Accuracy Concerns**: Human review step and explainability

## Sample Natural Language Instructions

Examples of instructor inputs the system should understand:
- "Distribute federal agencies evenly across all tables"
- "Ensure each table has at least one senior executive"
- "Keep the two FBI agents at separate tables"
- "Mix East Coast and West Coast participants"
- "Place first-time attendees with CHDS alumni"

## Data Samples

### Expected Input (PDF Roster)
```
Paul Adcox, Mobilization Officer
Nevada Army National Guard, Reno, NV

David Baker, Deportation Officer  
DHS – Immigration and Customs Enforcement, Nashville, TN

Evan Bart, Security Manager
The Walt Disney Company, Clermont, FL
```

### AI Output
```json
{
  "students": [{
    "name": "Paul Adcox",
    "title": "Mobilization Officer",
    "organization": "Nevada Army National Guard",
    "inferences": {
      "gender": {"value": "male", "confidence": 0.92},
      "agency_level": {"value": "state", "confidence": 0.95},
      "department_type": {"value": "military", "confidence": 0.98},
      "seniority": {"value": "mid", "confidence": 0.75}
    }
  }]
}
```

## Deliverables

1. **Web Application**: Fully functional Rails 8 application
2. **Admin Interface**: AI configuration and cost tracking
3. **Documentation**: User guide and admin manual
4. **Training**: 2-hour session for CHDS instructors
5. **Support**: 30-day post-launch support period

## Acceptance Criteria

The system is complete when:
1. Successfully processes actual Emergence cohort roster
2. Generates arrangements meeting CHDS diversity goals
3. All 5 instructors can create arrangements independently
4. API costs are tracked and reported monthly
5. Natural language instructions work for common scenarios
6. System explains its seating decisions clearly