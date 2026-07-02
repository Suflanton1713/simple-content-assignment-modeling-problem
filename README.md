# Modelo simple de asignacion de contenidos y consenso de opiniones

Este repositorio contiene modelos MiniZinc para estudiar como una plataforma puede asignar contenidos a agentes con el objetivo de modificar la evolucion de sus opiniones. El proyecto usa una dinamica inspirada en el modelo de DeGroot: cada agente tiene una opinion entera en la escala `0..100`, una terquedad o resistencia al cambio, y recibe contenidos con un valor ideologico tambien entre `0..100`.

La pregunta central es como seleccionar contenidos por agente e intervalo para reducir polarizacion o conducir la poblacion hacia una zona objetivo, respetando restricciones de no repeticion, intensidad de intervencion y evolucion temporal de las opiniones.

## Estructura del repositorio

```text
.
|-- models/                      Modelos MiniZinc activos y carpeta de modelos no usados.
|-- data/benchmarks_organized/   Datos .dzn organizados por suite, escala y escenario.
|-- tools/                       Generador de datos y runner de benchmarks.
|-- benchmark_results_archive/   Resultados historicos de benchmarks.
|-- reports/                     Informe en LaTeX del proyecto.
|-- BENCHMARKS.md                Guia corta para ejecutar benchmarks.
|-- Context.md                   Contexto extendido del desarrollo y de las pruebas.
`-- simple_content_assignment_project.mzp
```

## Modelos incluidos

Los modelos activos estan en `models/`.

### Modelo base

- `simple_content_assignment.mzn`

Modelo inicial y mas basico. Representa asignacion de contenidos y propagacion de opinion sin las restricciones de consenso mas elaboradas. Se conserva como punto de partida conceptual.

### Consenso sin epsilon

- `simple_content_assignment_consensus_free.mzn`
- `simple_content_assignment_consensus_directed.mzn`

El modelo `consensus_free` minimiza la polarizacion final sin exigir un objetivo externo. El modelo `consensus_directed` agrega una meta dirigida:

```minizinc
constraint opinion[1,Iend] = target;
```

Es decir, el agente 1 debe terminar exactamente en `target`.

### Consenso con epsilon optimizado

- `simple_content_assignment_epsilon_consensus_free_optimized.mzn`
- `simple_content_assignment_epsilon_consensus_directed_optimized.mzn`

Estas variantes introducen una tolerancia `epsilon`.

En el caso libre se exige que la polarizacion final este por debajo de `epsilon`. En el caso dirigido, las opiniones finales deben quedar dentro de la banda:

```text
[target - epsilon, target + epsilon]
```

Estas formulaciones incluyen mejoras de dominio, restricciones globales, salida compacta y parametros de intensidad de intervencion desde los `.dzn`.

### Variantes search mas optimizadas

- `simple_content_assignment_epsilon_consensus_free_chuffed_search.mzn`
- `simple_content_assignment_epsilon_consensus_directed_chuffed_search.mzn`

Mantienen la misma esencia matematica de los modelos epsilon optimizados, pero modifican anotaciones de busqueda para mejorar el desempeno practico. Aunque el nombre menciona Chuffed, tambien se han probado con OR Tools CP-SAT y Gecode.

### Diseno de contenidos

- `simple_content_design_epsilon_consensus.mzn`

Modelo adicional donde el solver puede decidir valores de contenidos, no solamente asignar contenidos ya dados. No fue el foco principal de los benchmarks, pero se conserva porque modela una variante importante del problema.

### Modelos no usados

Los modelos antiguos o descartados estan en:

```text
models/unused/
```

No se eliminan para mantener trazabilidad historica, pero no forman parte de la bateria principal actual.

## Datos de prueba

Los datos estan organizados en:

```text
data/benchmarks_organized/
```

El indice completo esta en:

```text
data/benchmarks_organized/manifest.csv
```

Las suites principales son:

- `base_plain`: casos base historicos sin `epsilon` ni `target`.
- `consensus_free`: datos para consenso libre sin epsilon.
- `consensus_directed`: datos con `target` para consenso dirigido sin epsilon.
- `epsilon_free`: datos para consenso libre con tolerancia epsilon.
- `epsilon_directed`: datos para consenso dirigido con `target` y `epsilon`.
- `design_free`: datos para diseno de contenidos no dirigido.
- `design_directed`: datos para diseno de contenidos dirigido.

Las escalas usadas son:

| Escala | Agentes | Intervalos | Contenidos |
|---|---:|---:|---:|
| smoke | 6 | 8 | 8 |
| small | 12 | 12 | 12 |
| medium | 30 | 30 | 30 |
| large | 75 | 75 | 75 |
| xlarge | 150 | 100 | 100 |
| massive | 300 | 150 | 150 |
| stress500 | 500 | 100 | 100 |

Los escenarios principales son:

- `balanced_bimodal`: dos grupos separados, cerca de extremos opuestos.
- `three_clusters`: tres grupos de opinion, con un cluster intermedio.
- `high_stubborn`: agentes con mayor terquedad.
- `target25_downshift`: caso dirigido hacia una opinion baja.
- `target75_upshift`: caso dirigido hacia una opinion alta.

Los `.dzn` actuales tambien incluyen parametros de intensidad de intervencion:

- `min_zero_per_agent`
- `min_assign_per_agent`

Con ellos el modelo calcula la cota efectiva de asignaciones por agente. Esto permite cambiar la politica de intervencion desde datos sin editar el `.mzn`.

## Herramientas

### Generar datos

```powershell
python tools\generate_benchmark_data.py
```

### Ejecutar benchmarks

El runner principal es:

```text
tools/run_benchmarks.ps1
```

Ejemplo de smoke test:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_benchmarks.ps1 `
  -MiniZinc "C:\Program Files\MiniZinc\minizinc.exe" `
  -Suites epsilon_free `
  -Sizes smoke `
  -Models simple_content_assignment_epsilon_consensus_free_chuffed_search.mzn `
  -Solvers Chuffed `
  -TimeLimitMs 60000 `
  -ResultsDir benchmark_results_smoke
```

Ejemplo para modelos epsilon search desde small hasta large:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_benchmarks.ps1 `
  -MiniZinc "C:\Program Files\MiniZinc\minizinc.exe" `
  -Suites epsilon_free,epsilon_directed `
  -Sizes smoke,small,medium,large `
  -Models simple_content_assignment_epsilon_consensus_free_chuffed_search.mzn,simple_content_assignment_epsilon_consensus_directed_chuffed_search.mzn `
  -Solvers "OR Tools CP-SAT" `
  -Parallel 8 `
  -TimeLimitMs 1800000 `
  -ResultsDir benchmark_results_epsilon_search_30min
```

Para guardar la matriz completa de asignaciones se debe usar:

```powershell
-FullOutput
```

Sin `-FullOutput`, los modelos optimizados suelen imprimir una salida compacta con conteos, opiniones finales y polarizacion, pero no toda la matriz agente-intervalo.

## Benchmarks archivados

Los resultados historicos estan en:

```text
benchmark_results_archive/
```

Organizacion:

```text
benchmark_results_archive/
|-- no_epsilon/
|-- epsilon_free/
|-- epsilon_directed/
|-- epsilon_mixed/
|-- failed_or_incomplete/
|-- misc/
`-- debug/
```

Cada carpeta de resultados contiene normalmente:

- `summary.csv`: tabla resumida de ejecuciones.
- `raw/`: logs completos por corrida.

Los `summary.csv` nuevos incluyen, cuando el dato lo permite:

- `min_zero_per_agent`
- `min_assign_per_agent`
- `max_assign_per_agent_effective`

Para buscar todos los resumenes:

```powershell
Get-ChildItem benchmark_results_archive -Recurse -Filter summary.csv
```

## Solvers y resultados observados

Se usaron principalmente:

- Chuffed 0.13.2
- OR Tools CP-SAT 9.15
- Gecode

Lectura experimental actual:

- Chuffed fue muy rapido en `smoke` y `small`.
- OR Tools CP-SAT fue fuerte en `medium` y `large`, especialmente con `-Parallel 8`.
- Gecode fue util en instancias muy grandes del modelo `epsilon_free` search: resolvio `xlarge` y una instancia `massive`.
- Los modelos `free` suelen ser mas faciles que los `directed`, porque no obligan a caer alrededor de un target especifico.
- Las variantes con `epsilon` escalaron mejor que las versiones sin epsilon.
- Las variantes `*_chuffed_search.mzn` fueron las mas utiles para datos pesados.

Tambien se observo consumo alto de recursos:

- OR Tools CP-SAT llego a consumir alrededor de 10 GB de RAM.
- Chuffed llego a consumir alrededor de 5 GB de RAM.
- Gecode uso bastante memoria, pero en las pruebas observadas estuvo mas cerca de 2 GB.
- OR Tools CP-SAT y Chuffed aumentaron bastante el uso de disco en algunas corridas pesadas.

Estas mediciones de memoria/disco fueron observaciones durante ejecuciones, no columnas instrumentadas automaticamente en `summary.csv`.

## Reporte

El informe principal esta en:

```text
reports/informe_modelos_consenso.tex
```

El reporte incluye:

- Portada e indice.
- Introduccion del proyecto.
- Explicacion matematica de modelos.
- Parametros, variables, arreglos auxiliares y restricciones.
- Descripcion de datos de prueba.
- Tablas de benchmarks.
- Graficas de desempeno.
- Ejemplos de asignaciones de contenido obtenidas en logs con `FullOutput`.
- Analisis preliminar de resultados.
- Conclusiones y trabajo futuro.

Nota: actualmente la portada referencia `univalle.png`. Si el archivo no esta disponible en la carpeta de compilacion, LaTeX fallara antes de compilar el informe completo.

## Contexto extendido

Para una explicacion mas detallada del proceso de desarrollo, comandos usados, decisiones sobre benchmarks y resultados historicos, revisar:

```text
Context.md
```

Ese archivo esta pensado para que otra IA o integrante del proyecto pueda retomar el trabajo sin reconstruir toda la conversacion previa.

## Recomendacion de uso

1. Probar primero `smoke` y `small` con Chuffed.
2. Probar `medium` y `large` con OR Tools CP-SAT usando `-Parallel 8`.
3. Para `xlarge` o `massive` en `epsilon_free`, probar Gecode.
4. Usar `-FullOutput` solo cuando se necesite la matriz completa de asignaciones, porque aumenta el tamano de logs y el costo de salida.
5. Revisar siempre `summary.csv` y los logs `raw/` antes de interpretar una corrida como exitosa.

