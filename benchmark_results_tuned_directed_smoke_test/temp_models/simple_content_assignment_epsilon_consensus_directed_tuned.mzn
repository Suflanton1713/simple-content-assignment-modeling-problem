% ================================================================
% MODELO TUNED: Epsilon-consenso DIRIGIDO
% ================================================================
% Variante experimental del modelo directed_optimized.
% Mantiene la esencia:
%   - misma variable assignment[a,t]
%   - misma dinamica de opinion turno a turno
%   - misma banda final [target-epsilon, target+epsilon]
%   - mismo objetivo: minimizar total_assigned
%
% Cambios para medir rendimiento:
%   1. Conteo assigned_count reutilizado.
%   2. contentValue0 permite indexar assignment=0 de forma segura.
%   3. Dinamica separada en implicaciones en vez de if.
%   4. Busqueda por agente, dom_w_deg, indomain_min.
%   5. restart_luby(100), util especialmente para Chuffed.
% ================================================================

include "alldifferent_except_0.mzn";

int: A;
int: C;
int: Iend;
int: epsilon;
int: target;
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

int: target_lo = max(0, target - epsilon);
int: target_hi = min(100, target + epsilon);

int: MIN_ZERO_PER_AGENT = 4;
int: MIN_ASSIGN_PER_AGENT = 1;
int: MAX_ASSIGN_PER_AGENT = min(C, Iend - MIN_ZERO_PER_AGENT);

constraint assert(MAX_ASSIGN_PER_AGENT >= MIN_ASSIGN_PER_AGENT,
    "Instancia infactible: Iend debe permitir al menos una asignacion y 4 ceros por agente.");

constraint forall(a in AGENT)(
    opinion[a,0] = initialOpinion[a]
);

constraint forall(a in AGENT)(
    alldifferent_except_0([assignment[a,t] | t in TIME])
);

array[AGENT] of var MIN_ASSIGN_PER_AGENT..MAX_ASSIGN_PER_AGENT: assigned_count;

constraint forall(a in AGENT)(
    assigned_count[a] = sum(t in TIME)(bool2int(assignment[a,t] != 0))
);

constraint symmetry_breaking_constraint(
    forall(a in AGENT, t in 1..Iend-1)(
        assignment[a,t] = 0 -> assignment[a,t+1] = 0
    )
);

constraint forall(a in AGENT, t in TIME)(
    assignment[a,t] = 0 ->
        opinion[a,t] = opinion[a,t-1]
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

constraint redundant_constraint(
    forall(t in TIME)(
        max_diff[t] <= max_diff[t-1]
    )
);

constraint forall(a in AGENT)(
    opinion[a,Iend] >= target_lo /\
    opinion[a,Iend] <= target_hi
);

var A..(A * MAX_ASSIGN_PER_AGENT): total_assigned;
constraint total_assigned = sum(a in AGENT)(assigned_count[a]);

solve
:: restart_luby(100)
:: int_search(
    [assignment[a,t] | a in AGENT, t in TIME],
    dom_w_deg,
    indomain_min,
    complete
)
minimize total_assigned;

output [
    "=== EPSILON-CONSENSO DIRIGIDO TUNED ===\n",
    "A=" ++ show(A) ++ " C=" ++ show(C) ++ " Iend=" ++ show(Iend) ++ " target=" ++ show(target) ++ " epsilon=" ++ show(epsilon) ++ "\n",
    "Banda objetivo: [" ++ show(target_lo) ++ "," ++ show(target_hi) ++ "]\n",
    "Asignaciones totales: " ++ show(total_assigned) ++ "\n",
    "Asignaciones por agente: " ++ show(assigned_count) ++ "\n",
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
            else "(" ++ show(fix(assignment[a,t])) ++ "):" ++ show(contentValue0[fix(assignment[a,t])]) ++ "\t"
            endif
            | t in TIME
        ]) ++ "\n"
        | a in AGENT
    ]
else
    ["\nNota: full_output=false; active full_output=true si necesita la matriz completa.\n"]
endif;
