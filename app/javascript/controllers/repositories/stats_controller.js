import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="repositories--stats"
export default class extends Controller {
  static targets = ['canvas']
  static values = { url: String, revision: String, change: String, title: String }

  connect() {
    Promise.all([
      // It is loaded lazily at runtime
      import('chart.js'),
      ajaxGet(this.urlValue)
    ]).then(([chart, json]) => {
      this.showStats(chart.default, json)
    })
  }

  showStats(Chart, data) {
    const chartData = {
      labels: data['labels'],
      datasets: [{
        label: this.revisionValue,
        backgroundColor: 'rgba(255, 99, 132, 0.7)',
        borderColor: 'rgb(255, 99, 132)',
        borderWidth: 1,
        data: data['commits']
      }, {
        label: this.changeValue,
        backgroundColor: 'rgba(54, 162, 235, 0.7)',
        borderColor: 'rgb(54, 162, 235)',
        data: data['changes']
      }]
    };
    new Chart(this.canvasTarget.getContext('2d'), {
      type: 'bar',
      data: chartData,
      options: {
        elements: {
          bar: {borderWidth: 2}
        },
        responsive: true,
        plugins: {
          legend: {position: 'right'},
          title: {
            display: true,
            text: this.titleValue
          }
        },
        scales: {
          y: {ticks: {precision: 0}}
        }
      }
    });
  }
}

function ajaxGet(url) {
  return new Promise((resolve, reject) => {
    $.getJSON(url).then(
      function(result) {
        resolve(result)
      },
      function() {
        reject()
      })
  })
}
