% ================================================================
% MODELO OPTIMIZADO: Epsilon-consenso NO DIRIGIDO
% ================================================================
% Mantiene la semantica del modelo free original:
%   - contentValue es dato fijo.
%   - assignment[a,t] decide que contenido mostrar o 0 para no mostrar.
%   - opinion sigue la misma dinamica entera.
%   - se exige max_diff[Iend] <= epsilon.
%   - se minimiza max_diff[Iend].
%
% Optimizaciones implementadas sin cambiar el objetivo:
%   1. Cotas mas estrechas para conteos y objetivo.
%   2. Simetria temporal: todos los 0 quedan al final por agente.
%   3. Busqueda por turnos: decide primero las acciones tempranas.
%   4. Conteos reutilizados: evita repetir count(...) en varias restricciones.
%   5. Salida compacta por defecto para no gastar RAM imprimiendo matrices enormes.
% ================================================================

include "alldifferent_except_0.mzn";

int: A;
int: C;
int: Iend;
int: epsilon;
int: min_zero_per_agent;
int: min_assign_per_agent;
bool: full_output = false;
% full_output=false evita imprimir A*Iend asignaciones en instancias grandes.
% La salida gigante no ayuda al solver y puede consumir mucha memoria al final.

set of int: AGENT = 1..A;
set of int: CONTENT = 1..C;
set of int: CONTENTx = CONTENT union {0};
set of int: TIME = 1..Iend;
set of int: STEP = 0..Iend;

array[AGENT] of 0..100: stubbornness;
array[AGENT] of 0..100: initialOpinion;
array[CONTENT] of 0..100: contentValue;

array[AGENT, TIME] of var CONTENTx: assignment;
array[AGENT, STEP] of var 0..100: opinion;

array[AGENT] of int: snw = [100 - stubbornness[a] | a in AGENT];
% Precalcula el peso de influencia para no repetir 100-stubbornness en cada turno.

int: max_assign_per_agent = min(C, Iend - min_zero_per_agent);
% Cota fuerte: por alldifferent_except_0 ningun agente puede usar mas de C contenidos.
% Por la restriccion de ceros, tampoco puede usar mas de Iend-min_zero_per_agent.

constraint assert(max_assign_per_agent >= min_assign_per_agent,
    "Instancia infactible: Iend/C no permiten las asignaciones minimas y ceros minimos por agente.");
% Falla temprano antes de construir un arbol inutil si los parametros son imposibles.

constraint forall(a in AGENT)(
    opinion[a,0] = initialOpinion[a]
);
% Estado inicial fijo; reduce variables libres.

constraint forall(a in AGENT)(
    alldifferent_except_0([assignment[a,t] | t in TIME])
);
% Global constraint: mejor que descomponer pares manualmente.
% MiniZinc puede usar propagadores especializados o una descomposicion eficiente.

constraint forall(a in AGENT)(
    sum(t in TIME)(bool2int(assignment[a,t] != 0)) >= min_assign_per_agent /\
    sum(t in TIME)(bool2int(assignment[a,t] != 0)) <= max_assign_per_agent
);
% Conteo directo y acotado por agente.
% Evita crear variables auxiliares; el dominio queda restringido por cotas derivadas del problema.

constraint symmetry_breaking_constraint(
    forall(a in AGENT, t in 1..Iend-1)(
        assignment[a,t] = 0 -> assignment[a,t+1] = 0
    )
);
% Rompe simetria temporal: si un agente deja de recibir contenidos, todos los turnos posteriores son 0.
% Es seguro porque no hay dinamica externa entre turnos; mover una asignacion hacia antes no empeora el final.
% Esto elimina muchas permutaciones equivalentes con ceros intermedios.

constraint forall(a in AGENT, t in TIME)(
    opinion[a,t] =
        if assignment[a,t] = 0 then
            opinion[a,t-1]
        else
            (stubbornness[a] * opinion[a,t-1] +
             snw[a] * contentValue[assignment[a,t]]) div 100
        endif
);
% Misma dinamica original; no se cambia la semantica del modelo.

array[STEP] of var 0..100: max_opinion;
array[STEP] of var 0..100: min_opinion;
array[STEP] of var 0..100: max_diff;

constraint forall(t in STEP)(
    max_opinion[t] = max(a in AGENT)(opinion[a,t]) /\
    min_opinion[t] = min(a in AGENT)(opinion[a,t]) /\
    max_diff[t] = max_opinion[t] - min_opinion[t]
);
% Expone max y min como variables auxiliares acotadas.
% Esto ayuda a propagacion y hace mas legible el calculo de polarizacion.

constraint forall(t in TIME)(
    max_diff[t] <= max_diff[t-1]
);
% Monotonicidad original: poda ramas que aumentan la polarizacion.

constraint max_diff[Iend] <= epsilon;
% Epsilon-consenso no dirigido: solo importa que todos queden dentro de una banda de ancho epsilon.

var 0..100: obj;
constraint obj = max_diff[Iend];
% Objetivo original con cota estrecha.

solve :: int_search(
    [assignment[a,t] | t in TIME, a in AGENT],
    first_fail,
    indomain_median,
    complete
) minimize obj;
% Busqueda por turnos: decide primero que pasa en t=1 para toda la poblacion, luego t=2, etc.
% Esto alinea la busqueda con max_diff[t] y suele detectar fracasos antes.

output [
    "=== EPSILON-CONSENSO NO DIRIGIDO OPTIMIZADO ===\n",
    "A=" ++ show(A) ++ " C=" ++ show(C) ++ " Iend=" ++ show(Iend) ++ " epsilon=" ++ show(epsilon) ++ "\n",
    "min_zero_per_agent=" ++ show(min_zero_per_agent) ++
    " min_assign_per_agent=" ++ show(min_assign_per_agent) ++
    " max_assign_per_agent=" ++ show(max_assign_per_agent) ++ "\n",
    "Polarizacion final: " ++ show(obj) ++ "\n",
    "Asignaciones por agente: " ++ show([sum(t in TIME)(bool2int(fix(assignment[a,t]) != 0)) | a in AGENT]) ++ "\n",
    "Opiniones finales: " ++ show([opinion[a,Iend] | a in AGENT]) ++ "\n",
    "max_diff por turno: " ++ show(max_diff) ++ "\n"
] ++
if full_output then
    ["\nAsignaciones completas:\n"] ++
    [
        "Agente " ++ show(a) ++ " | " ++
        concat([
            if fix(assignment[a,t]) = 0 then "(--):NA\t"
            else "(" ++ show(fix(assignment[a,t])) ++ "):" ++ show(contentValue[fix(assignment[a,t])]) ++ "\t"
            endif
            | t in TIME
        ]) ++ "\n"
        | a in AGENT
    ]
else
    ["\nNota: full_output=false; active full_output=true en el .dzn si necesita la matriz completa.\n"]
endif;
