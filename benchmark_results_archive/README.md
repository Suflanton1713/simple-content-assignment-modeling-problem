# Archivo de resultados de benchmarks

Esta carpeta concentra los resultados historicos de benchmarks para no dejar todas las carpetas en la raiz del proyecto.

## Organizacion

```text
benchmark_results_archive/
  no_epsilon/          Resultados de consensus_free y consensus_directed.
  epsilon_free/        Resultados especificos de epsilon_free.
  epsilon_directed/    Resultados especificos de epsilon_directed.
  epsilon_mixed/       Corridas mixtas o comparativas con varias suites/modelos.
  failed_or_incomplete/Reservado para corridas incompletas futuras.
  misc/                Resultados genericos o antiguos sin familia clara.
  debug/               Logs manuales debug_*.log.
```

## Notas

- Las variantes `propagation`, `gecode_search` y `tuned` fueron depuradas.
- Los resultados donde `Gecode` fue usado como solver sobre modelos activos `*_chuffed_search.mzn` se conservaron.
- Para analizar resultados existentes, buscar `summary.csv` de forma recursiva:

```powershell
Get-ChildItem benchmark_results_archive -Recurse -Filter summary.csv
```

- Los nuevos benchmarks pueden seguir escribiendose en la raiz con `-ResultsDir`; luego se pueden mover a esta estructura.
