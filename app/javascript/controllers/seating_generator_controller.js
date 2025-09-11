import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "loadingOverlay", "progressMessage", "progressBar"]

  connect() {
    this.progressSteps = [
      "Loading student data...",
      "Analyzing diversity metrics...",
      "Calculating optimal table combinations...",
      "Applying seating constraints...",
      "Optimizing for maximum diversity...",
      "Running final optimization passes...",
      "Finalizing seating arrangements..."
    ]
  }

  generate(event) {
    console.log("Seating generator activated!")
    
    // Check if we should show loading (only if generate_now is checked or it's a regenerate)
    const generateNowCheckbox = document.getElementById('generate_now')
    const shouldShowLoading = !generateNowCheckbox || generateNowCheckbox.checked || event.submitter?.textContent?.includes('Regenerate')
    
    if (shouldShowLoading) {
      console.log("Showing loading overlay...")
      // Show loading overlay
      this.showLoading()
      
      // Simulate progress updates (in real implementation, this would come from server)
      this.simulateProgress()
    }
    
    // Don't prevent the form submission
    // return true is not needed, just don't call preventDefault
  }

  showLoading() {
    if (this.hasLoadingOverlayTarget) {
      this.loadingOverlayTarget.classList.remove("hidden")
    }
    
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = true
      this.buttonTarget.innerHTML = `
        <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Generating...
      `
    }
  }

  simulateProgress() {
    let step = 0
    const totalSteps = this.progressSteps.length
    
    const interval = setInterval(() => {
      if (step < totalSteps) {
        // Progress calculation:
        // - Never show 0% (start at a small value)
        // - Never reach 100% (max out at 85% for the last step)
        // - Leave room for actual completion
        const progressPercent = Math.min(85, Math.max(5, (step / totalSteps) * 90))
        this.updateProgress(this.progressSteps[step], progressPercent)
        step++
      } else {
        clearInterval(interval)
        // Stay at 85% with "Finalizing..." message until actual redirect
        // This gives visual feedback that we're waiting for the server
      }
    }, 1000) // 1 second per step for realistic feel
  }

  updateProgress(message, percentage) {
    if (this.hasProgressMessageTarget) {
      this.progressMessageTarget.textContent = message
    }
    
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.width = `${percentage}%`
    }
  }

  hideLoading() {
    if (this.hasLoadingOverlayTarget) {
      this.loadingOverlayTarget.classList.add("hidden")
    }
    
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = false
      this.buttonTarget.innerHTML = this.buttonTarget.dataset.originalText || "Generate Seating"
    }
  }
}