# Pin npm packages by running ./bin/importmap

pin "application"
pin "chartkick", to: "https://cdn.jsdelivr.net/npm/chartkick@5.2.1/dist/chartkick.esm.js"
pin "Chart.js", to: "https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
