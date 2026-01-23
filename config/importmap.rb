# frozen_string_literal: true

# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "turndown" # @7.2.0
pin_all_from "app/javascript/controllers", under: "controllers"
pin "tablesort", to: "tablesort.min.js"
pin "tablesort.number", to: "tablesort.number.min.js"
