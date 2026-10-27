# Pin npm packages by running ./bin/importmap

pin "application"
pin "calculator"
pin "map"
pin "survey_model"
pin "survey_cards"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "leaflet" # @1.9.4
