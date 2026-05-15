<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import Chart from 'chart.js/auto';

  let { hourly }: { hourly: number[] } = $props();
  let canvas: HTMLCanvasElement | undefined = $state();
  let chart: Chart | null = null;

  function render(data: number[]) {
    if (!canvas) return;
    // 既存 chart を確実に破棄してから canvas を再利用する。
    if (chart) {
      chart.destroy();
      chart = null;
    }
    // Chart.js は data 配列を defineProperty で内部書換するため、
    // Svelte 5 の $state proxy を渡すと state_descriptors_fixed でクラッシュ。
    // $state.snapshot で deep に proxy を外し、Array.from で plain Array を作る。
    const plain: number[] = Array.from($state.snapshot(data) as number[], (v) => Number(v));
    chart = new Chart(canvas, {
      type: 'bar',
      data: {
        labels: Array.from({ length: 24 }, (_, h) => `${h}時`),
        datasets: [
          {
            label: '売上',
            data: plain,
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
  onDestroy(() => {
    chart?.destroy();
    chart = null;
  });
</script>

<div class="h-64"><canvas bind:this={canvas}></canvas></div>
