# Contexto completo del proyecto y benchmarks

Este archivo resume el contexto necesario para que otra IA o agente pueda continuar el trabajo sin leer todo el chat. Incluye el objetivo del proyecto, la estructura de modelos y datos, los comandos que se usaron, los resultados observados, como interpretar los logs, que solvers funcionaron mejor y que rutas conviene evitar.

## Objetivo del proyecto

El proyecto modela un problema de asignacion de contenidos inspirado en plataformas como YouTube. Hay agentes con opiniones iniciales, terquedad o resistencia al cambio, y contenidos con valor ideologico. En cada intervalo de tiempo se decide que contenido mostrar a cada agente, o si no se le muestra contenido. La opinion evoluciona con una dinamica entera inspirada en DeGroot:

```text
opinion[a,t] =
  opinion[a,t-1]                                                si assignment[a,t] = 0
  (stubbornness[a] * opinion[a,t-1]
   + (100 - stubbornness[a]) * contentValue[assignment[a,t]]) div 100
                                                                  si assignment[a,t] != 0
```

Las opiniones y contenidos estan en escala entera `0..100`. Como la actualizacion usa `div 100`, el promedio real se redondea hacia abajo y puede introducir un error menor a 1 punto por actualizacion, con maximo teorico de `0.99`.

La polarizacion en un tiempo `t` se mide como:

```text
max_diff[t] = max(opinion[a,t]) - min(opinion[a,t])
```

Se usa tambien una restriccion de monotonicidad:

```text
max_diff[t] <= max_diff[t-1]
```

## Modelos activos actuales

Despues de limpiar variantes no usadas, los modelos activos en `models/` son:

```text
simple_content_assignment.mzn
simple_content_assignment_consensus_free.mzn
simple_content_assignment_consensus_directed.mzn
simple_content_assignment_epsilon_consensus_free_optimized.mzn
simple_content_assignment_epsilon_consensus_directed_optimized.mzn
simple_content_assignment_epsilon_consensus_free_chuffed_search.mzn
simple_content_assignment_epsilon_consensus_directed_chuffed_search.mzn
simple_content_design_epsilon_consensus.mzn
```

`simple_content_assignment.mzn` se conserva como modelo inicial y mas basico.

`simple_content_design_epsilon_consensus.mzn` no se usa en la bateria principal de benchmarks, pero se conserva porque modela el diseno/eleccion de contenidos en lugar de recibir `contentValue` como dato fijo.

## Modelos eliminados o archivados

Se eliminaron las variantes:

```text
simple_content_assignment_epsilon_consensus_free_chuffed_propagation.mzn
simple_content_assignment_epsilon_consensus_directed_chuffed_propagation.mzn
simple_content_assignment_epsilon_consensus_free_gecode_search.mzn
simple_content_assignment_epsilon_consensus_directed_gecode_search.mzn
```

Tambien se eliminaron carpetas de resultados asociadas directamente a esas variantes:

```text
benchmark_results_epsilon_chuffed_variants_p4_15min_full_output/
benchmark_results_epsilon_directed_gecode_search_xlarge_p16_90min/
benchmark_results_epsilon_directed_gecode_search_xlarge_p8_90min/
```

Los resultados donde `Gecode` se uso como solver sobre los modelos `*_chuffed_search.mzn` se conservaron, porque son utiles y no pertenecen a la variante eliminada `*_gecode_search.mzn`.

Los modelos historicos no usados estan en:

```text
models/unused/
```

## Familias de modelos

### Sin epsilon

`simple_content_assignment_consensus_free.mzn`

- No usa `epsilon`.
- No usa `target`.
- Minimiza `max_diff[Iend]`.
- Busca consenso libre: reducir la brecha final lo mas posible.

`simple_content_assignment_consensus_directed.mzn`

- No usa `epsilon`.
- Usa `target`.
- Agrega:

```text
constraint opinion[1,Iend] = target;
```

- Minimiza `max_diff[Iend]`.
- Busca consenso dirigido con un agente de referencia llegando exactamente al objetivo.

### Con epsilon optimizados

`simple_content_assignment_epsilon_consensus_free_optimized.mzn`

- Usa `epsilon`.
- No usa `target`.
- Exige:

```text
max_diff[Iend] <= epsilon
```

- Minimiza `max_diff[Iend]`.

`simple_content_assignment_epsilon_consensus_directed_optimized.mzn`

- Usa `epsilon`.
- Usa `target`.
- Exige que todos los agentes terminen dentro de la banda:

```text
target - epsilon <= opinion[a,Iend] <= target + epsilon
```

- Minimiza `total_assigned`.

### Variantes chuffed_search

`simple_content_assignment_epsilon_consensus_free_chuffed_search.mzn`

- Misma semantica que `epsilon_free_optimized`.
- Cambia la busqueda a:

```text
restart_luby(100)
int_search([assignment[a,t] | a in AGENT, t in TIME],
           dom_w_deg,
           indomain_min,
           complete)
```

`simple_content_assignment_epsilon_consensus_directed_chuffed_search.mzn`

- Misma semantica que `epsilon_directed_optimized`.
- Usa busqueda similar:

```text
restart_luby(100)
int_search([assignment[a,t] | a in AGENT, t in TIME],
           dom_w_deg,
           indomain_min,
           complete)
```

Aunque se llaman `chuffed_search`, se ejecutaron tambien con OR Tools CP-SAT y Gecode. El nombre se refiere a la anotacion/idea de busqueda, no obliga a usar Chuffed.

## Datos de benchmark

Los datos organizados estan en:

```text
data/benchmarks_organized/
```

El indice completo esta en:

```text
data/benchmarks_organized/manifest.csv
```

Las suites principales son:

```text
base_plain
consensus_free
consensus_directed
epsilon_free
epsilon_directed
design_free
design_directed
```

La convencion usada para los datos principales fue dejar `C = Iend` cuando aplica, porque si los contenidos se agotan antes del horizonte temporal el experimento pierde sentido para estos modelos.

Escalas:

```text
smoke     -> A=6,   C=8,   Iend=8
small     -> A=12,  C=12,  Iend=12
medium    -> A=30,  C=30,  Iend=30
large     -> A=75,  C=75,  Iend=75
xlarge    -> A=150, C=100, Iend=100
massive   -> A=300, C=150, Iend=150
stress500 -> A=500, C=100, Iend=100
```

Escenarios para `epsilon_free` y `consensus_free`:

```text
balanced_bimodal
three_clusters
high_stubborn
```

Escenarios para `epsilon_directed` y `consensus_directed`:

```text
three_clusters / target50
target25_downshift / target25
target75_upshift / target75
```

## Script de benchmarks

El runner principal es:

```text
tools/run_benchmarks.ps1
```

Parametros importantes:

```text
-MiniZinc       ruta a minizinc.exe
-Suites         suites de datos, separadas por coma
-Sizes          tamanos, separados por coma
-Models         modelos, separados por coma
-Solvers        solvers, separados por coma
-Parallel       valor pasado a MiniZinc como --parallel
-TimeLimitMs    limite por ejecucion individual, en milisegundos
-ResultsDir     carpeta de salida
-FullOutput     imprime matriz completa de asignaciones si el modelo soporta full_output
```

Importante: `-TimeLimitMs` es por cada combinacion ejecutada, no para todo el comando completo. Una combinacion es basicamente:

```text
suite + data + model + solver
```

Los logs siempre se guardan en:

```text
<ResultsDir>/raw/
```

El resumen se guarda en:

```text
<ResultsDir>/summary.csv
```

No usar `-FullOutput` en `large`, `xlarge`, `massive` o `stress500` salvo que sea estrictamente necesario. Puede consumir mucha RAM y hacer que la corrida falle al imprimir matrices enormes.

## Solvers disponibles

En esta instalacion de MiniZinc se detectaron, entre otros:

```text
Chuffed 0.13.2
Gecode 6.3.0
OR Tools CP-SAT 9.15
COIN-BC
HiGHS
SCIP
Gurobi
CPLEX
Xpress
```

Los solvers realmente usados y relevantes fueron:

```text
Chuffed 0.13.2
OR Tools CP-SAT 9.15
Gecode 6.3.0
```

Los solvers MIP como HiGHS, COIN-BC, Gurobi, CPLEX o SCIP no son la ruta principal para este modelo tal como esta formulado, porque hay restricciones globales, `element`, reificaciones, `div`, `max/min` y dominios finitos. MiniZinc podria intentar reformular, pero probablemente no sea eficiente.

## Interpretacion de estados

En los `summary.csv`:

```text
optimal_or_complete
```

Significa que el log contiene `==========`. En la practica se interpreta como solucion completa u optimalidad reportada por MiniZinc/solver.

```text
solution_or_timeout
```

Significa que hubo al menos una solucion (`----------`) pero no necesariamente optimalidad. Puede haber llegado al tiempo limite.

```text
unsat
```

El solver probo infactibilidad y reporto `=====UNSATISFIABLE=====`.

```text
unknown
```

El solver no concluyo dentro del limite o reporto desconocido.

```text
error
```

El proceso tuvo `exit_code != 0` o MiniZinc/solver devolvio error. No debe interpretarse automaticamente como infactible.

Cuando los logs muestran:

```text
=====ERROR=====
%%%mzn-stat: nSolutions=0
```

eso significa que no hubo solucion util devuelta. No significa que el modelo sea matematicamente infactible. Puede ser crash del backend, modelo demasiado grande, problema interno del solver, memoria, o fallo de presolve.

## Resultados consolidados

Snapshot al momento de crear este archivo:

```text
summary.csv encontrados: 18
filas totales: 88
optimal_or_complete: 53
error: 28
unsat: 3
unknown: 3
solution_or_timeout: 1
```

### Sin epsilon

`simple_content_assignment_consensus_free.mzn`

```text
smoke: 3/3 exitosos con Chuffed
small: 3/3 exitosos con Chuffed
medium: 3/3 unknown con Gecode a 15 min
large+: sin exitos registrados
```

`simple_content_assignment_consensus_directed.mzn`

```text
smoke: 3/3 exitosos con Chuffed
small: 2/3 exitosos con Chuffed, 1 solution_or_timeout
medium+: sin resultados exitosos registrados
```

### Epsilon optimizados

`simple_content_assignment_epsilon_consensus_free_optimized.mzn`

```text
smoke: three_clusters exitoso; balanced_bimodal y high_stubborn unsat
small: 3/3 exitosos con Chuffed
medium: 3/3 exitosos con Chuffed
large+: sin exitos registrados para este modelo
```

`simple_content_assignment_epsilon_consensus_directed_optimized.mzn`

```text
smoke: 3/3 exitosos con Chuffed
small: 3/3 exitosos con Chuffed
medium: 3/3 exitosos con OR Tools CP-SAT p8
large+: sin exitos registrados para este modelo
```

### Epsilon free chuffed_search

`simple_content_assignment_epsilon_consensus_free_chuffed_search.mzn`

```text
smoke: three_clusters exitoso; balanced_bimodal y high_stubborn unsat
small: 3/3 exitosos con Chuffed
medium: 3/3 exitosos con OR Tools CP-SAT p8
large: 3/3 exitosos con OR Tools CP-SAT p8
xlarge: 3/3 exitosos con Gecode p0
massive: balanced_bimodal exitoso con Gecode p0
stress500: 3 intentos con OR Tools CP-SAT p16, todos error
```

Detalles importantes:

`xlarge` con Gecode p0 fue exitoso:

```text
balanced_bimodal: 106.006 s, optimal_or_complete
three_clusters: 195.990 s, optimal_or_complete
high_stubborn: 285.668 s, optimal_or_complete
```

Carpeta:

```text
benchmark_results_epsilon_free_search_xlarge_gecode_90min
```

`massive balanced_bimodal` con Gecode p0 fue exitoso:

```text
A=300, C=150, Iend=150, epsilon=10
Polarizacion final: 0
wall_time_ms: 2054999 ms
solveTime aprox: 2008.89 s
```

Carpeta:

```text
benchmark_results_epsilon_free_search_massive_stress500_gecode_90min
```

OR Tools CP-SAT fallo en `epsilon_free xlarge`, aunque Gecode si resolvio esos mismos datos. Por tanto, para `epsilon_free xlarge+`, Gecode fue mas estable que OR Tools CP-SAT.

### Epsilon directed chuffed_search

`simple_content_assignment_epsilon_consensus_directed_chuffed_search.mzn`

```text
smoke: 3/3 exitosos con Chuffed
small: 3/3 exitosos con Chuffed
medium: 3/3 exitosos con OR Tools CP-SAT p8
large: 3/3 exitosos con OR Tools CP-SAT p8
xlarge: intentado con OR Tools p12 y Gecode p28, 0 exitos
massive: intentado con OR Tools p12, 0 exitos
stress500: intentado con OR Tools p12, 0 exitos
```

El mejor corte real para directed es:

```text
hasta large exitoso
xlarge en adelante pendiente/fallido
```

En `large`, OR Tools p8 fue mejor que p12. Con p12, `three_clusters` fallo; con p8, los tres escenarios salieron exitosos.

Carpeta buena de `large`:

```text
benchmark_results_epsilon_directed_search_large_ortools_p8_30min
```

Resultados:

```text
large three_clusters: 155.297 s, optimal_or_complete
large target25_downshift: 262.148 s, optimal_or_complete
large target75_upshift: 255.866 s, optimal_or_complete
```

## Comandos importantes usados

### Smoke/small directed chuffed_search

```powershell
cd "C:\Users\lialq\OneDrive\Escritorio\Semestre-2026-I\PRACTICA-INV\modelo_simple"

powershell -ExecutionPolicy Bypass -File tools\run_benchmarks.ps1 `
  -MiniZinc "C:\Program Files\MiniZinc\minizinc.exe" `
  -Suites epsilon_directed `
  -Sizes smoke,small `
  -Models simple_content_assignment_epsilon_consensus_directed_chuffed_search.mzn `
  -Solvers Chuffed `
  -TimeLimitMs 1800000 `
  -ResultsDir benchmark_results_epsilon_directed_search_smoke_small_chuffed_30min
```

Resultado: 6/6 exitosos.

### Directed large con OR Tools p8

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_benchmarks.ps1 `
  -MiniZinc "C:\Program Files\MiniZinc\minizinc.exe" `
  -Suites epsilon_directed `
  -Sizes large `
  -Models simple_content_assignment_epsilon_consensus_directed_chuffed_search.mzn `
  -Solvers "OR Tools CP-SAT" `
  -Parallel 8 `
  -TimeLimitMs 1800000 `
  -ResultsDir benchmark_results_epsilon_directed_search_large_ortools_p8_30min
```

Resultado: 3/3 exitosos.

### Directed large a stress500 con OR Tools p12

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_benchmarks.ps1 `
  -MiniZinc "C:\Program Files\MiniZinc\minizinc.exe" `
  -Suites epsilon_directed `
  -Sizes large,xlarge,massive,stress500 `
  -Models simple_content_assignment_epsilon_consensus_directed_chuffed_search.mzn `
  -Solvers "OR Tools CP-SAT" `
  -Parallel 12 `
  -TimeLimitMs 5400000 `
  -ResultsDir benchmark_results_epsilon_directed_search_large_to_stress500_ortools_p12_90min
```

Resultado: 2/12 exitosos. Large target25 y target75 salieron; large three_clusters y xlarge+ fallaron.

### Free xlarge con Gecode p0

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_benchmarks.ps1 `
  -MiniZinc "C:\Program Files\MiniZinc\minizinc.exe" `
  -Suites epsilon_free `
  -Sizes xlarge `
  -Models simple_content_assignment_epsilon_consensus_free_chuffed_search.mzn `
  -Solvers Gecode `
  -TimeLimitMs 5400000 `
  -ResultsDir benchmark_results_epsilon_free_search_xlarge_gecode_90min
```

Resultado: 3/3 exitosos.

### Free massive/stress500 con Gecode p0

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_benchmarks.ps1 `
  -MiniZinc "C:\Program Files\MiniZinc\minizinc.exe" `
  -Suites epsilon_free `
  -Sizes massive,stress500 `
  -Models simple_content_assignment_epsilon_consensus_free_chuffed_search.mzn `
  -Solvers Gecode `
  -TimeLimitMs 5400000 `
  -ResultsDir benchmark_results_epsilon_free_search_massive_stress500_gecode_90min
```

Resultado registrado: solo 1 test exitoso (`massive balanced_bimodal`). La ejecucion se detuvo/interrumpio antes de registrar los demas.

### Free large a stress500 con OR Tools p16

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_benchmarks.ps1 `
  -MiniZinc "C:\Program Files\MiniZinc\minizinc.exe" `
  -Suites epsilon_free,epsilon_directed `
  -Sizes large,xlarge,massive,stress500 `
  -Models simple_content_assignment_epsilon_consensus_free_chuffed_search.mzn,simple_content_assignment_epsilon_consensus_directed_chuffed_search.mzn `
  -Solvers "OR Tools CP-SAT" `
  -Parallel 16 `
  -TimeLimitMs 5400000 `
  -ResultsDir benchmark_results_epsilon_search_large_to_stress500_ortools_p16_90min
```

En la practica, para `epsilon_free` registro xlarge/massive/stress500 con errores. Los large free exitosos ya estaban en una carpeta anterior con p8.

### Debug directo OR Tools xlarge free

Este comando se uso para ver mas informacion que el runner normal:

```powershell
& "C:\Program Files\MiniZinc\minizinc.exe" `
  --solver "OR Tools CP-SAT" `
  --time-limit 5400000 `
  --statistics `
  --verbose `
  --parallel 8 `
  -I models `
  models\simple_content_assignment_epsilon_consensus_free_chuffed_search.mzn `
  data\benchmarks_organized\epsilon_free\xlarge_150a_100i_balanced_bimodal_epsilon10.dzn `
  2>&1 | Tee-Object debug_ortools_xlarge_free.log
```

Resultado: OR Tools fallo con `=====ERROR=====`. El log mostro que el modelo presuelto llegaba a mas de 3 millones de variables y mas de 9 millones de restricciones lineales simples:

```text
#Variables: 3'082'501
#kLinear1: 9'006'662
[Symmetry] Problem too large. Skipping.
=====ERROR=====
nSolutions=0
```

Interpretacion: no es infactible probado; CP-SAT explota en tamano/presolve para esa instancia.

### Debug directo Gecode xlarge free

```powershell
& "C:\Program Files\MiniZinc\minizinc.exe" `
  --solver Gecode `
  --time-limit 5400000 `
  --statistics `
  --verbose `
  -I models `
  models\simple_content_assignment_epsilon_consensus_free_chuffed_search.mzn `
  data\benchmarks_organized\epsilon_free\xlarge_150a_100i_balanced_bimodal_epsilon10.dzn `
  2>&1 | Tee-Object debug_gecode_xlarge_free.log
```

Resultado: Gecode si resolvio.

```text
A=150 C=100 Iend=100 epsilon=10
Polarizacion final: 0
solveTime=78.283
nSolutions=1
Done (overall time 89.50 s)
```

## Paralelizacion

La maquina tiene 32 logical processors.

Se probaron distintos niveles:

```text
OR Tools CP-SAT p8
OR Tools CP-SAT p12
OR Tools CP-SAT p16
Gecode p0
Gecode p28
```

Conclusiones:

- OR Tools CP-SAT p8 fue bueno en medium y large, especialmente directed.
- OR Tools CP-SAT p12 no mejoro directed large; incluso fallo `large three_clusters`, que p8 habia resuelto.
- OR Tools CP-SAT p16 fallo en xlarge/massive/stress500 para free.
- Gecode p0 resolvio `epsilon_free xlarge` completo y `massive balanced_bimodal`.
- Gecode p28 fallo en directed xlarge.
- Mas hilos no implican mejor resultado. En estos modelos grandes, mas paralelismo puede aumentar memoria y overhead.

Recomendacion actual:

```text
Chuffed: smoke/small
OR Tools CP-SAT p8: medium/large directed y free large
Gecode p0: epsilon_free xlarge/massive
No usar p28 como default
```

Si se quiere probar Gecode paralelo, empezar con p4 o p8, no p28.

## Recomendaciones para futuras ejecuciones

### Epsilon free

Ruta recomendada:

```text
smoke/small: Chuffed
medium/large: OR Tools CP-SAT p8 o Chuffed segun caso
xlarge/massive: Gecode p0
stress500: pendiente; probar Gecode p0 o p4, con paciencia
```

Comando sugerido para continuar los faltantes free:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_benchmarks.ps1 `
  -MiniZinc "C:\Program Files\MiniZinc\minizinc.exe" `
  -Suites epsilon_free `
  -Sizes massive,stress500 `
  -Models simple_content_assignment_epsilon_consensus_free_chuffed_search.mzn `
  -Solvers Gecode `
  -TimeLimitMs 5400000 `
  -ResultsDir benchmark_results_epsilon_free_search_massive_stress500_gecode_retry_90min
```

### Epsilon directed

Ruta recomendada:

```text
smoke/small: Chuffed
medium/large: OR Tools CP-SAT p8
xlarge+: no hay solver/parametro exitoso aun
```

No confiar en OR Tools p12 ni Gecode p28 para xlarge directed. Si se quiere seguir intentando, probar OR Tools p8, Chuffed con mucho tiempo, o reformular/reducir el modelo.

Comando razonable para reintentar directed xlarge con OR Tools p8:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_benchmarks.ps1 `
  -MiniZinc "C:\Program Files\MiniZinc\minizinc.exe" `
  -Suites epsilon_directed `
  -Sizes xlarge `
  -Models simple_content_assignment_epsilon_consensus_directed_chuffed_search.mzn `
  -Solvers "OR Tools CP-SAT" `
  -Parallel 8 `
  -TimeLimitMs 5400000 `
  -ResultsDir benchmark_results_epsilon_directed_search_xlarge_ortools_p8_retry_90min
```

Pero la expectativa es incierta.

## Cosas que NO deben interpretarse mal

1. `error` no significa infactible.

Solo `unsat` significa que el solver probo infactibilidad.

2. `chuffed_search` no significa que solo sirva con Chuffed.

Se uso con Chuffed, OR Tools CP-SAT y Gecode.

3. `-TimeLimitMs` es por test individual.

Un comando con muchas combinaciones puede durar muchas horas.

4. `-FullOutput` no debe usarse en grandes.

Puede matar la corrida al imprimir matrices enormes.

5. Los resultados de Gecode como solver no deben borrarse solo porque se eliminaron los modelos `*_gecode_search.mzn`.

Los modelos `*_gecode_search.mzn` fueron variantes experimentales eliminadas. Pero los resultados utiles de Gecode sobre `*_chuffed_search.mzn` se conservan.

6. Las carpetas con nombres `p16`, `p28`, etc. pueden tener inconsistencias historicas.

Leer siempre `summary.csv`, columna `parallel`, para saber el valor real usado.

## Informe LaTeX

Se creo un borrador de informe en:

```text
reports/informe_modelos_consenso.tex
```

Incluye:

- portada,
- indice,
- introduccion,
- estado del arte pendiente,
- formulacion matematica,
- parametros y variables,
- explicacion de restricciones,
- solvers,
- tablas y graficas preliminares,
- conclusiones,
- notas amarillas para que otra IA sepa que completar.

El informe se compilo correctamente con `pdflatex` en una carpeta temporal. Hubo advertencias menores, no errores fatales.

Se hizo commit y push a `develop` con:

```text
b21d36e Add LaTeX draft report for consensus models
```

## Estado Git y limpieza

Al momento de escribir este contexto, el arbol tiene cambios no commiteados por limpieza:

- `BENCHMARKS.md` modificado para quitar modelos eliminados.
- `models/unused/README.md` modificado para quitar modelos eliminados.
- eliminados modelos `propagation` y `gecode_search`.
- eliminadas carpetas de resultados relacionadas con `propagation` y `gecode_search`.

No usar `git reset --hard` ni revertir cambios sin permiso, porque hay muchas modificaciones historicas y resultados de benchmark.

## Resumen ejecutivo para otra IA

Si solo se necesita continuar benchmarks:

1. Para `epsilon_free`, los mejores resultados grandes vienen de `simple_content_assignment_epsilon_consensus_free_chuffed_search.mzn` con Gecode p0.
2. Para `epsilon_directed`, los resultados confiables llegan hasta `large` usando OR Tools CP-SAT p8.
3. `xlarge+` directed sigue abierto; no hay exito.
4. OR Tools CP-SAT explota en xlarge free con millones de variables/restricciones; Gecode p0 lo resolvio.
5. No usar las variantes `propagation` ni `gecode_search`; fueron eliminadas.
6. No activar `FullOutput` en grandes.
7. Revisar siempre `summary.csv` y luego `raw/*.log` si hay dudas.

