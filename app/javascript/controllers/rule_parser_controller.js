import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="rule-parser"
export default class extends Controller {
  static targets = ["input", "preview", "previewContent"]
  static values = { 
    previewUrl: String,
    csrfToken: String
  }

  connect() {
    this.timeout = null
    this.csrfTokenValue = document.querySelector('[name="csrf-token"]')?.content || ""
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  previewParsing() {
    const instruction = this.inputTarget.value.trim()
    if (!instruction) {
      this.hidePreview()
      return
    }

    // Show loading state
    this.showLoading()

    // Debounce the preview to avoid too many API calls
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.fetchPreview(instruction)
    }, 1000) // 1 second delay
  }

  async fetchPreview(instruction) {
    try {
      const response = await fetch(this.previewUrlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfTokenValue,
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          instruction_text: instruction
        })
      })

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      const result = await response.json()

      if (result.success) {
        this.showPreview(result)
      } else {
        this.showError(result.error || 'Unknown error occurred')
      }
    } catch (error) {
      console.error('Preview fetch error:', error)
      this.showError(`Network error: ${error.message}`)
    }
  }

  showLoading() {
    this.previewContentTarget.innerHTML = `
      <div class="flex items-center space-x-2">
        <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-600"></div>
        <span class="text-blue-700">Parsing instruction with AI...</span>
      </div>
    `
    this.previewTarget.classList.remove('hidden')
  }

  showPreview(result) {
    const confidence = (result.confidence * 100).toFixed(1)
    const confidenceColor = this.getConfidenceColor(result.confidence)
    
    let content = `
      <div class="flex items-center justify-between mb-3">
        <div class="flex items-center space-x-2">
          <span class="font-medium text-blue-900">AI Interpretation</span>
          <span class="inline-flex items-center px-2 py-1 rounded text-xs font-medium ${confidenceColor}">
            ${confidence}% confidence
          </span>
        </div>
        <span class="text-xs bg-blue-100 text-blue-800 px-2 py-1 rounded">
          ${result.rule_count} rule(s) detected
        </span>
      </div>
    `

    if (result.interpretation && result.interpretation.interpretation) {
      content += `
        <div class="text-sm text-blue-700 mb-3">
          <strong>Understanding:</strong> ${result.interpretation.interpretation}
        </div>
      `
    }

    if (result.interpretation && result.interpretation.rules && result.interpretation.rules.length > 0) {
      content += `
        <div class="space-y-2">
          <div class="text-xs font-medium text-blue-900">Detected Rules:</div>
      `
      
      result.interpretation.rules.forEach((rule, index) => {
        const ruleTypeColor = this.getRuleTypeColor(rule.rule_type)
        content += `
          <div class="bg-white rounded border border-blue-200 p-2">
            <div class="flex items-center space-x-2 mb-1">
              <span class="inline-flex items-center px-2 py-1 rounded text-xs font-medium ${ruleTypeColor}">
                ${this.humanizeRuleType(rule.rule_type)}
              </span>
              <span class="text-xs text-gray-500">Priority: ${rule.priority || (index + 1)}</span>
            </div>
            <div class="text-xs text-gray-700">
              ${rule.description || 'No description provided'}
            </div>
          </div>
        `
      })
      
      content += '</div>'
    }

    if (result.interpretation && result.interpretation.examples && result.interpretation.examples.length > 0) {
      content += `
        <div class="mt-3 text-xs">
          <div class="font-medium text-blue-900 mb-1">Examples:</div>
          <ul class="list-disc list-inside text-blue-700 space-y-1">
      `
      
      result.interpretation.examples.forEach(example => {
        content += `<li>${example}</li>`
      })
      
      content += '</ul></div>'
    }

    this.previewContentTarget.innerHTML = content
    this.previewTarget.classList.remove('hidden')
  }

  showError(error) {
    this.previewContentTarget.innerHTML = `
      <div class="flex items-center space-x-2 text-red-600">
        <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
        </svg>
        <div>
          <strong>Error:</strong> ${error}
        </div>
      </div>
    `
    this.previewTarget.classList.remove('hidden')
  }

  hidePreview() {
    this.previewTarget.classList.add('hidden')
  }

  useTemplate(event) {
    const instruction = event.currentTarget.dataset.instruction
    this.inputTarget.value = instruction
    this.inputTarget.focus()
    
    // Trigger preview after setting the value
    setTimeout(() => {
      this.previewParsing()
    }, 100)
  }

  // Helper methods for styling
  getConfidenceColor(confidence) {
    if (confidence >= 0.9) return 'bg-green-100 text-green-800'
    if (confidence >= 0.7) return 'bg-yellow-100 text-yellow-800'
    return 'bg-red-100 text-red-800'
  }

  getRuleTypeColor(ruleType) {
    const colors = {
      'separation': 'bg-red-100 text-red-800',
      'clustering': 'bg-green-100 text-green-800',
      'distribution': 'bg-blue-100 text-blue-800',
      'proximity': 'bg-purple-100 text-purple-800',
      'custom': 'bg-gray-100 text-gray-800'
    }
    return colors[ruleType] || 'bg-gray-100 text-gray-800'
  }

  humanizeRuleType(ruleType) {
    return ruleType.charAt(0).toUpperCase() + ruleType.slice(1)
  }
}