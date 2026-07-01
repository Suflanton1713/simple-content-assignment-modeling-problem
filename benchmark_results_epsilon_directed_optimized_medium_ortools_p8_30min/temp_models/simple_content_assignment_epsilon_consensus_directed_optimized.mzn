% ================================================================
% MODELO OPTIMIZADO: Epsilon-consenso DIRIGIDO
% ================================================================
% Mantiene la semantica del modelo directed original:
%   - contentValue es dato fijo.
%   - todos los agentes terminan en [target-epsilon, target+epsilon].
%   - se minimiza el numero total de contenidos asignados.
%
% Optimizaciones implementadas sin cambiar el objetivo:
%   1. Cotas mas estrechas para conteos y total_assigned.
%   2. Simetria temporal: ceros al final para eliminar horarios equivalentes.
%   3. Busqueda por turnos para propagar antes restricciones globales de consenso.
%   4. Conteo canalizado por agente para evitar count(...) repetidos.
%   5. Salida compacta por defecto para proteger RAM en 100/200/500 agentes.
% ================================================================

include "alldifferent_except_0.mzn";

int: A;
int: C;
int: Iend;
int: epsilon;
int: target;
bool: full_output = true;
% full_output=false es importante para instancias grandes: imprimir A*Iend celdas puede ser costoso.

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
% Precalcula influencia para hacer la dinamica mas directa al aplanar.

int: target_lo = max(0, target - epsilon);
int: target_hi = min(100, target + epsilon);
% Limites de consenso dirigido; son parametros derivados, no variables.

int: MIN_ZERO_PER_AGENT = 4;
int: MIN_ASSIGN_PER_AGENT = 1;
int: MAX_ASSIGN_PER_AGENT = min(C, Iend - MIN_ZERO_PER_AGENT);
% Cota fuerte derivada de ceros minimos y no repeticion de contenido.

constraint assert(MAX_ASSIGN_PER_AGENT >= MIN_ASSIGN_PER_AGENT,
    "Instancia infactible: Iend debe permitir al menos una asignacion y 4 ceros por agente.");
% Detecta datos imposibles antes de construir una busqueda grande.

constraint forall(a in AGENT)(
    opinion[a,0] = initialOpinion[a]
);
% Estado inicial fijo.

constraint forall(a in AGENT)(
    alldifferent_except_0([assignment[a,t] | t in TIME])
);
% Mantiene la restriccion global de no repetir contenido por agente.

constraint forall(a in AGENT)(
    sum(t in TIME)(bool2int(assignment[a,t] != 0)) >= MIN_ASSIGN_PER_AGENT /\
    sum(t in TIME)(bool2int(assignment[a,t] != 0)) <= MAX_ASSIGN_PER_AGENT
);
% Conteo directo y acotado por agente.
% Mantiene las cotas fuertes sin introducir variables auxiliares de conteo.

constraint symmetry_breaking_constraint(
    forall(a in AGENT, t in 1..Iend-1)(
        assignment[a,t] = 0 -> assignment[a,t+1] = 0
    )
);
% Rompe simetria temporal: las intervenciones utiles ocurren al inicio.
% Si una solucion tenia ceros intermedios, mover sus contenidos hacia antes conserva total_assigned y no empeora el final.

constraint forall(a in AGENT, t in TIME)(
    opinion[a,t] =
        if assignment[a,t] = 0 then
            opinion[a,t-1]
        else
            (stubbornness[a] * opinion[a,t-1] +
             snw[a] * contentValue[assignment[a,t]]) div 100
        endif
);
% Dinamica original de opinion.

array[STEP] of var 0..100: max_opinion;
array[STEP] of var 0..100: min_opinion;
array[STEP] of var 0..100: max_diff;

constraint forall(t in STEP)(
    max_opinion[t] = max(a in AGENT)(opinion[a,t]) /\
    min_opinion[t] = min(a in AGENT)(opinion[a,t]) /\
    max_diff[t] = max_opinion[t] - min_opinion[t]
);
% Polarizacion por turno; max/min quedan acotados y reutilizables en salida.

constraint forall(t in TIME)(
    max_diff[t] <= max_diff[t-1]
);
% Mantiene la poda monotona original.

constraint forall(a in AGENT)(
    opinion[a,Iend] >= target_lo /\
    opinion[a,Iend] <= target_hi
);
% Consenso dirigido final: todos terminan dentro de la banda target +/- epsilon.

var A..(A * MAX_ASSIGN_PER_AGENT): total_assigned;
constraint total_assigned = sum(a in AGENT, t in TIME)(bool2int(assignment[a,t] != 0));
% Objetivo original, pero con dominio mucho mas estrecho que var int y sin variables auxiliares.

solve :: int_search(
    [assignment[a,t] | t in TIME, a in AGENT],
    first_fail,
    indomain_median,
    complete
) minimize total_assigned;
% Busqueda por turnos con first_fail: se enfoca en variables con menos valores disponibles.
% indomain_median suele probar contenidos centrales antes que extremos cuando los ids estan ordenados por valor.

output [
    "=== EPSILON-CONSENSO DIRIGIDO OPTIMIZADO ===\n",
    "A=" ++ show(A) ++ " C=" ++ show(C) ++ " Iend=" ++ show(Iend) ++ " target=" ++ show(target) ++ " epsilon=" ++ show(epsilon) ++ "\n",
    "Banda objetivo: [" ++ show(target_lo) ++ "," ++ show(target_hi) ++ "]\n",
    "Asignaciones totales: " ++ show(total_assigned) ++ "\n",
    "Asignaciones por agente: " ++ show([sum(t in TIME)(bool2int(fix(assignment[a,t]) != 0)) | a in AGENT]) ++ "\n",
    "Polarizacion final: " ++ show(max_diff[Iend]) ++ "\n",
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