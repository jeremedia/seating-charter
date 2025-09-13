import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["label"]

  handleChange(event) {
    const file = event.target.files[0];

    if (file) {
      const fileName = file.name;
      const fileSize = (file.size / 1024 / 1024).toFixed(2);

      this.labelTarget.innerHTML = `
        <div class="flex flex-col items-center justify-center pt-5 pb-6">
          <svg class="w-8 h-8 mb-4 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
          </svg>
          <p class="mb-2 text-sm text-gray-700 font-medium">${fileName}</p>
          <p class="text-xs text-gray-500">${fileSize} MB</p>
          <p class="text-xs text-green-600 mt-2">Ready to upload</p>
        </div>
      `;
    }
  }
}