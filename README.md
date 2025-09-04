# CHDS Seating Charter

AI-powered seating chart optimizer for diverse classroom arrangements at the Center for Homeland Defense and Security (CHDS), Naval Postgraduate School.

## 🎯 Purpose

This application helps CHDS instructors create optimally diverse seating arrangements for emergency management professionals, maximizing cross-agency and cross-jurisdictional interaction during 5-day intensive programs.

## ✨ Key Features

- **AI-Powered Roster Import** - Automatically parse PDFs and infer student attributes using configurable OpenAI models
- **Diversity Optimization** - Generate seating that maximizes diversity across agency levels, departments, and geography
- **Natural Language Instructions** - Tell the system your requirements in plain English
- **Multi-Day Workshops** - Minimize repeated pairings across 5-day programs
- **Explainable Decisions** - Understand why each seating decision was made
- **Interactive Editor** - Drag-and-drop interface with real-time diversity scoring
- **Professional Exports** - Generate PDFs, Excel files, and name tags

## 🚀 Quick Start

### Prerequisites

- Ruby 3.3.0
- Rails 8.0+
- PostgreSQL 14+
- Node.js 18+
- Redis (for background jobs)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/jeremedia/seating-charter.git
cd seating-charter
```

2. Install dependencies:
```bash
bundle install
yarn install
```

3. Set up the database:
```bash
rails db:create
rails db:migrate
rails db:seed
```

4. Configure environment variables:
```bash
cp .env.example .env
# Add your OpenAI API key to .env
```

5. Start the application:
```bash
bin/dev
```

6. Visit http://localhost:3000

Default credentials:
- Email: admin@chds.nps.edu
- Password: password123

## 📋 Project Status

### Current Phase: Planning Complete ✅

All 8 development phases have been planned and documented:

| Phase | Week | Status | Description |
|-------|------|--------|-------------|
| 1 | Week 1 | 🔜 Ready | Foundation & Setup |
| 2 | Week 2 | 📋 Planned | AI Integration & Configuration |
| 3 | Week 3 | 📋 Planned | Review Interface |
| 4 | Week 4 | 📋 Planned | Optimization Engine |
| 5 | Week 5 | 📋 Planned | Multi-Day Support |
| 6 | Week 6 | 📋 Planned | Interactive Editor |
| 7 | Week 7 | 📋 Planned | Export System |
| 8 | Week 8 | 📋 Planned | Testing & Deployment |

View all [GitHub Issues](https://github.com/jeremedia/seating-charter/issues) for detailed tasks.

## 🏗️ Architecture

### Tech Stack
- **Backend**: Rails 8.0, PostgreSQL, Redis
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS
- **AI**: OpenAI API (configurable models)
- **Jobs**: Sidekiq
- **Exports**: Prawn (PDF), Caxlsx (Excel)

### Key Services
- `AiRosterParser` - Extracts student data from documents
- `SeatingOptimizer` - Generates diverse arrangements
- `MultiDayOptimizer` - Minimizes repeated pairings
- `CostTracker` - Monitors OpenAI API usage

## 📖 Documentation

- [Full Specification](SPECIFICATION.md) - Detailed requirements and design
- [Rails Prompt](../rails-seating-chart-prompt.md) - Original implementation prompt
- [GitHub Issues](https://github.com/jeremedia/seating-charter/issues) - Development tasks

## 🤝 Development Workflow

1. Pick an issue from the [project board](https://github.com/jeremedia/seating-charter/issues)
2. Create a feature branch: `git checkout -b feature/issue-number-description`
3. Make your changes
4. Write tests (RSpec)
5. Ensure all tests pass: `rspec`
6. Submit a pull request

### Running Tests

```bash
# Run all tests
rspec

# Run specific test file
rspec spec/services/seating_optimizer_spec.rb

# Run with coverage
COVERAGE=true rspec
```

### Code Style

```bash
# Ruby linting
rubocop

# JavaScript linting
yarn lint

# Fix auto-fixable issues
rubocop -A
```

## 🔐 Security & Privacy

- All student PII is encrypted at rest
- API keys stored securely with Rails credentials
- Audit trail for all data modifications
- FERPA compliant data handling
- No student data leaves NPS infrastructure

## 📊 AI Configuration

The system supports multiple OpenAI models configurable through the admin interface:

- GPT-4o (recommended)
- GPT-4 Turbo
- GPT-3.5 Turbo
- Azure OpenAI (future)

Admins can adjust:
- Model selection
- Temperature (0.0-1.0)
- Max tokens (1000-4000)
- Batch size (5-10 students)
- Custom prompts

## 🎯 Success Metrics

- Parse Emergence cohort rosters with >95% accuracy
- Generate arrangements in <2 seconds for 40 students
- Achieve 80%+ unique pairings over 5 days
- Process rosters for <$0.10 in API costs
- Support all 5 CHDS instructors concurrently

## 📝 License

This project is proprietary software for the Center for Homeland Defense and Security.

## 👥 Team

- **Product Owner**: CHDS Program Office
- **Development**: TBD
- **Stakeholders**: CHDS Instructors

## 📧 Contact

For questions about this project, contact the CHDS Program Office.

---

*Built specifically for CHDS at the Naval Postgraduate School to enhance emergency management education through optimized peer interaction.*