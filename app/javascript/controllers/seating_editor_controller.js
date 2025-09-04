import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = [
    "editorContainer",
    "table",
    "studentCard", 
    "unassignedArea",
    "toolbar",
    "diversityScores",
    "constraintViolations",
    "saveStatus",
    "searchInput",
    "searchResults"
  ]
  
  static values = {
    arrangementId: String,
    autoSaveInterval: { type: Number, default: 30000 }, // 30 seconds
    csrfToken: String
  }

  connect() {
    console.log("SeatingEditor controller connected")
    
    this.autoSaveTimer = null
    this.isDragging = false
    this.draggedStudent = null
    this.isModified = false
    this.searchTimeout = null
    
    this.initializeSortables()
    this.startAutoSave()
    this.bindKeyboardEvents()
    this.updateDiversityDisplay()
    this.updateConstraintDisplay()
    
    // Listen for visibility change to pause/resume auto-save
    document.addEventListener('visibilitychange', this.handleVisibilityChange.bind(this))
  }

  disconnect() {
    this.stopAutoSave()
    this.destroySortables()
    document.removeEventListener('visibilitychange', this.handleVisibilityChange.bind(this))
  }

  initializeSortables() {
    // Initialize sortables for each table
    this.tableTargets.forEach(table => {
      this.initializeTableSortable(table)
    })

    // Initialize sortable for unassigned area
    if (this.hasUnassignedAreaTarget) {
      this.initializeUnassignedSortable()
    }
  }

  initializeTableSortable(tableElement) {
    const tableNumber = tableElement.dataset.tableNumber
    
    new Sortable(tableElement.querySelector('.student-cards'), {
      group: 'students',
      animation: 150,
      ghostClass: 'sortable-ghost',
      chosenClass: 'sortable-chosen',
      dragClass: 'sortable-drag',
      
      onStart: (evt) => {
        this.isDragging = true
        this.draggedStudent = {
          id: evt.item.dataset.studentId,
          name: evt.item.dataset.studentName,
          fromTable: evt.from.closest('[data-table-number]').dataset.tableNumber
        }
        
        evt.item.classList.add('dragging')
        this.highlightDropZones()
        this.showDragPreview(evt.item)
      },
      
      onEnd: (evt) => {
        this.isDragging = false
        evt.item.classList.remove('dragging')
        this.clearDropZoneHighlights()
        this.hideDragPreview()
        
        const toTable = evt.to.closest('[data-table-number]').dataset.tableNumber
        const fromTable = this.draggedStudent.fromTable
        
        if (fromTable !== toTable) {
          this.moveStudent(this.draggedStudent.id, fromTable, toTable, evt.newIndex)
        }
        
        this.draggedStudent = null
      },
      
      onMove: (evt) => {
        return this.canDropStudent(evt.dragged, evt.to)
      }
    })
  }

  initializeUnassignedSortable() {
    new Sortable(this.unassignedAreaTarget.querySelector('.student-cards'), {
      group: 'students',
      animation: 150,
      ghostClass: 'sortable-ghost',
      chosenClass: 'sortable-chosen',
      dragClass: 'sortable-drag',
      
      onStart: (evt) => {
        this.isDragging = true
        this.draggedStudent = {
          id: evt.item.dataset.studentId,
          name: evt.item.dataset.studentName,
          fromTable: '0' // Unassigned
        }
        
        evt.item.classList.add('dragging')
        this.highlightDropZones()
        this.showDragPreview(evt.item)
      },
      
      onEnd: (evt) => {
        this.isDragging = false
        evt.item.classList.remove('dragging')
        this.clearDropZoneHighlights()
        this.hideDragPreview()
        
        const toElement = evt.to.closest('[data-table-number]')
        const toTable = toElement ? toElement.dataset.tableNumber : '0'
        const fromTable = this.draggedStudent.fromTable
        
        if (fromTable !== toTable) {
          this.moveStudent(this.draggedStudent.id, fromTable, toTable, evt.newIndex)
        }
        
        this.draggedStudent = null
      }
    })
  }

  destroySortables() {
    // Destroy all Sortable instances
    this.tableTargets.forEach(table => {
      const studentCards = table.querySelector('.student-cards')
      if (studentCards && studentCards.sortable) {
        studentCards.sortable.destroy()
      }
    })
    
    if (this.hasUnassignedAreaTarget) {
      const unassignedCards = this.unassignedAreaTarget.querySelector('.student-cards')
      if (unassignedCards && unassignedCards.sortable) {
        unassignedCards.sortable.destroy()
      }
    }
  }

  async moveStudent(studentId, fromTable, toTable, position = null) {
    this.showSaveStatus('Saving...', 'saving')
    
    try {
      const response = await fetch(`/seating_arrangements/${this.arrangementIdValue}/move_student`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfTokenValue
        },
        body: JSON.stringify({
          student_id: studentId,
          from_table: fromTable,
          to_table: toTable,
          position: position
        })
      })
      
      const result = await response.json()
      
      if (result.success) {
        this.updateDiversityScores(result.new_scores)
        this.updateConstraintViolations(result.constraint_violations)
        this.showSaveStatus('Saved', 'success')
        this.markAsModified()
        
        // Update table diversity indicators
        this.updateTableDiversityIndicators(result.table_layout)
      } else {
        this.showError(result.error)
        this.showSaveStatus('Error', 'error')
        // Revert the UI change
        this.revertMove(studentId, fromTable, toTable)
      }
    } catch (error) {
      console.error('Error moving student:', error)
      this.showError('Failed to move student. Please try again.')
      this.showSaveStatus('Error', 'error')
      this.revertMove(studentId, fromTable, toTable)
    }
  }

  async swapStudents(studentAId, studentBId) {
    this.showSaveStatus('Swapping...', 'saving')
    
    try {
      const response = await fetch(`/seating_arrangements/${this.arrangementIdValue}/swap_students`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfTokenValue
        },
        body: JSON.stringify({
          student_a_id: studentAId,
          student_b_id: studentBId
        })
      })
      
      const result = await response.json()
      
      if (result.success) {
        this.refreshTableLayout(result.table_layout)
        this.updateDiversityScores(result.new_scores)
        this.updateConstraintViolations(result.constraint_violations)
        this.showSaveStatus('Swapped', 'success')
        this.markAsModified()
      } else {
        this.showError(result.error)
        this.showSaveStatus('Error', 'error')
      }
    } catch (error) {
      console.error('Error swapping students:', error)
      this.showError('Failed to swap students. Please try again.')
      this.showSaveStatus('Error', 'error')
    }
  }

  async createTable() {
    try {
      const response = await fetch(`/seating_arrangements/${this.arrangementIdValue}/create_table`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfTokenValue
        }
      })
      
      const result = await response.json()
      
      if (result.success) {
        this.addNewTableToDOM(result.table_number)
        this.showSaveStatus(`Table ${result.table_number} created`, 'success')
        this.markAsModified()
      } else {
        this.showError(result.error)
      }
    } catch (error) {
      console.error('Error creating table:', error)
      this.showError('Failed to create table. Please try again.')
    }
  }

  async deleteTable(tableNumber) {
    if (!confirm(`Are you sure you want to delete Table ${tableNumber}? Students will be moved to unassigned.`)) {
      return
    }
    
    try {
      const response = await fetch(`/seating_arrangements/${this.arrangementIdValue}/delete_table/${tableNumber}`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfTokenValue
        }
      })
      
      const result = await response.json()
      
      if (result.success) {
        this.removeTableFromDOM(tableNumber)
        this.refreshUnassignedArea(result.unassigned_students)
        this.updateDiversityScores(result.new_scores)
        this.showSaveStatus(`Table ${tableNumber} deleted`, 'success')
        this.markAsModified()
      } else {
        this.showError(result.error)
      }
    } catch (error) {
      console.error('Error deleting table:', error)
      this.showError('Failed to delete table. Please try again.')
    }
  }

  async shuffleTable(tableNumber) {
    if (!confirm(`Shuffle students on Table ${tableNumber}?`)) {
      return
    }
    
    try {
      const response = await fetch(`/seating_arrangements/${this.arrangementIdValue}/shuffle_table/${tableNumber}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfTokenValue
        }
      })
      
      const result = await response.json()
      
      if (result.success) {
        this.refreshTableLayout(result.table_layout)
        this.updateDiversityScores(result.new_scores)
        this.showSaveStatus(`Table ${tableNumber} shuffled`, 'success')
        this.markAsModified()
      } else {
        this.showError(result.error)
      }
    } catch (error) {
      console.error('Error shuffling table:', error)
      this.showError('Failed to shuffle table. Please try again.')
    }
  }

  async balanceTables() {
    if (!confirm('Balance table sizes? This will redistribute students across tables.')) {
      return
    }
    
    try {
      const response = await fetch(`/seating_arrangements/${this.arrangementIdValue}/balance_tables`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfTokenValue
        }
      })
      
      const result = await response.json()
      
      if (result.success) {
        this.refreshTableLayout(result.table_layout)
        this.updateDiversityScores(result.new_scores)
        this.showSaveStatus('Tables balanced', 'success')
        this.markAsModified()
      } else {
        this.showError(result.error)
      }
    } catch (error) {
      console.error('Error balancing tables:', error)
      this.showError('Failed to balance tables. Please try again.')
    }
  }

  async undo() {
    try {
      const response = await fetch(`/seating_arrangements/${this.arrangementIdValue}/undo`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfTokenValue
        }
      })
      
      const result = await response.json()
      
      if (result.success) {
        this.refreshTableLayout(result.table_layout)
        this.refreshUnassignedArea(result.unassigned_students)
        this.updateDiversityScores(result.diversity_scores)
        this.showSaveStatus(`Undid: ${result.action}`, 'success')
      } else {
        this.showError(result.error)
      }
    } catch (error) {
      console.error('Error undoing action:', error)
      this.showError('Failed to undo. Please try again.')
    }
  }

  async searchStudents(query) {
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout)
    }
    
    this.searchTimeout = setTimeout(async () => {
      try {
        const response = await fetch(
          `/seating_arrangements/${this.arrangementIdValue}/search_students?query=${encodeURIComponent(query)}`
        )
        const result = await response.json()
        
        this.displaySearchResults(result.students)
      } catch (error) {
        console.error('Error searching students:', error)
      }
    }, 300)
  }

  async applyTemplate(templateName) {
    if (!confirm(`Apply ${templateName} template? This will rearrange all students.`)) {
      return
    }
    
    this.showSaveStatus('Applying template...', 'saving')
    
    try {
      const response = await fetch(`/seating_arrangements/${this.arrangementIdValue}/apply_template`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfTokenValue
        },
        body: JSON.stringify({
          template_name: templateName
        })
      })
      
      const result = await response.json()
      
      if (result.success) {
        this.refreshTableLayout(result.table_layout)
        this.updateDiversityScores(result.new_scores)
        this.showSaveStatus(`${templateName} template applied`, 'success')
        this.markAsModified()
      } else {
        this.showError(result.error)
        this.showSaveStatus('Error', 'error')
      }
    } catch (error) {
      console.error('Error applying template:', error)
      this.showError('Failed to apply template. Please try again.')
      this.showSaveStatus('Error', 'error')
    }
  }

  // Event handlers
  onSearchInput(event) {
    const query = event.target.value.trim()
    
    if (query.length > 0) {
      this.searchStudents(query)
    } else {
      this.clearSearchResults()
    }
  }

  onStudentDoubleClick(event) {
    const studentCard = event.currentTarget
    const studentId = studentCard.dataset.studentId
    
    // Show student details or edit dialog
    this.showStudentDetails(studentId)
  }

  onStudentRightClick(event) {
    event.preventDefault()
    
    const studentCard = event.currentTarget
    const studentId = studentCard.dataset.studentId
    
    this.showStudentContextMenu(event, studentId)
  }

  onTableDoubleClick(event) {
    const table = event.currentTarget
    const tableNumber = table.dataset.tableNumber
    
    if (tableNumber !== '0') {
      this.shuffleTable(tableNumber)
    }
  }

  // Keyboard events
  bindKeyboardEvents() {
    document.addEventListener('keydown', this.handleKeyboardShortcuts.bind(this))
  }

  handleKeyboardShortcuts(event) {
    // Only handle shortcuts when not in input fields
    if (event.target.tagName === 'INPUT' || event.target.tagName === 'TEXTAREA') {
      return
    }
    
    if (event.ctrlKey || event.metaKey) {
      switch (event.key) {
        case 'z':
          event.preventDefault()
          this.undo()
          break
        case 's':
          event.preventDefault()
          this.manualSave()
          break
        case 'f':
          event.preventDefault()
          if (this.hasSearchInputTarget) {
            this.searchInputTarget.focus()
          }
          break
      }
    }
    
    switch (event.key) {
      case 'Escape':
        this.clearSelection()
        this.clearSearchResults()
        break
    }
  }

  // UI Helper methods
  highlightDropZones() {
    this.tableTargets.forEach(table => {
      if (!this.isTableFull(table)) {
        table.classList.add('drop-zone-available')
      } else {
        table.classList.add('drop-zone-full')
      }
    })
    
    if (this.hasUnassignedAreaTarget) {
      this.unassignedAreaTarget.classList.add('drop-zone-available')
    }
  }

  clearDropZoneHighlights() {
    this.tableTargets.forEach(table => {
      table.classList.remove('drop-zone-available', 'drop-zone-full')
    })
    
    if (this.hasUnassignedAreaTarget) {
      this.unassignedAreaTarget.classList.remove('drop-zone-available')
    }
  }

  showDragPreview(element) {
    const preview = element.cloneNode(true)
    preview.id = 'drag-preview'
    preview.classList.add('drag-preview')
    document.body.appendChild(preview)
    
    document.addEventListener('mousemove', this.updateDragPreview.bind(this))
  }

  updateDragPreview(event) {
    const preview = document.getElementById('drag-preview')
    if (preview) {
      preview.style.left = `${event.clientX + 10}px`
      preview.style.top = `${event.clientY + 10}px`
    }
  }

  hideDragPreview() {
    const preview = document.getElementById('drag-preview')
    if (preview) {
      preview.remove()
    }
    document.removeEventListener('mousemove', this.updateDragPreview.bind(this))
  }

  canDropStudent(draggedElement, targetContainer) {
    const targetTable = targetContainer.closest('[data-table-number]')
    
    if (!targetTable) return false
    
    const tableNumber = targetTable.dataset.tableNumber
    const maxSize = parseInt(targetTable.dataset.maxSize) || 8
    const currentSize = targetContainer.children.length
    
    // Allow dropping in unassigned area
    if (tableNumber === '0') return true
    
    // Check table capacity
    if (currentSize >= maxSize && !targetContainer.contains(draggedElement)) {
      return false
    }
    
    return true
  }

  isTableFull(tableElement) {
    const tableNumber = tableElement.dataset.tableNumber
    if (tableNumber === '0') return false // Unassigned can't be full
    
    const maxSize = parseInt(tableElement.dataset.maxSize) || 8
    const currentSize = tableElement.querySelectorAll('.student-card').length
    
    return currentSize >= maxSize
  }

  // Auto-save functionality
  startAutoSave() {
    if (this.autoSaveIntervalValue > 0) {
      this.autoSaveTimer = setInterval(() => {
        if (this.isModified && !this.isDragging) {
          this.autoSave()
        }
      }, this.autoSaveIntervalValue)
    }
  }

  stopAutoSave() {
    if (this.autoSaveTimer) {
      clearInterval(this.autoSaveTimer)
      this.autoSaveTimer = null
    }
  }

  async autoSave() {
    try {
      const response = await fetch(`/seating_arrangements/${this.arrangementIdValue}/auto_save`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfTokenValue
        }
      })
      
      const result = await response.json()
      
      if (result.success) {
        this.isModified = false
        this.showSaveStatus('Auto-saved', 'success', 2000)
      }
    } catch (error) {
      console.error('Auto-save failed:', error)
    }
  }

  async manualSave() {
    await this.autoSave()
    this.showSaveStatus('Saved', 'success')
  }

  markAsModified() {
    this.isModified = true
  }

  handleVisibilityChange() {
    if (document.hidden) {
      this.stopAutoSave()
    } else {
      this.startAutoSave()
    }
  }

  // UI update methods
  showSaveStatus(message, type, duration = 5000) {
    if (this.hasSaveStatusTarget) {
      this.saveStatusTarget.textContent = message
      this.saveStatusTarget.className = `save-status ${type}`
      
      setTimeout(() => {
        this.saveStatusTarget.textContent = ''
        this.saveStatusTarget.className = 'save-status'
      }, duration)
    }
  }

  showError(message) {
    // Create or update error notification
    let errorDiv = document.getElementById('seating-editor-error')
    if (!errorDiv) {
      errorDiv = document.createElement('div')
      errorDiv.id = 'seating-editor-error'
      errorDiv.className = 'error-notification'
      document.body.appendChild(errorDiv)
    }
    
    errorDiv.textContent = message
    errorDiv.classList.add('show')
    
    setTimeout(() => {
      errorDiv.classList.remove('show')
    }, 5000)
  }

  updateDiversityScores(scores) {
    if (this.hasDiversityScoresTarget && scores) {
      // Update diversity scores display
      const scoreElements = this.diversityScoresTarget.querySelectorAll('[data-score]')
      
      scoreElements.forEach(element => {
        const scoreType = element.dataset.score
        if (scores[scoreType] !== undefined) {
          const value = (scores[scoreType] * 100).toFixed(1)
          element.textContent = `${value}%`
          
          // Update color based on score
          element.className = element.className.replace(/score-\w+/, '')
          if (scores[scoreType] >= 0.8) {
            element.classList.add('score-high')
          } else if (scores[scoreType] >= 0.6) {
            element.classList.add('score-medium')
          } else {
            element.classList.add('score-low')
          }
        }
      })
    }
  }

  updateConstraintViolations(violations) {
    if (this.hasConstraintViolationsTarget) {
      this.constraintViolationsTarget.innerHTML = ''
      
      if (violations && violations.length > 0) {
        violations.forEach(violation => {
          const violationElement = document.createElement('div')
          violationElement.className = `violation ${violation.severity}`
          violationElement.innerHTML = `
            <span class="violation-icon">⚠️</span>
            <span class="violation-message">${violation.message}</span>
            ${violation.table_number ? `<span class="violation-table">Table ${violation.table_number}</span>` : ''}
          `
          this.constraintViolationsTarget.appendChild(violationElement)
        })
      }
    }
  }

  updateDiversityDisplay() {
    // Update the initial diversity display
    if (this.hasDiversityScoresTarget) {
      const scores = JSON.parse(this.diversityScoresTarget.dataset.scores || '{}')
      this.updateDiversityScores(scores)
    }
  }

  updateConstraintDisplay() {
    // Update the initial constraint display
    if (this.hasConstraintViolationsTarget) {
      const violations = JSON.parse(this.constraintViolationsTarget.dataset.violations || '[]')
      this.updateConstraintViolations(violations)
    }
  }

  // Additional helper methods would go here...
  refreshTableLayout(tableLayout) {
    // This would refresh the entire table layout from server response
    // For now, we'll trigger a page refresh or implement incremental updates
    console.log('Refreshing table layout:', tableLayout)
  }

  refreshUnassignedArea(unassignedStudents) {
    // Refresh the unassigned students area
    console.log('Refreshing unassigned area:', unassignedStudents)
  }

  displaySearchResults(students) {
    if (this.hasSearchResultsTarget) {
      this.searchResultsTarget.innerHTML = ''
      
      students.forEach(student => {
        const resultElement = document.createElement('div')
        resultElement.className = 'search-result'
        resultElement.innerHTML = `
          <span class="student-name">${student.name}</span>
          <span class="student-org">${student.organization}</span>
          <span class="student-table">Table ${student.current_table || 'Unassigned'}</span>
        `
        
        resultElement.addEventListener('click', () => {
          this.highlightStudent(student.id)
        })
        
        this.searchResultsTarget.appendChild(resultElement)
      })
    }
  }

  clearSearchResults() {
    if (this.hasSearchResultsTarget) {
      this.searchResultsTarget.innerHTML = ''
    }
  }

  highlightStudent(studentId) {
    // Remove existing highlights
    document.querySelectorAll('.student-card.highlighted').forEach(card => {
      card.classList.remove('highlighted')
    })
    
    // Highlight the specific student
    const studentCard = document.querySelector(`[data-student-id="${studentId}"]`)
    if (studentCard) {
      studentCard.classList.add('highlighted')
      studentCard.scrollIntoView({ behavior: 'smooth', block: 'center' })
      
      setTimeout(() => {
        studentCard.classList.remove('highlighted')
      }, 3000)
    }
  }
}