% ================================================================
%  MODELO B: Epsilon-Consenso DIRIGIDO
% ================================================================
%  El source apunta a un consenso en torno a un valor específico.
%  Todos los agentes deben terminar en [target - epsilon, target + epsilon].
%
%  Parámetros clave:
%    target  → punto de consenso deseado (ej: 50 = centro)
%    epsilon → tolerancia alrededor del target
%
%  Ejemplo: target=50, epsilon=10
%    → todos los agentes deben terminar en [40, 60]
%
%  Objetivo: minimizar el número total de contenidos asignados
%    → encontrar la forma MÁS EFICIENTE de llevar a todos al target
%    → alternativa comentada: minimizar max_diff (más conservador)
% ================================================================

include "alldifferent_except_0.mzn";

int: A; int: C; int: Iend;
int: epsilon;  % tolerancia: banda alrededor del target
int: target;   % punto de consenso deseado (0..100)

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

% Bounds del intervalo objetivo — parámetros derivados
int: target_lo = max(0,   target - epsilon);
int: target_hi = min(100, target + epsilon);

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

% 4. Rango de asignaciones por agente
constraint forall(a in AGENT)(
    count([assignment[a, t] | t in TIME], 0) <= Iend - 1 /\
    count([assignment[a, t] | t in TIME], 0) >= 4
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

% 8. Epsilon-consenso DIRIGIDO
%    Todos los agentes deben terminar dentro del intervalo [target-ε, target+ε]
constraint forall(a in AGENT)(
    opinion[a, Iend] >= target_lo /\
    opinion[a, Iend] <= target_hi
);

% 9. Objetivo: minimizar contenido total usado (eficiencia del source)
%    → cuántos "mensajes" necesita enviar el source para lograr el consenso dirigido
%    Alternativa: minimize max_diff[Iend] (comentado abajo)
var int: total_assigned;
constraint total_assigned = sum(a in AGENT, t in TIME)(
    bool2int(assignment[a, t] != 0)
);

% Objetivo A: mínimo contenido para alcanzar consenso en [target±epsilon]
solve :: int_search(
    [assignment[a, t] | a in AGENT, t in TIME],
    dom_w_deg, indomain_median, complete
) minimize total_assigned;

% Objetivo B (alternativa): minimizar polarización final
% var 0..100: obj;
% constraint obj = max_diff[Iend];
% solve :: int_search(...) minimize obj;

output [
    "=== EPSILON-CONSENSO DIRIGIDO ===\n",
    "Target:  \(target)  |  Epsilon: \(epsilon)\n",
    "Intervalo objetivo: [\(target_lo), \(target_hi)]\n",
    "Contenidos totales asignados: \(total_assigned)\n",
    "Polarización final (max_diff): \(max_diff[Iend])\n\n"
] ++ [
    if t == 1 then "\nAgente \(a) | " else "" endif ++
    if fix(assignment[a, t]) > 0 then
        "(\(fix(assignment[a,t]))): \(contentValue[fix(assignment[a,t])])\t"
    else "(--): N/A\t" endif ++
    if t == Iend then "\n" else "" endif
    | a in AGENT, t in TIME
] ++ ["\nOpiniones Finales:  " ++ show([opinion[a, Iend] | a in AGENT])]
  ++ ["\nmax_diff por turno: " ++ show(max_diff) ++ "\n"]
  ++ ["\nVerificación por agente (dentro de [" ++ show(target_lo) ++ "," ++
      show(target_hi) ++ "]):\n"]
  ++ [ "  Agente \(a): \(opinion[a,Iend]) " ++
       if fix(opinion[a,Iend]) >= target_lo /\ fix(opinion[a,Iend]) <= target_hi
       then "✓\n" else "✗\n" endif
       | a in AGENT ];
