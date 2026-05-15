<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import Chart from 'chart.js/auto';

  let { hourly }: { hourly: number[] } = $props();
  let canvas: HTMLCanvasElement | undefined = $state();
  let chart: Chart | null = null;

  function render(data: number[]) {
    if (!canvas) return;
    chart?.destroy();
    chart = new Chart(canvas, {
      type: 'bar',
      data: {
        labels: Array.from({ length: 24 }, (_, h) => `${h}時`),
        datasets: [
          {
            label: '売上',
            data,
            backgroundColor: '#173a5e',
            hoverBackgroundColor: '#b83b3b',
            borderRadius: 4,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false } },
        scales: {
          y: {
            beginAtZero: true,
            ticks: { callback: (v) => '¥' + Number(v).toLocaleString('ja-JP') },
          },
        },
      },
    });
  }

  onMount(() => render(hourly));
  $effect(() => render(hourly));
  onDestroy(() => chart?.destroy());
</script>

<div class="h-64"><canvas bind:this={canvas}></canvas></div>
