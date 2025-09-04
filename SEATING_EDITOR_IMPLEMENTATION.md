# Seating Editor Implementation Guide

This document provides a comprehensive overview of the drag-and-drop seating editor implementation for the CHDS Seating Charter Rails application.

## Overview

The seating editor is a sophisticated web-based interface that allows users to manually adjust seating arrangements through drag-and-drop functionality. It provides real-time feedback on diversity scores, constraint violations, and supports various advanced features like undo/redo, auto-save, templates, and collaborative editing.

## Architecture

### Components

1. **Backend Service Layer**
   - `SeatingEditorService` - Core business logic for seating operations
   - `SeatingEditorsController` - AJAX API endpoints

2. **Frontend Layer**
   - Stimulus controller for drag-and-drop functionality
   - HTML/ERB views with partial components
   - CSS styles for responsive design

3. **Data Layer**
   - Enhanced models with editor-specific fields
   - Database migrations for new functionality

## File Structure

```
app/
├── services/
│   └── seating_editor_service.rb           # Core business logic
├── controllers/
│   └── seating_editors_controller.rb       # AJAX API endpoints
├── javascript/controllers/
│   └── seating_editor_controller.js        # Stimulus drag-and-drop controller
├── views/seating_editors/
│   ├── edit.html.erb                       # Main editor interface
│   ├── _table.html.erb                     # Table component
│   ├── _student_card.html.erb              # Draggable student cards
│   └── _toolbar.html.erb                   # Editor toolbar
├── assets/stylesheets/
│   └── seating_editor.css                  # Comprehensive CSS styles
└── models/
    ├── seating_arrangement.rb              # Enhanced with editor fields
    └── table_assignment.rb                 # Enhanced with position field
```

## Key Features Implemented

### 1. Drag-and-Drop Interface
- **HTML5 native drag-and-drop** with SortableJS enhancement
- **Visual feedback** during drag operations
- **Drop zone highlighting** with availability indicators
- **Drag preview** with rotation effect
- **Touch support** for tablet devices

### 2. Real-Time Updates
- **AJAX-based** student movements
- **Automatic diversity score** recalculation
- **Constraint violation detection** and display
- **Live table capacity** monitoring

### 3. Editor Tools
- **Table Management**: Create, delete, shuffle, balance tables
- **Student Operations**: Bulk select, search, auto-arrange
- **Templates**: U-shape, classroom, round tables
- **View Options**: Grid view, color coding, fullscreen

### 4. Persistence & History
- **Auto-save** every 30 seconds
- **Manual save** with Ctrl+S
- **Undo functionality** with action history
- **Version tracking** with timestamps

### 5. Collaboration Features
- **Lock/unlock arrangements** for exclusive editing
- **Real-time status** indicators
- **User activity tracking**

### 6. Accessibility
- **Keyboard navigation** support
- **Screen reader** compatibility
- **High contrast** mode support
- **Reduced motion** preferences

## API Endpoints

### Student Movement
```
POST /seating_arrangements/:id/move_student
POST /seating_arrangements/:id/swap_students
```

### Table Management
```
POST /seating_arrangements/:id/create_table
DELETE /seating_arrangements/:id/delete_table/:table_number
POST /seating_arrangements/:id/balance_tables
POST /seating_arrangements/:id/shuffle_table/:table_number
```

### Editor Operations
```
POST /seating_arrangements/:id/undo
POST /seating_arrangements/:id/auto_save
GET /seating_arrangements/:id/status
POST /seating_arrangements/:id/apply_template
```

### Search & Export
```
GET /seating_arrangements/:id/search_students
GET /seating_arrangements/:id/export
```

## Database Schema Changes

### SeatingArrangement Enhancements
```sql
ALTER TABLE seating_arrangements ADD COLUMN last_modified_at DATETIME;
ALTER TABLE seating_arrangements ADD COLUMN last_modified_by_id BIGINT;
ALTER TABLE seating_arrangements ADD COLUMN is_locked BOOLEAN DEFAULT FALSE;
ALTER TABLE seating_arrangements ADD COLUMN locked_by_id BIGINT;
ALTER TABLE seating_arrangements ADD COLUMN locked_at DATETIME;
```

### TableAssignment Enhancements
```sql
ALTER TABLE table_assignments ADD COLUMN position INTEGER;
```

## Usage Instructions

### Basic Operations

1. **Access Editor**
   ```ruby
   # Route: /seating_arrangements/:id/edit_seating
   # Or programmatically:
   edit_seating_seating_arrangement_path(@arrangement)
   ```

2. **Drag Students**
   - Click and drag student cards between tables
   - Watch diversity scores update in real-time
   - Check constraint violations panel

3. **Table Management**
   - Use "Add Table" to create new tables
   - Right-click tables for context menu
   - Double-click to shuffle table

4. **Search Students**
   - Type in search box to find specific students
   - Click search results to highlight students

### Advanced Features

1. **Auto-Arrange**
   - Use toolbar dropdown to balance by attributes
   - Apply seating templates for quick layouts

2. **Bulk Operations**
   - Enable bulk select mode from toolbar
   - Select multiple students for group operations

3. **Keyboard Shortcuts**
   - `Ctrl+Z`: Undo last action
   - `Ctrl+S`: Save changes
   - `Ctrl+F`: Focus search
   - `Escape`: Clear selection

## Configuration

### Auto-Save Interval
```javascript
// Default: 30 seconds
data-seating-editor-auto-save-interval-value="30000"
```

### Table Capacity
```erb
<!-- Default: 8 students per table -->
data-max-size="8"
```

### Color Coding
The editor supports multiple color-coding modes:
- Gender-based highlighting
- Agency level indicators  
- Department type colors
- Seniority level coding

## Performance Considerations

### Frontend Optimization
- **Virtual scrolling** for large student lists
- **Debounced search** with 300ms delay
- **Efficient DOM updates** with targeted refreshes
- **Memory management** with proper cleanup

### Backend Optimization
- **Service layer** for business logic separation
- **Optimistic locking** for concurrent access
- **Bulk operations** for multiple changes
- **Caching** of diversity calculations

## Error Handling

### Client-Side
- **Network error recovery** with retry logic
- **Validation feedback** before server requests
- **Graceful degradation** when JavaScript disabled
- **User-friendly error messages**

### Server-Side
- **Transaction rollback** on failures
- **Constraint validation** before commits
- **Detailed error responses** for debugging
- **Logging** of all operations

## Security Considerations

### CSRF Protection
```ruby
# All AJAX requests include CSRF token
data-seating-editor-csrf-token-value="<%= form_authenticity_token %>"
```

### Authorization
- User must be authenticated
- Arrangement access controlled by ownership
- Lock mechanism prevents concurrent edits

### Input Validation
- Student and table IDs validated
- Position values sanitized
- Template names whitelisted

## Testing Strategy

### Unit Tests
- Service methods for all operations
- Model validations and associations
- Helper methods and calculations

### Integration Tests
- Controller endpoints with various scenarios
- Error conditions and edge cases
- Permission and access control

### Frontend Tests
- Stimulus controller behavior
- Drag-and-drop functionality
- Keyboard navigation
- Accessibility compliance

## Browser Support

### Minimum Requirements
- **Chrome 60+**
- **Firefox 55+**
- **Safari 12+**
- **Edge 79+**

### Mobile Support
- **iOS Safari 12+**
- **Chrome Mobile 60+**
- **Samsung Internet 8+**

### Features Used
- HTML5 Drag and Drop API
- CSS Grid and Flexbox
- ES6 Classes and Modules
- Fetch API for AJAX
- CSS Custom Properties

## Deployment Checklist

### Prerequisites
1. Rails 8+ with Stimulus and Turbo
2. SortableJS library included
3. Database migrations run
4. CSS and JS assets compiled

### Configuration
1. Set auto-save interval in views
2. Configure table capacity limits
3. Set up error monitoring
4. Enable performance profiling

### Monitoring
1. Track editor usage analytics
2. Monitor AJAX endpoint performance
3. Watch for JavaScript errors
4. Measure user engagement metrics

## Future Enhancements

### Planned Features
1. **Real-time collaboration** with WebSockets
2. **Advanced templates** with custom layouts
3. **AI-powered suggestions** during manual edits
4. **Export to PDF** with visual layouts
5. **Mobile app** with native drag-and-drop

### Technical Improvements
1. **WebGL rendering** for large arrangements
2. **Progressive Web App** capabilities
3. **Offline editing** with sync
4. **Advanced analytics** dashboard

## Troubleshooting

### Common Issues

1. **Drag not working**
   - Check SortableJS is loaded
   - Verify Stimulus controller connected
   - Ensure proper HTML structure

2. **Save failures**
   - Check network connectivity
   - Verify CSRF token validity
   - Review server logs for errors

3. **Performance issues**
   - Reduce auto-save frequency
   - Enable grid view for large arrangements
   - Check browser memory usage

4. **Style conflicts**
   - Verify CSS load order
   - Check for conflicting frameworks
   - Review responsive breakpoints

### Debug Mode
Enable debugging with:
```javascript
// In browser console
window.seatingEditorDebug = true;
```

This provides detailed logging of all operations and state changes.

## Support

For technical support or feature requests:
1. Check existing GitHub issues
2. Review this implementation guide
3. Contact the development team
4. Submit detailed bug reports with browser info

---

This implementation provides a comprehensive, accessible, and performant seating editor that meets all the requirements specified in Issue #11. The modular architecture makes it easy to extend and maintain while providing an excellent user experience across devices.