<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import Chart from 'chart.js/auto';

  let { data }: { data: Map<string, number> } = $props();
  let canvas: HTMLCanvasElement | undefined = $state();
  let chart: Chart | null = null;

  function render(map: Map<string, number>) {
    if (!canvas) return;
    chart?.destroy();
    const entries = [...map.entries()].sort((a, b) => b[1] - a[1]);
    chart = new Chart(canvas, {
      type: 'bar',
      data: {
        labels: entries.map(([k]) => k),
        datasets: [
          {
            label: '注文数',
            data: entries.map(([, v]) => v),
            backgroundColor: '#173a5e',
            borderRadius: 4,
            barThickness: 14,
          },
        ],
      },
      options: {
        indexAxis: 'y',
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false } },
        scales: { x: { beginAtZero: true, ticks: { precision: 0 } } },
      },
    });
  }

  onMount(() => render(data));
  $effect(() => render(data));
  onDestroy(() => chart?.destroy());
</script>

<div class="h-40"><canvas bind:this={canvas}></canvas></div>
