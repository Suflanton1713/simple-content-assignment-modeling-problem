# Benchmarks MiniZinc

Este proyecto ahora tiene una bateria organizada de datos en `data/benchmarks_organized/`. Los archivos originales en `data/` se conservan intactos.

## Que falta para ejecutar

En esta terminal `minizinc` no esta disponible en el `PATH`. Para correr benchmarks necesitas una de estas dos cosas:

1. Instalar MiniZinc y agregar `minizinc.exe` al `PATH`.
2. Pasar la ruta explicita al runner con `-MiniZinc "C:\ruta\MiniZinc\minizinc.exe"`.

Tambien conviene tener solvers como Chuffed, Gecode y, si esta disponible, OR Tools CP-SAT.

## Organizacion de datos

Todos los datos nuevos usan la convencion `C = Iend`, para que la cantidad de contenidos disponibles crezca con el horizonte de decision.

- `base_plain`: datos historicos sin `epsilon` ni `target`. Sus modelos quedaron archivados en `models/unused/`.
- `consensus_free`: datos sin `epsilon` ni `target` para `simple_content_assignment_consensus_free.mzn`.
- `consensus_directed`: datos con `target`, sin `epsilon`, para `simple_content_assignment_consensus_directed.mzn`.
- `epsilon_free`: datos para consenso epsilon no dirigido.
- `epsilon_directed`: datos para consenso epsilon dirigido con `target`.
- `design_free`: datos para `simple_content_design_epsilon_consensus.mzn` en modo no dirigido.
- `design_directed`: datos para `simple_content_design_epsilon_consensus.mzn` en modo dirigido.

El indice completo esta en `data/benchmarks_organized/manifest.csv`.

## Modelos activos

- `models/simple_content_assignment_consensus_free.mzn`
- `models/simple_content_assignment_consensus_directed.mzn`
- `models/simple_content_assignment.mzn`
- `models/simple_content_assignment_epsilon_consensus_free_optimized.mzn`
- `models/simple_content_assignment_epsilon_consensus_directed_optimized.mzn`
- `models/simple_content_assignment_epsilon_consensus_free_chuffed_search.mzn`
- `models/simple_content_assignment_epsilon_consensus_directed_chuffed_search.mzn`
- `models/simple_content_design_epsilon_consensus.mzn`

Los modelos historicos no usados en la bateria principal estan en `models/unused/`.

## Ejecutar pruebas

Regenerar datos:

```powershell
python tools\generate_benchmark_data.py
```

Smoke test rapido con pocos casos:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_benchmarks.ps1 -Suites epsilon_free -Solvers Chuffed -TimeLimitMs 10000 -MaxRuns 5
```

Comparar modelos epsilon no dirigidos:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_benchmarks.ps1 -Suites epsilon_free -Solvers Chuffed,Gecode -TimeLimitMs 60000
```

Comparar modelos epsilon dirigidos:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_benchmarks.ps1 -Suites epsilon_directed -Solvers Chuffed,Gecode -TimeLimitMs 60000
```

Ejecutar las 4 familias principales de consenso:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_benchmarks.ps1 `
  -MiniZinc "C:\Program Files\MiniZinc\minizinc.exe" `
  -Suites consensus_free,consensus_directed,epsilon_free,epsilon_directed `
  -Models simple_content_assignment_consensus_free.mzn,simple_content_assignment_consensus_directed.mzn,simple_content_assignment_epsilon_consensus_free_optimized.mzn,simple_content_assignment_epsilon_consensus_directed_optimized.mzn `
  -Solvers Chuffed,Gecode `
  -TimeLimitMs 1800000 `
  -FullOutput `
  -ResultsDir benchmark_results_four_consensus_models_30min_full_output
```

Ejecutar con ruta explicita a MiniZinc:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_benchmarks.ps1 -MiniZinc "C:\Program Files\MiniZinc\minizinc.exe" -Suites epsilon_free -Solvers Chuffed -TimeLimitMs 60000
```

Los resultados quedan en:

- `benchmark_results/summary.csv`
- `benchmark_results/raw/*.log`

## Recomendacion de orden

Empieza por `smoke`, `small` y `medium` antes de correr `xlarge`, `massive` o `stress500`. Para pruebas grandes, usa primero los modelos optimizados:

- `simple_content_assignment_epsilon_consensus_free_optimized.mzn`
- `simple_content_assignment_epsilon_consensus_directed_optimized.mzn`

Luego compara contra los originales para medir diferencia real de tiempo, nodos, fallos y capacidad de probar optimalidad.
