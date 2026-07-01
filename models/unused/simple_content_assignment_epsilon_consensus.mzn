% ================================================================
%  MODELO A: Epsilon-Consenso NO DIRIGIDO
% ================================================================
%  Los agentes convergen a DONDE SEA, sin punto objetivo fijo.
%  Solo se exige que la diferencia máxima final sea <= epsilon.
%  El solver minimiza la polarización final buscando naturalmente
%  el punto de convergencia más fácil de alcanzar.
%
%  Parámetro clave: epsilon
%    → define cuán "juntos" deben estar los agentes al final
%    → epsilon=0  : consenso exacto (muy exigente)
%    → epsilon=10 : todos dentro de una banda de 10 puntos
%    → epsilon=20 : consenso más relajado
% ================================================================

include "alldifferent_except_0.mzn";

int: A; int: C; int: Iend;
int: epsilon;  % tolerancia de consenso: max_diff[Iend] <= epsilon

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

% 2. Simetría temporal: ceros al final
%constraint forall(a in AGENT, t in 1..Iend-1)(
%    assignment[a, t] = 0 -> assignment[a, t+1] = 0
%);

% 3. No repetir contenido por agente
constraint forall(a in AGENT)(
    alldifferent_except_0([assignment[a, t] | t in TIME])
);

% 4. Rango de asignaciones por agente
constraint forall(a in AGENT)(
    count([assignment[a, t] | t in TIME], 0) <= Iend - 1 /\  % cantidad de no asignamientos
    count([assignment[a, t] | t in TIME], 0) >= 7            % mínimo 3
);

% 5. Dinámica de opinión
constraint forall(a in AGENT, t in TIME)(
    opinion[a, t] = if assignment[a, t] = 0
                    then opinion[a, t-1]
                    else (stubbornness[a] * opinion[a, t-1]
                         + snw[a] * contentValue[assignment[a, t]]) div 100
                    endif
);

% 6. max_diff O(A)
array[0..Iend] of var 0..100: max_diff;

constraint forall(t in 0..Iend)(
    max_diff[t] = max(a in AGENT)(opinion[a, t])
                - min(a in AGENT)(opinion[a, t])
);

% 7. Monotonicidad
constraint forall(t in 1..Iend)(
    max_diff[t] <= max_diff[t-1]
);

% 8. Epsilon-consenso NO DIRIGIDO
%    No importa dónde converjan, solo que estén suficientemente juntos
constraint max_diff[Iend] <= epsilon;

var 0..100: obj;
constraint obj = max_diff[Iend];

solve :: int_search(
    [assignment[a, t] | a in AGENT, t in TIME],
    dom_w_deg, indomain_median, complete
) minimize obj;

output [
    "=== EPSILON-CONSENSO NO DIRIGIDO ===\n",
    "Epsilon definido: \(epsilon)\n",
    "Polarización final (max_diff): \(obj)\n",
    "Consenso alcanzado: " ++ if fix(obj) <= epsilon then "SÍ" else "NO" endif ++ "\n",
    "Punto de convergencia aprox.: " ++
        show((fix(max(a in AGENT)(opinion[a,Iend])) +
              fix(min(a in AGENT)(opinion[a,Iend]))) div 2) ++ "\n\n"
] ++ [
    if t == 1 then "\nAgente \(a) | " else "" endif ++
    if fix(assignment[a, t]) > 0 then
        "(\(fix(assignment[a,t]))): \(contentValue[fix(assignment[a,t])])\t"
    else "(--): N/A\t" endif ++
    if t == Iend then "\n" else "" endif
    | a in AGENT, t in TIME
] ++ ["\nOpiniones Finales:  " ++ show([opinion[a, Iend] | a in AGENT])]
  ++ ["\nmax_diff por turno: " ++ show(max_diff) ++ "\n"];
