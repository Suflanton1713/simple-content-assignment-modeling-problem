% ================================================================
% MODELO EXPERIMENTAL: Epsilon-consenso NO DIRIGIDO, propagacion
% ================================================================
% Basado en simple_content_assignment_epsilon_consensus_free_optimized.mzn.
% Mantiene la misma semantica y el mismo objetivo.
%
% Cambios experimentales:
%   1. assignedCount[a] canaliza el conteo de asignaciones.
%   2. contentValue0 permite indexar tambien assignment=0 sin cambiar la dinamica.
%   3. La dinamica se expresa con dos implicaciones en vez de un if.
%   4. Busqueda por tiempo con first_fail + indomain_min + restart_luby(100).
% ================================================================

include "alldifferent_except_0.mzn";

int: A;
int: C;
int: Iend;
int: epsilon;
bool: full_output = true;

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
array[CONTENTx] of 0..100: contentValue0 =
    array1d(CONTENTx, [0] ++ [contentValue[c] | c in CONTENT]);

int: MIN_ZERO_PER_AGENT = 7;
int: MIN_ASSIGN_PER_AGENT = 1;
int: MAX_ASSIGN_PER_AGENT = min(C, Iend - MIN_ZERO_PER_AGENT);

constraint assert(MAX_ASSIGN_PER_AGENT >= MIN_ASSIGN_PER_AGENT,
    "Instancia infactible: Iend debe permitir al menos una asignacion y 7 ceros por agente.");

constraint forall(a in AGENT)(
    opinion[a,0] = initialOpinion[a]
);

constraint forall(a in AGENT)(
    alldifferent_except_0([assignment[a,t] | t in TIME])
);

array[AGENT] of var MIN_ASSIGN_PER_AGENT..MAX_ASSIGN_PER_AGENT: assignedCount;
constraint forall(a in AGENT)(
    assignedCount[a] = sum(t in TIME)(bool2int(assignment[a,t] != 0))
);

constraint symmetry_breaking_constraint(
    forall(a in AGENT, t in 1..Iend-1)(
        assignment[a,t] = 0 -> assignment[a,t+1] = 0
    )
);

constraint forall(a in AGENT, t in TIME)(
    assignment[a,t] = 0 -> opinion[a,t] = opinion[a,t-1]
);

constraint forall(a in AGENT, t in TIME)(
    assignment[a,t] != 0 ->
        opinion[a,t] =
            (stubbornness[a] * opinion[a,t-1] +
             snw[a] * contentValue0[assignment[a,t]]) div 100
);

array[STEP] of var 0..100: max_opinion;
array[STEP] of var 0..100: min_opinion;
array[STEP] of var 0..100: max_diff;

constraint forall(t in STEP)(
    max_opinion[t] = max(a in AGENT)(opinion[a,t]) /\
    min_opinion[t] = min(a in AGENT)(opinion[a,t]) /\
    max_diff[t] = max_opinion[t] - min_opinion[t]
);

constraint forall(t in TIME)(
    max_diff[t] <= max_diff[t-1]
);

constraint max_diff[Iend] <= epsilon;

solve
:: restart_luby(100)
:: int_search(
    [assignment[a,t] | t in TIME, a in AGENT],
    first_fail,
    indomain_min,
    complete
)
minimize max_diff[Iend];

output [
    "=== EPSILON-CONSENSO NO DIRIGIDO CHUFFED PROPAGATION ===\n",
    "A=" ++ show(A) ++ " C=" ++ show(C) ++ " Iend=" ++ show(Iend) ++ " epsilon=" ++ show(epsilon) ++ "\n",
    "Polarizacion final: " ++ show(max_diff[Iend]) ++ "\n",
    "Asignaciones por agente: " ++ show(assignedCount) ++ "\n",
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
    ["\nNota: full_output=false; active full_output=true si necesita la matriz completa.\n"]
endif;
