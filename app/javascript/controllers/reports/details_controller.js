import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="reports--details"
export default class extends Controller {
  static targets = ['labels', 'datasets', 'canvas']
  static values = { title: String }

  connect() {
    const chartData = {
      labels:   jsonData(this.labelsTarget),
      datasets: jsonData(this.datasetsTarget)
    };
    // It is loaded lazily at runtime
    import('chart.js').then(chart =>
      this.renderChart(chart.default, chartData)
    );
  }

  renderChart(Chart, chartData){
    const backgroundColors = ['rgba(255, 99, 132, 0.2)', 'rgba(54, 162, 235, 0.2)', 'rgba(255, 206, 86, 0.2)', 'rgba(75, 192, 192, 0.2)', 'rgba(153, 102, 255, 0.2)', 'rgba(255, 159, 64, 0.2)'];
    const borderColors     = ['rgba(255, 99, 132, 1)',   'rgba(54, 162, 235, 1)',   'rgba(255, 206, 86, 1)',   'rgba(75, 192, 192, 1)',   'rgba(153, 102, 255, 1)',   'rgba(255, 159, 64, 1)'];
    for (let i = 0; i < chartData.datasets.length; i++) {
      chartData.datasets[i].backgroundColor = backgroundColors[i % backgroundColors.length];
      chartData.datasets[i].borderColor     = borderColors[i % borderColors.length];
      chartData.datasets[i].borderWidth     = 1;
    }
    new Chart(this.canvasTarget, {
      type: 'bar',
      data: chartData,
      options: {
        indexAxis: 'y',
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
          y: {stacked: true},
          x: {stacked: true, ticks: {precision: 0}}
        }
      },
    });
  }
}

function jsonData(template) {
  return template.content ? JSON.parse(template.content.textContent) : []
}


