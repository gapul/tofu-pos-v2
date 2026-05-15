<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import Chart from 'chart.js/auto';

  let { data }: { data: Map<string, number> } = $props();
  let canvas: HTMLCanvasElement | undefined = $state();
  let chart: Chart | null = null;

  function render(map: Map<string, number>) {
    if (!canvas) return;
    if (chart) {
      chart.destroy();
      chart = null;
    }
    // Map 自体が $state proxy 経由で渡って来る可能性があるため、
    // snapshot で proxy を外してから走査する。
    const snap = $state.snapshot(map) as Map<string, number> | Record<string, number>;
    const pairs: Array<[string, number]> = snap instanceof Map
      ? [...snap.entries()]
      : Object.entries(snap).map(([k, v]) => [k, Number(v)]);
    pairs.sort((a, b) => b[1] - a[1]);
    const labels: string[] = Array.from(pairs, (p) => String(p[0]));
    const values: number[] = Array.from(pairs, (p) => Number(p[1]));
    chart = new Chart(canvas, {
      type: 'bar',
      data: {
        labels,
        datasets: [
          {
            label: '注文数',
            data: values,
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
  onDestroy(() => {
    chart?.destroy();
    chart = null;
  });
</script>

<div class="h-40"><canvas bind:this={canvas}></canvas></div>
