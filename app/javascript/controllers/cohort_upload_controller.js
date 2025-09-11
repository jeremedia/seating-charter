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
    "errorMessage",
    "progressContainer",
    "extractedContainer",
    "extractedMetadata"
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
    this.startTime = Date.now()
    
    // Show the new progress container and hide old one
    this.showProgressContainer()
    
    // Start with simulated progress
    await this.simulateProgressSteps(file)
  }

  async simulateProgressSteps(file) {
    try {
      // Step 1: Upload phase
      this.updateProgressStep('upload', 'Uploading PDF...', 10)
      await this.delay(500) // Brief delay for user to see
      
      // Step 2: Processing phase (start actual upload)
      this.updateProgressStep('extracting_metadata', 'Extracting cohort information...', 30)
      
      // Create FormData for upload
      const formData = new FormData()
      formData.append('roster_pdf', file)
      formData.append('authenticity_token', this.csrfTokenValue)

      // Start the actual upload in the background while showing progress
      const uploadPromise = fetch(this.uploadUrlValue, {
        method: 'POST',
        body: formData,
        headers: {
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      // Continue progress simulation while upload happens
      await this.delay(2000) // Simulate metadata extraction time
      this.updateProgressStep('parsing_roster', 'Parsing student roster...', 70)
      
      // Wait for actual upload to complete
      const response = await uploadPromise
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      const result = await response.json()
      
      // Step 3: Final processing
      this.updateProgressStep('complete', 'Generating preview...', 95)
      await this.delay(500)

      if (result.success) {
        // Step 4: Complete
        this.updateProgressStep('complete', 'Processing complete!', 100, result)
        await this.delay(1000)
        this.handleSuccessfulExtraction(result)
      } else {
        this.updateProgressStep('error', result.error || 'Failed to process PDF', 0)
      }

    } catch (error) {
      console.error('Error processing file:', error)
      this.updateProgressStep('error', 'Failed to process PDF. Please try again or use manual entry.', 0)
    } finally {
      this.isProcessing = false
    }
  }

  showProgressContainer() {
    if (this.hasProgressContainerTarget) {
      this.progressContainerTarget.classList.remove('hidden')
    }
    
    // Hide the old progress display
    if (this.hasUploadProgressTarget) {
      this.uploadProgressTarget.classList.add('hidden')
    }
  }

  updateProgressStep(step, message, progress, data = null) {
    const elapsed = ((Date.now() - this.startTime) / 1000).toFixed(1)
    
    // Create progress HTML directly (simulating turbo frame update)
    const progressHtml = this.createProgressHtml(step, message, progress, elapsed, data)
    
    // Update the turbo frame directly
    const uploadProgressFrame = document.getElementById('upload_progress')
    if (uploadProgressFrame) {
      uploadProgressFrame.innerHTML = progressHtml
    }
    
    // Also show extracted data if available
    if (data && step === 'complete') {
      this.showExtractedData(data)
    }
  }

  createProgressHtml(step, message, progress, elapsed, data = null) {
    const stepIcons = {
      upload: '📤',
      extracting_metadata: '🔍',
      parsing_roster: '📋',
      complete: '✅',
      error: '❌'
    }

    const stepNames = {
      upload: 'Uploading PDF',
      extracting_metadata: 'Extracting Information', 
      parsing_roster: 'Parsing Student Roster',
      complete: 'Processing Complete',
      error: 'Processing Error'
    }

    const estimatedRemaining = {
      upload: 35,
      extracting_metadata: 25,
      parsing_roster: 10,
      complete: 0,
      error: 0
    }

    return `
      <div class="bg-white border border-blue-200 rounded-lg p-6 shadow-sm">
        <!-- Header -->
        <div class="flex items-center justify-between mb-4">
          <div class="flex items-center space-x-3">
            <div class="flex-shrink-0">
              <div class="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center text-xl">
                ${stepIcons[step] || '⏳'}
              </div>
            </div>
            <div>
              <h3 class="text-lg font-medium text-gray-900">${stepNames[step] || 'Processing'}</h3>
              <p class="text-sm text-gray-600">${message}</p>
            </div>
          </div>
          
          <!-- Time Display -->
          <div class="text-right text-sm text-gray-500">
            <div>Elapsed: ${elapsed}s</div>
            ${estimatedRemaining[step] > 0 ? `<div>Est. remaining: ~${estimatedRemaining[step]}s</div>` : ''}
          </div>
        </div>

        ${step !== 'error' ? `
        <!-- Progress Bar -->
        <div class="mb-4">
          <div class="flex items-center justify-between text-sm text-gray-600 mb-2">
            <span>Progress</span>
            <span>${progress}%</span>
          </div>
          <div class="w-full bg-gray-200 rounded-full h-2">
            <div class="bg-blue-600 h-2 rounded-full transition-all duration-500 ease-out" style="width: ${progress}%"></div>
          </div>
        </div>
        ` : ''}

        ${step === 'error' ? `
        <div class="mt-4 p-3 bg-red-50 border border-red-200 rounded-md">
          <div class="flex items-center">
            <svg class="w-5 h-5 text-red-400" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"></path>
            </svg>
            <div class="ml-3">
              <h3 class="text-sm font-medium text-red-800">Processing Failed</h3>
              <p class="mt-1 text-sm text-red-700">${message}</p>
              <div class="mt-3">
                <button type="button" 
                        data-action="click->cohort-upload#resetUpload"
                        class="inline-flex items-center px-3 py-1 border border-red-300 rounded-md text-xs font-medium text-red-700 bg-red-50 hover:bg-red-100">
                  Try Again
                </button>
              </div>
            </div>
          </div>
        </div>
        ` : ''}

        ${step === 'complete' && data ? `
        <div class="mt-4 p-3 bg-green-50 border border-green-200 rounded-md">
          <div class="flex items-center justify-between">
            <div class="flex items-center">
              <svg class="w-5 h-5 text-green-400" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
              </svg>
              <div class="ml-3">
                <h3 class="text-sm font-medium text-green-800">Processing Complete!</h3>
                <p class="mt-1 text-sm text-green-700">
                  Found ${data.students_preview?.estimated_total || 0} students.
                  ${data.metadata?.name ? `Cohort: "${data.metadata.name}"` : ''}
                </p>
              </div>
            </div>
            <div class="text-xs text-green-600 font-medium">
              ${elapsed}s total
            </div>
          </div>
        </div>
        ` : ''}

        ${!['complete', 'error'].includes(step) ? `
        <!-- Loading Animation -->
        <div class="mt-4 flex items-center justify-center">
          <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-600"></div>
          <span class="ml-2 text-sm text-gray-600">Processing...</span>
        </div>
        ` : ''}
      </div>
    `
  }

  showExtractedData(result) {
    if (!this.hasExtractedContainerTarget) return
    
    this.extractedContainerTarget.classList.remove('hidden')
    
    const extractedDataFrame = document.getElementById('extracted_data')
    if (extractedDataFrame) {
      extractedDataFrame.innerHTML = this.createExtractedDataHtml(result.metadata, result.students_preview)
    }
  }

  createExtractedDataHtml(metadata, studentsPreview) {
    let html = '<div class="space-y-6">'
    
    // Metadata display
    if (metadata) {
      html += `
        <div class="bg-blue-50 rounded-lg p-4">
          <h4 class="text-lg font-medium text-blue-900 mb-3">Extracted Cohort Information</h4>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
      `
      
      if (metadata.name) {
        html += `
          <div>
            <span class="font-medium text-blue-800">Name:</span>
            <span class="text-blue-700">${metadata.name}</span>
          </div>
        `
      }
      
      if (metadata.start_date || metadata.end_date) {
        html += `
          <div>
            <span class="font-medium text-blue-800">Dates:</span>
            <span class="text-blue-700">${metadata.start_date || '?'} to ${metadata.end_date || '?'}</span>
          </div>
        `
      }
      
      html += '</div></div>'
    }
    
    // Students preview
    if (studentsPreview) {
      html += `
        <div class="bg-green-50 rounded-lg p-4">
          <h4 class="text-lg font-medium text-green-900 mb-3">
            Student Roster Preview
            <span class="ml-2 text-sm font-normal text-green-700">
              (${studentsPreview.estimated_total || 0} students detected)
            </span>
          </h4>
      `
      
      if (studentsPreview.sample_students && studentsPreview.sample_students.length > 0) {
        html += '<div class="space-y-2">'
        studentsPreview.sample_students.forEach((student, index) => {
          html += `
            <div class="flex items-center justify-between p-2 bg-white rounded border border-green-200">
              <div class="flex items-center space-x-3">
                <span class="w-6 h-6 bg-green-100 rounded-full flex items-center justify-center text-xs font-medium text-green-800">
                  ${index + 1}
                </span>
                <div>
                  <div class="font-medium text-gray-900">${student.name}</div>
                  <div class="text-sm text-gray-600">
                    ${student.title ? student.title : ''}
                    ${student.title && student.organization ? ' • ' : ''}
                    ${student.organization ? student.organization : ''}
                  </div>
                </div>
              </div>
            </div>
          `
        })
        html += '</div>'
      }
      
      html += '</div>'
    }
    
    html += '</div>'
    return html
  }

  delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms))
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
    if (!studentsPreview || studentsPreview.estimated_total === 0) {
      this.studentsCountTarget.textContent = "No students detected"
      this.studentsPreviewTarget.innerHTML = "<p class='text-gray-500 italic'>No student data found in PDF</p>"
      return
    }

    this.studentsCountTarget.textContent = `${studentsPreview.estimated_total} students detected`
    
    let html = "<div class='space-y-2'>"
    html += "<h4 class='font-medium text-gray-900'>Sample Students:</h4>"
    html += "<div class='space-y-1'>"
    
    const students = studentsPreview.sample_students || []
    students.forEach(student => {
      html += "<div class='text-sm text-gray-700'>"
      html += `<strong>${student.name}</strong>`
      if (student.title) html += ` - ${student.title}`
      if (student.organization) html += ` (${student.organization})`
      html += "</div>"
    })
    
    html += "</div>"
    
    if (studentsPreview.estimated_total > students.length) {
      const remaining = studentsPreview.estimated_total - students.length
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
    
    // Hide new progress containers
    if (this.hasProgressContainerTarget) {
      this.progressContainerTarget.classList.add('hidden')
    }
    if (this.hasExtractedContainerTarget) {
      this.extractedContainerTarget.classList.add('hidden')
    }
    
    // Clear turbo frames
    const uploadProgressFrame = document.getElementById('upload_progress')
    if (uploadProgressFrame) {
      uploadProgressFrame.innerHTML = ''
    }
    
    const extractedDataFrame = document.getElementById('extracted_data')
    if (extractedDataFrame) {
      extractedDataFrame.innerHTML = ''
    }
    
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