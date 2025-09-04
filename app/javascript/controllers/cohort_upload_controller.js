import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="cohort-upload"
export default class extends Controller {
  static targets = [
    "uploadArea", 
    "fileInput",
    "fileInfo",
    "fileName", 
    "fileSize",
    "uploadProgress",
    "processStatus",
    "extractedData",
    "nameField",
    "descriptionField", 
    "startDateField",
    "endDateField",
    "maxStudentsField",
    "studentsPreview",
    "studentsCount",
    "confidenceIndicators",
    "submitButton",
    "manualForm",
    "pdfForm",
    "uploadSection",
    "reviewSection",
    "errorMessage"
  ]

  static values = {
    uploadUrl: String,
    csrfToken: String
  }

  connect() {
    console.log("Cohort upload controller connected")
    this.setupDragAndDrop()
    this.extractedMetadata = null
    this.isProcessing = false
  }

  setupDragAndDrop() {
    const uploadArea = this.uploadAreaTarget

    // Prevent default drag behaviors
    ;['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
      uploadArea.addEventListener(eventName, this.preventDefaults.bind(this), false)
      document.body.addEventListener(eventName, this.preventDefaults.bind(this), false)
    })

    // Highlight drop area when item is dragged over it
    ;['dragenter', 'dragover'].forEach(eventName => {
      uploadArea.addEventListener(eventName, this.highlight.bind(this), false)
    })

    ;['dragleave', 'drop'].forEach(eventName => {
      uploadArea.addEventListener(eventName, this.unhighlight.bind(this), false)
    })

    // Handle dropped files
    uploadArea.addEventListener('drop', this.handleDrop.bind(this), false)
  }

  preventDefaults(e) {
    e.preventDefault()
    e.stopPropagation()
  }

  highlight(e) {
    this.uploadAreaTarget.classList.add('border-blue-500', 'bg-blue-50')
  }

  unhighlight(e) {
    this.uploadAreaTarget.classList.remove('border-blue-500', 'bg-blue-50')
  }

  handleDrop(e) {
    const files = e.dataTransfer.files
    if (files.length > 0) {
      this.handleFile(files[0])
    }
  }

  // Handle file selection via click
  selectFile() {
    this.fileInputTarget.click()
  }

  // Handle file input change
  fileSelected(event) {
    const file = event.target.files[0]
    if (file) {
      this.handleFile(file)
    }
  }

  // Process the selected file
  async handleFile(file) {
    if (this.isProcessing) return

    // Validate file
    if (!this.validateFile(file)) return

    // Show file info
    this.showFileInfo(file)
    
    // Start processing
    await this.processFile(file)
  }

  validateFile(file) {
    // Clear any previous errors
    this.hideError()

    // Check file type
    if (file.type !== 'application/pdf') {
      this.showError('Please select a PDF file.')
      return false
    }

    // Check file size (10MB limit)
    const maxSize = 10 * 1024 * 1024 // 10MB in bytes
    if (file.size > maxSize) {
      this.showError('File size must be less than 10MB.')
      return false
    }

    return true
  }

  showFileInfo(file) {
    this.fileNameTarget.textContent = file.name
    this.fileSizeTarget.textContent = this.formatFileSize(file.size)
    
    // Show the file info section
    if (this.hasFileInfoTarget) {
      this.fileInfoTarget.classList.remove('hidden')
    }
  }

  async processFile(file) {
    this.isProcessing = true
    this.showProgress('Uploading PDF...')

    try {
      // Create FormData for upload
      const formData = new FormData()
      formData.append('roster_pdf', file)
      formData.append('authenticity_token', this.csrfTokenValue)

      // Upload and process
      const response = await fetch(this.uploadUrlValue, {
        method: 'POST',
        body: formData,
        headers: {
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      const result = await response.json()

      if (result.success) {
        this.handleSuccessfulExtraction(result)
      } else {
        this.showError(result.error || 'Failed to process PDF')
      }

    } catch (error) {
      console.error('Error processing file:', error)
      this.showError('Failed to process PDF. Please try again or use manual entry.')
    } finally {
      this.isProcessing = false
      this.hideProgress()
    }
  }

  handleSuccessfulExtraction(result) {
    this.extractedMetadata = result.metadata
    
    // Show extracted data section
    this.showReviewSection()
    
    // Populate form fields
    this.populateFormFields(result.metadata)
    
    // Show students preview
    this.showStudentsPreview(result.students_preview)
    
    // Show confidence indicators
    this.showConfidenceIndicators(result.metadata.confidence)
    
    // Enable submit button
    this.enableSubmitButton()
  }

  populateFormFields(metadata) {
    if (metadata.name) {
      this.nameFieldTarget.value = metadata.name
    }
    
    if (metadata.description) {
      this.descriptionFieldTarget.value = metadata.description
    }
    
    if (metadata.start_date) {
      this.startDateFieldTarget.value = metadata.start_date
    }
    
    if (metadata.end_date) {
      this.endDateFieldTarget.value = metadata.end_date
    }
    
    if (metadata.suggested_max_students) {
      this.maxStudentsFieldTarget.value = metadata.suggested_max_students
    }
  }

  showStudentsPreview(studentsPreview) {
    if (!studentsPreview || studentsPreview.count === 0) {
      this.studentsCountTarget.textContent = "No students detected"
      this.studentsPreviewTarget.innerHTML = "<p class='text-gray-500 italic'>No student data found in PDF</p>"
      return
    }

    this.studentsCountTarget.textContent = `${studentsPreview.estimated_total} students detected`
    
    let html = "<div class='space-y-2'>"
    html += "<h4 class='font-medium text-gray-900'>Sample Students:</h4>"
    html += "<div class='space-y-1'>"
    
    studentsPreview.sample.forEach(student => {
      html += "<div class='text-sm text-gray-700'>"
      html += `<strong>${student.name}</strong>`
      if (student.title) html += ` - ${student.title}`
      if (student.organization) html += ` (${student.organization})`
      html += "</div>"
    })
    
    html += "</div>"
    
    if (studentsPreview.estimated_total > studentsPreview.sample.length) {
      const remaining = studentsPreview.estimated_total - studentsPreview.sample.length
      html += `<p class='text-xs text-gray-500 mt-2'>...and ${remaining} more students</p>`
    }
    
    html += "</div>"
    
    this.studentsPreviewTarget.innerHTML = html
  }

  showConfidenceIndicators(confidence) {
    if (!confidence) return

    let html = "<div class='space-y-2'>"
    html += "<h4 class='text-sm font-medium text-gray-900'>Extraction Confidence:</h4>"
    html += "<div class='space-y-1'>"

    Object.entries(confidence).forEach(([field, score]) => {
      const percentage = Math.round(score * 100)
      const colorClass = score > 0.7 ? 'bg-green-500' : score > 0.4 ? 'bg-yellow-500' : 'bg-red-500'
      
      html += `
        <div class='flex items-center justify-between text-xs'>
          <span class='capitalize'>${field}:</span>
          <div class='flex items-center space-x-2'>
            <div class='w-16 bg-gray-200 rounded-full h-2'>
              <div class='${colorClass} h-2 rounded-full' style='width: ${percentage}%'></div>
            </div>
            <span class='text-gray-600'>${percentage}%</span>
          </div>
        </div>
      `
    })

    html += "</div></div>"

    this.confidenceIndicatorsTarget.innerHTML = html
  }

  showReviewSection() {
    this.uploadSectionTarget.classList.add('hidden')
    this.reviewSectionTarget.classList.remove('hidden')
  }

  showProgress(message) {
    this.processStatusTarget.textContent = message
    this.uploadProgressTarget.classList.remove('hidden')
  }

  hideProgress() {
    this.uploadProgressTarget.classList.add('hidden')
  }

  showError(message) {
    this.errorMessageTarget.textContent = message
    this.errorMessageTarget.classList.remove('hidden')
  }

  hideError() {
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.classList.add('hidden')
    }
  }

  enableSubmitButton() {
    this.submitButtonTarget.disabled = false
    this.submitButtonTarget.classList.remove('opacity-50', 'cursor-not-allowed')
  }

  // Toggle between PDF and manual forms
  showManualForm() {
    this.pdfFormTarget.classList.add('hidden')
    this.manualFormTarget.classList.remove('hidden')
  }

  showPdfForm() {
    this.manualFormTarget.classList.add('hidden')
    this.pdfFormTarget.classList.remove('hidden')
    
    // Reset the review section
    this.reviewSectionTarget.classList.add('hidden')
    this.uploadSectionTarget.classList.remove('hidden')
  }

  // Reset the upload process
  resetUpload() {
    this.extractedMetadata = null
    this.isProcessing = false
    this.fileInputTarget.value = ''
    
    // Clear and hide file info
    this.fileNameTarget.textContent = ''
    this.fileSizeTarget.textContent = ''
    if (this.hasFileInfoTarget) {
      this.fileInfoTarget.classList.add('hidden')
    }
    
    // Reset form fields
    this.nameFieldTarget.value = ''
    this.descriptionFieldTarget.value = ''
    this.startDateFieldTarget.value = ''
    this.endDateFieldTarget.value = ''
    this.maxStudentsFieldTarget.value = '25'
    
    // Clear preview sections
    this.studentsPreviewTarget.innerHTML = ''
    this.confidenceIndicatorsTarget.innerHTML = ''
    
    // Hide error and progress
    this.hideError()
    this.hideProgress()
    
    // Show upload section, hide review
    this.showPdfForm()
  }

  // Utility methods
  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes'

    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))

    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }
}