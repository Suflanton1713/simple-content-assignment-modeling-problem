% ================================================================
% MODELO C: Diseno optimo de contenidos para epsilon-consenso
% ================================================================
% Pregunta que responde:
%   Que valores de contenido debe crear el source, y a que agentes
%   debe mostrarlos, para alcanzar consenso lo mas rapido posible?
%
% Diferencia con los modelos anteriores:
%   Antes contentValue[c] era dato fijo.
%   Aqui contentValue[c] es variable de decision: el solver disena
%   los contenidos y simultaneamente decide assignment[a,t].
%
% Criterio de optimizacion lexicografico, codificado como un solo int:
%   1. minimizar cuantos turnos pasan antes de alcanzar epsilon-consenso
%   2. minimizar el numero total de asignaciones realizadas
%   3. minimizar el numero de contenidos distintos usados
%   4. minimizar la distancia final residual
%
% El modelo soporta dos modos:
%   use_target = false -> consenso no dirigido: max(opinion)-min(opinion) <= epsilon
%   use_target = true  -> consenso dirigido: todos terminan en [target-epsilon,target+epsilon]
% ================================================================

include "alldifferent_except_0.mzn";

% -------------------------
% Parametros de instancia
% -------------------------

int: A;                 % numero de agentes
int: C;                 % numero maximo de contenidos que el source puede disenar
int: Iend;              % horizonte maximo de intervenciones
int: epsilon;           % tolerancia del consenso
int: target;            % punto objetivo, usado solo si use_target = true
bool: use_target;       % false = no dirigido, true = dirigido
int: min_assign_per_agent; % minimo de contenidos por agente; normalmente 0 en este modelo
int: max_assign_per_agent; % maximo de contenidos por agente; ayuda a podar si se conoce una cota

set of int: AGENT = 1..A;
set of int: CONTENT = 1..C;
set of int: CONTENTx = CONTENT union {0};
set of int: TIME = 1..Iend;
set of int: STEP = 0..Iend;

array[AGENT] of 0..100: stubbornness;    % terquedad del agente; 100 significa que no cambia
array[AGENT] of 0..100: initialOpinion;  % opinion inicial del agente

% -------------------------
% Variables principales
% -------------------------

array[CONTENT] of var 0..100: contentValue;
% contentValue[c] es el valor ideologico/discursivo del contenido c.
% Esta es la variable nueva del problema: el solver disena el contenido.

array[AGENT, TIME] of var CONTENTx: assignment;
% assignment[a,t] = 0 significa no mostrar nada al agente a en el turno t.
% assignment[a,t] = c significa mostrar el contenido c al agente a en t.

array[AGENT, STEP] of var 0..100: opinion;
% opinion[a,t] guarda la opinion resultante despues del turno t.

array[CONTENT] of var bool: content_used;
% content_used[c] indica si el contenido c fue usado al menos una vez.

array[AGENT] of int: snw = [100 - stubbornness[a] | a in AGENT];
% snw es el peso de influencia del contenido; evita recalcular 100-stubbornness.

array[CONTENTx] of var 0..100: contentValue0 =
    array1d(CONTENTx, [0] ++ [contentValue[c] | c in CONTENT]);
% contentValue0 permite indexar incluso cuando assignment=0.
% El valor de contentValue0[0] no afecta la dinamica porque se usa solo en rama de no asignacion.

int: target_lo = max(0, target - epsilon);
int: target_hi = min(100, target + epsilon);
% Banda objetivo para el modo dirigido.

% -------------------------
% Estado inicial
% -------------------------

constraint forall(a in AGENT)(
    opinion[a, 0] = initialOpinion[a]
);
% Fija la opinion inicial; esto elimina grados de libertad innecesarios.

% -------------------------
% Diseno de contenidos y ruptura de simetrias
% -------------------------

constraint forall(c in 1..C-1)(
    contentValue[c] <= contentValue[c+1]
);
% Ordena los contenidos por valor.
% Sin esta poda, permutar dos contenidos iguales en rol produce soluciones equivalentes.

constraint forall(c in CONTENT)(
    content_used[c] <-> exists(a in AGENT, t in TIME)(assignment[a,t] = c)
);
% Conecta la decision de uso con las asignaciones reales.
% Esto permite optimizar cuantos contenidos distintos se necesitan.

constraint forall(c in 1..C-1)(
    content_used[c+1] -> content_used[c]
);
% Empaca los contenidos usados al inicio: si se usa c+1, tambien debe usarse c.
% Reduce simetria porque evita soluciones equivalentes con huecos entre contenidos.

constraint forall(c in 1..C-1)(
    content_used[c+1] -> contentValue[c] < contentValue[c+1]
);
% Si dos contenidos consecutivos se usan, sus valores deben ser distintos.
% Esto evita catalogos artificiales con varios contenidos numericamente identicos.

constraint (not content_used[1]) -> contentValue[1] = target;
% Si no se usa ningun contenido, fija el primer valor para evitar busqueda inutil.

constraint forall(c in 2..C)(
    (not content_used[c]) -> contentValue[c] = contentValue[c-1]
);
% Los contenidos no usados copian el valor anterior.
% Asi el solver no pierde tiempo asignando valores a contenidos irrelevantes.

% -------------------------
% Restricciones de asignacion
% -------------------------

constraint forall(a in AGENT)(
    alldifferent_except_0([assignment[a,t] | t in TIME])
);
% Un agente no recibe el mismo contenido dos veces.
% El 0 puede repetirse porque representa no intervenir.

array[AGENT] of var 0..Iend: assigned_by_agent;
constraint forall(a in AGENT)(
    assigned_by_agent[a] = sum(t in TIME)(bool2int(assignment[a,t] != 0))
);
% Cuenta cuantas intervenciones recibe cada agente.

constraint forall(a in AGENT)(
    assigned_by_agent[a] >= min_assign_per_agent /\
    assigned_by_agent[a] <= max_assign_per_agent
);
% Cotas por agente: son utiles para podar arboles si ya sabemos que no queremos sobreintervenir.

constraint forall(a in AGENT, t in 1..Iend-1)(
    assignment[a,t] = 0 -> assignment[a,t+1] = 0
);
% Simetria temporal fuerte: para cada agente, los contenidos se muestran al inicio.
% Como no hay dinamica externa entre turnos, esperar antes de mostrar el mismo contenido nunca ayuda
% a llegar mas rapido; esta poda elimina permutaciones equivalentes con ceros intermedios.

% -------------------------
% Dinamica de opinion
% -------------------------

constraint forall(a in AGENT, t in TIME)(
    opinion[a,t] =
        if assignment[a,t] = 0 then
            opinion[a,t-1]
        else
            (stubbornness[a] * opinion[a,t-1] +
             snw[a] * contentValue0[assignment[a,t]]) div 100
        endif
);
% Actualiza la opinion con la misma regla de tus modelos anteriores.
% La division entera mantiene el modelo finito y compatible con MiniZinc entero.

% -------------------------
% Medidas de consenso
% -------------------------

array[STEP] of var 0..100: max_diff;
constraint forall(t in STEP)(
    max_diff[t] = max(a in AGENT)(opinion[a,t]) - min(a in AGENT)(opinion[a,t])
);
% Polarizacion no dirigida en cada turno.

array[STEP] of var 0..100: target_error;
constraint forall(t in STEP)(
    target_error[t] = max(a in AGENT)(abs(opinion[a,t] - target))
);
% Distancia maxima al target; solo domina cuando use_target=true.

array[STEP] of var 0..A: outside_target;
constraint forall(t in STEP)(
    outside_target[t] = sum(a in AGENT)(
        bool2int(opinion[a,t] < target_lo \/ opinion[a,t] > target_hi)
    )
);
% Numero de agentes fuera de la banda objetivo en modo dirigido.

array[STEP] of var bool: consensus_ok;
constraint forall(t in STEP)(
    consensus_ok[t] <->
        (if use_target then outside_target[t] = 0 else max_diff[t] <= epsilon endif)
);
% Define que significa haber alcanzado consenso segun el modo elegido.

constraint consensus_ok[Iend];
% Exige que al final del horizonte el consenso se haya alcanzado.

constraint forall(t in TIME)(
    max_diff[t] <= max_diff[t-1]
);
% Poda monotona: no se permite aumentar la polarizacion global.
% Esto recorta muchas ramas que se alejan del consenso.

constraint forall(t in TIME)(
    if use_target then target_error[t] <= target_error[t-1] else true endif
);
% En modo dirigido, tampoco se permite alejarse del target.
% En modo no dirigido se desactiva para no sesgar el punto de convergencia.

constraint forall(a in AGENT, t in TIME)(
    consensus_ok[t-1] -> assignment[a,t] = 0
);
% Una vez alcanzado el consenso, ya no se muestran mas contenidos.
% Esto poda ramas equivalentes que agregan intervenciones inutiles despues del exito.

% -------------------------
% Objetivo lexicografico
% -------------------------

var 0..Iend: turns_before_consensus;
constraint turns_before_consensus = sum(t in STEP)(bool2int(not consensus_ok[t]));
% Por monotonicidad, esto equivale al primer turno en que se alcanza consenso.
% Si ya hay consenso en t=0, vale 0.

var 0..(A * Iend): total_assigned;
constraint total_assigned = sum(a in AGENT)(assigned_by_agent[a]);
% Total de intervenciones realizadas.

var 0..C: distinct_contents;
constraint distinct_contents = sum(c in CONTENT)(bool2int(content_used[c]));
% Cantidad de contenidos distintos que realmente fueron necesarios.

var 0..100: final_error;
constraint final_error = if use_target then target_error[Iend] else max_diff[Iend] endif;
% Error final que se minimiza solo despues de tiempo, asignaciones y contenidos usados.

int: W3 = 101;
int: W2 = (C + 1) * W3;
int: W1 = (A * Iend + 1) * W2;
% Pesos lexicograficos.
% W1 es mayor que cualquier combinacion posible de criterios secundarios.

var int: obj;
constraint obj =
    turns_before_consensus * W1 +
    total_assigned * W2 +
    distinct_contents * W3 +
    final_error;
% Objetivo escalar equivalente al orden lexicografico descrito arriba.

solve :: seq_search([
    int_search([assignment[a,t] | a in AGENT, t in TIME], dom_w_deg, indomain_min, complete),
    int_search([contentValue[c] | c in CONTENT], input_order, indomain_median, complete)
]) minimize obj;
% Decide primero la estructura de asignaciones y luego calibra los valores de contenido.
% Con la simetria temporal, indomain_min empuja a usar pocos contenidos y evita huecos entre turnos.

% -------------------------
% Salida
% -------------------------

output [
    "=== DISENO OPTIMO DE CONTENIDOS PARA EPSILON-CONSENSO ===\n",
    "Modo: " ++ if use_target then "DIRIGIDO" else "NO DIRIGIDO" endif ++ "\n",
    "A=" ++ show(A) ++ " C=" ++ show(C) ++ " Iend=" ++ show(Iend) ++ " epsilon=" ++ show(epsilon) ++ "\n",
    if use_target then "Target=" ++ show(target) ++ " banda=[" ++ show(target_lo) ++ "," ++ show(target_hi) ++ "]\n" else "" endif,
    "Turnos antes del consenso: " ++ show(turns_before_consensus) ++ "\n",
    "Asignaciones totales: " ++ show(total_assigned) ++ "\n",
    "Contenidos distintos usados: " ++ show(distinct_contents) ++ "\n",
    "Error final: " ++ show(final_error) ++ "\n",
    "Catalogo disenado: " ++ show(contentValue) ++ "\n",
    "Contenidos usados: " ++ show([contentValue[c] | c in CONTENT where fix(content_used[c])]) ++ "\n",
    "Opiniones finales: " ++ show([opinion[a,Iend] | a in AGENT]) ++ "\n",
    "max_diff por turno: " ++ show(max_diff) ++ "\n\n",
    "Asignaciones por agente:\n"
] ++ [
    "Agente " ++ show(a) ++ " | " ++
    concat([
        if fix(assignment[a,t]) = 0 then
            "(--):NA\t"
        else
            "(" ++ show(fix(assignment[a,t])) ++ "):" ++ show(fix(contentValue[fix(assignment[a,t])])) ++ "\t"
        endif
        | t in TIME
    ]) ++ "\n"
    | a in AGENT
];