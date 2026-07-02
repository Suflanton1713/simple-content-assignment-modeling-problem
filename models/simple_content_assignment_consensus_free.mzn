include "alldifferent_except_0.mzn";

int: A; int: C; int: Iend;
int: min_zero_per_agent;
int: min_assign_per_agent;

set of int: AGENT    = 1..A;
set of int: CONTENT  = 1..C;
set of int: CONTENTx = CONTENT union {0};
set of int: TIME     = 1..Iend;

array[AGENT]   of 0..100: stubbornness;
array[AGENT]   of 0..100: initialOpinion;
array[CONTENT] of 0..100: contentValue;

array[AGENT, TIME]    of var CONTENTx: assignment;
array[AGENT, 0..Iend] of var 0..100:  opinion;

array[AGENT] of int: snw      = [100 - stubbornness[a] | a in AGENT];
int: max_assign_per_agent = min(C, Iend - min_zero_per_agent);

constraint assert(max_assign_per_agent >= min_assign_per_agent,
    "Instancia infactible: Iend/C no permiten las asignaciones minimas y ceros minimos por agente.");


% 1. Condición inicial
constraint forall(a in AGENT)(
    opinion[a, 0] = initialOpinion[a]
);

% 2. Simetría temporal: ceros al final
constraint forall(a in AGENT, t in 1..Iend-1)(
    assignment[a, t] = 0 -> assignment[a, t+1] = 0
);

% 3. No repetir contenido por agente
constraint forall(a in AGENT)(
    alldifferent_except_0([assignment[a, t] | t in TIME])
);

% 4. Mínimo de asignaciones por agente — con count, sin booleanos
constraint forall(a in AGENT)(
    sum(t in TIME)(bool2int(assignment[a, t] != 0)) >= min_assign_per_agent /\
    sum(t in TIME)(bool2int(assignment[a, t] != 0)) <= max_assign_per_agent
);

% 5. Dinámica directa — sin effective_cv
constraint forall(a in AGENT, t in TIME)(
    opinion[a, t] = if assignment[a, t] = 0
                    then opinion[a, t-1]
                    else (stubbornness[a] * opinion[a, t-1]
                         + snw[a] * contentValue[assignment[a, t]]) div 100
                    endif
);


% 7. max_diff con max-min — O(A) no O(A²)
array[0..Iend] of var 0..100: max_diff;

constraint forall(t in 0..Iend)(
    max_diff[t] = max(a in AGENT)(opinion[a, t])
                - min(a in AGENT)(opinion[a, t])
);

% 8. Monotonicidad
constraint forall(t in 1..Iend)(
    max_diff[t] <= max_diff[t-1]
);

var 0..100: obj;
constraint obj = max_diff[Iend];



% 9. dom_w_deg para minimización
solve :: int_search(
    [assignment[a, t] | a in AGENT, t in TIME],
    dom_w_deg,
    indomain_median,
    complete
) minimize obj;

output [
    "=== CONSENSUS FREE ===\n",
    "min_zero_per_agent=" ++ show(min_zero_per_agent) ++
    " min_assign_per_agent=" ++ show(min_assign_per_agent) ++
    " max_assign_per_agent=" ++ show(max_assign_per_agent) ++ "\n"
] ++ [
    if t == 1 then "\nAgente \(a) | " else "" endif ++
    if fix(assignment[a, t]) > 0 then
        "(\(fix(assignment[a,t]))): \(contentValue[fix(assignment[a,t])])\t"
    else "(--): N/A\t" endif ++
    if t == Iend then "\n" else "" endif
    | a in AGENT, t in TIME
] ++ ["\nOpiniones Finales: " ++ show([opinion[a, Iend] | a in AGENT])]
  ++ ["\nDiferencia de opiniones máximas Final: \(obj)\n"];
