include "alldifferent_except_0.mzn";

int: A; int: C; int: Iend;

set of int: AGENT    = 1..A;
set of int: CONTENT  = 1..C;
set of int: CONTENTx = CONTENT union {0};
set of int: TIME     = 1..Iend;

array[AGENT]   of 0..100: stubbornness;
array[AGENT]   of 0..100: initialOpinion;
array[CONTENT] of 0..100: contentValue;

array[AGENT, TIME]    of var CONTENTx: assignment;
array[AGENT, 0..Iend] of var 0..100:  opinion;

array[AGENT] of int: snw = [100 - stubbornness[a] | a in AGENT];

% 1. Condición inicial
constraint forall(a in AGENT)(
    opinion[a, 0] = initialOpinion[a]
);

% 2. No repetir contenido por agente
constraint forall(a in AGENT)(
    alldifferent_except_0([assignment[a, t] | t in TIME])
);

% 3. Rango de asignaciones por agente
constraint forall(a in AGENT)(
    count([assignment[a, t] | t in TIME], 0) <= Iend - 1
);
constraint forall(a in AGENT)(
    count([assignment[a, t] | t in TIME], 0) >= 3
);

% 4. Dinámica de opinión
constraint forall(a in AGENT, t in TIME)(
    opinion[a, t] = if assignment[a, t] = 0
                    then opinion[a, t-1]
                    else (stubbornness[a] * opinion[a, t-1]
                         + snw[a] * contentValue[assignment[a, t]]) div 100
                    endif
);

% 5. max_diff con max-min — O(A)
array[0..Iend] of var 0..100: max_diff;

constraint forall(t in 0..Iend)(
    max_diff[t] = max(a in AGENT)(opinion[a, t])
                - min(a in AGENT)(opinion[a, t])
);

% 6. Monotonicidad
constraint forall(t in 1..Iend)(
    max_diff[t] <= max_diff[t-1]
);

% 7. Objetivo lexicográfico: primero polarización, luego asignaciones
%
%    total_assigned ∈ [0 .. A×Iend]
%    max_diff[Iend] ∈ [0 .. 100]
%    factor = A×Iend + 1
%
%    Cualquier mejora de 1 en polarización supera ahorrar
%    todas las asignaciones posibles → polarización siempre domina

var int: total_assigned;
constraint total_assigned =
    sum(a in AGENT)(Iend - count([assignment[a, t] | t in TIME], 0));

var int: obj;
constraint obj = max_diff[Iend] * (A * Iend + 1) + total_assigned;

solve :: int_search(
    [assignment[a, t] | a in AGENT, t in TIME],
    dom_w_deg,
    indomain_median,
    complete
) minimize obj;

output [
    if t == 1 then "\nAgente \(a) | " else "" endif ++
    if fix(assignment[a, t]) > 0 then
        "(\(fix(assignment[a,t]))): \(contentValue[fix(assignment[a,t])])\t"
    else "(--): N/A\t" endif ++
    if t == Iend then "\n" else "" endif
    | a in AGENT, t in TIME
] ++ ["\nOpiniones Finales:    " ++ show([opinion[a, Iend] | a in AGENT])]
  ++ ["\nmax_diff por turno:   " ++ show(max_diff)]
  ++ ["\nPolarización final:   " ++ show(max_diff[Iend])]
  ++ ["\nAsignaciones totales: " ++ show(total_assigned)]
  ++ ["\nObj lexicográfico:    " ++ show(obj) ++ "\n"];
