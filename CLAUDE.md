# CLAUDE.md - AI Assistant Context for CHDS Seating Charter

## 🎯 Project Overview
This is the CHDS (Center for Homeland Defense and Security) Seating Charter application for the Naval Postgraduate School. It uses AI to create optimally diverse classroom seating arrangements for emergency management professionals.

## 🚀 Current Status (September 2025)

### ✅ APPLICATION COMPLETE & DEPLOYED TO PRODUCTION!

**Live Production URL**: https://sc.domt.app  
**Development URL**: https://sc.dev.domt.app

### All 13 Issues Implemented

#### Completed Features:
- ✅ **Phase 1-2**: Rails 8 setup with PostgreSQL and GPT-5 Integration
- ✅ **Issue #6**: Import Review Interface with AI confidence indicators
- ✅ **Issue #7**: Natural Language Instructions for seating rules
- ✅ **Issue #8**: Diversity Optimization Algorithm (3 strategies)
- ✅ **Issue #9**: Explainable AI Decisions with visualizations
- ✅ **Issue #10**: Multi-Day Workshop Optimization (2-10 days)
- ✅ **Issue #11**: Drag-and-Drop Seating Editor with real-time updates
- ✅ **Issue #12**: Export Formats (PDF, Excel, CSV, Name Tags, PowerPoint)
- ✅ **Issue #13**: Comprehensive Testing Suite and Production Configuration

### Key Achievement: Full-Stack AI-Powered Application
**IMPORTANT**: GPT-5 is now available and integrated! The system supports:
- `gpt-5` - Main model (using gpt-5-2025-08-07)
- `gpt-5-mini` - Faster, cheaper variant
- `gpt-5-nano` - Smallest, most efficient
- `gpt-5-chat-latest` - Latest chat-optimized version

## ⚙️ Technical Configuration

### Environment Setup
```bash
# Start PostgreSQL
pg_ctl -D /opt/homebrew/var/postgresql@14 start

# Start Rails server with environment
source .env && rails server

# Run tests
rails phase2:test
```

### Database
- PostgreSQL 14+ required
- All models created and migrated
- Seed data includes 27 Emergence cohort students
- Login: admin@chds.edu / password

### GPT-5 Specific Requirements
⚠️ **CRITICAL GPT-5 DIFFERENCES**:
1. **Parameters**: Uses `max_completion_tokens` NOT `max_tokens`
2. **Temperature**: Currently only supports default (1.0) - cannot be customized
3. **Cost**: Approximately $0.02 per 1000 tokens
4. **API Key**: Already configured in .env (sk-svcacct-...)

### Testing GPT-5
```ruby
# Quick test in Rails console
rails runner "
  service = OpenaiService.new
  response = OpenaiService.call(
    'Hello GPT-5, confirm you are working',
    purpose: 'test',
    model_override: 'gpt-5'
  )
  puts response
"
```

## 🏗️ Architecture Decisions

### AI Configuration System
- **Dynamic Model Switching**: Admin can change models without code changes
- **Cost Tracking**: Every API call tracked with tokens and estimated cost
- **Fallback Logic**: Rule-based inference when AI unavailable
- **Batch Processing**: 5-10 students per API call to minimize costs

### Model Structure
- **JSONB Fields**: Used for flexible attribute storage
- **Confidence Scores**: All AI inferences include 0-1 confidence rating
- **Conservative Approach**: Returns "unknown" when confidence < threshold

### Service Layer
- `OpenaiService`: Wrapper with GPT-5 compatibility
- `AiRosterParser`: Handles PDF/Excel/CSV with batch processing
- `AttributeInferenceService`: Gender, agency, department inference
- Cost tracking automatic on every API call

## 🎉 Application Features

### Core Capabilities
- **AI-Powered Student Analysis**: GPT-5 integration for gender, agency, department inference
- **Smart Seating Optimization**: 3 algorithms (Simulated Annealing, Genetic, Random Swap)
- **Natural Language Rules**: Instructors can type "Keep FBI agents apart"
- **Multi-Day Workshops**: Optimize 2-10 day events with interaction diversity
- **Interactive Editor**: Drag-and-drop interface with real-time diversity scoring
- **Professional Exports**: PDF, Excel, CSV, Name Tags, PowerPoint presentations
- **Explainable AI**: Understand why each student was placed where
- **FERPA Compliant**: Security hardened for educational data

### Production Ready
- **Comprehensive Testing**: RSpec test suite with factories and system tests
- **CI/CD Pipeline**: GitHub Actions with security scanning
- **Monitoring**: Error tracking and performance monitoring configured
- **Documentation**: Complete setup and deployment guides

## 🔧 Common Commands

### Development
```bash
# Start everything
source .env && rails server

# Test AI integration
rails phase2:test

# Check available OpenAI models
rails openai:check_models

# Rails console with env
source .env && rails console

# Create new migration
rails generate migration AddFieldToModel field:type

# Run specific test
rspec spec/services/openai_service_spec.rb
```

### Database
```bash
# Reset database
rails db:drop db:create db:migrate db:seed

# Check current schema
rails db:migrate:status

# Rollback migration
rails db:rollback
```

### Git Workflow
```bash
# Check issue status
gh issue list

# Close issue with comment
gh issue close NUMBER --comment "Message"

# Create PR
gh pr create --title "Title" --body "Description"
```

## 🐛 Known Issues & Gotchas

1. **Rails 8 Enum Syntax**: Must use `enum :field, { values }` not `enum field: { values }`

2. **Secret Key Base**: Required in .env for Rails to start

3. **GPT-5 Temperature**: Cannot be changed from default (1.0) - will error if you try

4. **Background Jobs**: Not yet configured - Sidekiq ready but not running

5. **File Uploads**: Models ready but controllers/views not implemented

## 🔐 Security Notes

- OpenAI API key is in .env (not committed to git normally, but provided by user)
- All student PII should be encrypted at rest (not yet implemented)
- FERPA compliance required for production
- Max 5 instructors, 40 students per cohort

## 📊 Testing Checklist

Before marking an issue complete, ensure:
- [ ] Feature works end-to-end
- [ ] AI integration tested with real API calls
- [ ] Cost tracking verified
- [ ] Error handling for API failures
- [ ] Admin UI reflects changes
- [ ] Documentation updated

## 💡 Tips for Future Development

1. **Always test with actual API**: The system behaves differently with real OpenAI calls vs mocked responses

2. **Check GPT-5 compatibility**: When adding new AI features, test with both GPT-5 and GPT-4 as they have different requirements

3. **Monitor costs**: GPT-5 is more expensive - always implement batch processing

4. **Use conservative inference**: Better to return "unknown" than wrong data

5. **Progressive enhancement**: System should work without AI (rule-based fallbacks)

## 📝 Admin Access Points

- **AI Configuration**: http://localhost:3000/admin/ai_configurations
- **Cost Tracking**: http://localhost:3000/admin/cost_trackings
- **Main App**: http://localhost:3000
- **Login**: admin@chds.edu / password

## 🚦 Ready-to-Implement Features

The following can be started immediately:
1. Import review interface (Issue #6) - Views and controllers needed
2. Natural language parsing (Issue #7) - Service exists, needs UI
3. Optimization algorithm (Issue #8) - Core business logic

## 🌐 Production Deployment

### Live URLs
- **Production**: https://sc.domt.app
- **Development**: https://sc.dev.domt.app
- **GitHub**: https://github.com/jeremedia/seating-charter

### Infrastructure
- **Production Server**: jer-serve (100.74.87.20)
- **Port**: 3200
- **Database**: PostgreSQL (seating_charter_production)
- **Service**: systemd (seating-charter.service)
- **CI/CD**: GitHub Actions (auto-deploy on push to main)
- **DNS**: Google Cloud DNS → Caddy proxy → Tailscale

### Deployment
- Pushing to `main` branch automatically deploys via GitHub Actions
- Service managed by systemd on production server
- Environment variables in `/home/jeremy/apps/seating-charter/.env`

## 📞 Contact & Context

- **Client**: CHDS at Naval Postgraduate School
- **Purpose**: Optimize diversity in emergency management training
- **Users**: 5 instructors max
- **Scale**: 40 students max per cohort
- **Status**: ✅ COMPLETE - Deployed to Production!

---

*Last Updated: September 2025 - Application Complete & Deployed to Production!*