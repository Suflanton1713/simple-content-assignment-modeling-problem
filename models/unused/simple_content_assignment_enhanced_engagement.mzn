include "alldifferent_except_0.mzn";

int: A; 
int: C; 
int: Iend; 

set of int: AGENT = 1..A;
set of int: CONTENT = 1..C;
set of int: CONTENTx = CONTENT union {0}; 
set of int: TIME = 1..Iend;

% Parámetros (Aseguramos el ":" después del tipo)
array[AGENT] of 0..100: stubbornness;
array[AGENT] of 0..100: initialOpinion;
array[CONTENT] of 0..100: contentValue;

% Variables
array[AGENT, TIME] of var CONTENTx: assignment;
array[AGENT, 0..Iend] of var 0..100: opinion;

% Peso de la red social
array[AGENT] of int: snw = [100 - stubbornness[a] | a in AGENT];

% --- Restricciones ---

% 1. Condición Inicial
constraint forall(a in AGENT)(opinion[a, 0] = initialOpinion[a]);

% 2. No repetir contenido por agente
constraint forall(a in AGENT)(
    alldifferent_except_0([assignment[a, t] | t in TIME])
);

% 3. Dinámica de opinión
constraint forall(a in AGENT, t in TIME)(
    if assignment[a, t] > 0 then
        opinion[a, t] = (stubbornness[a] * opinion[a, t-1] + snw[a] * contentValue[assignment[a, t]]) div 100
    else
        opinion[a, t] = opinion[a, t-1] 
    endif
);

%-------- contenidos y engagement -----------------

%Cantidad de contenidos mínimos asignados
constraint
forall(a in AGENT)(
    sum(t in TIME)(assignment[a,t] != 0) >= 5
);

%engagement
var int: engagement =
    sum(a in AGENT, t in TIME)(
        assignment[a,t] != 0
    );

%------------------------------------------------

% 4. Objetivo
var 0..100: obj;
array[AGENT, AGENT] of var 0..100: difference;
constraint
forall(a1, a2 in AGENT)(
    difference[a1,a2] =
        abs(opinion[a1,Iend] - opinion[a2,Iend])
);

constraint
forall(a1, a2 in AGENT)(
    obj >= difference[a1,a2]
);

constraint
exists(a1, a2 in AGENT)(
    obj = difference[a1,a2]
);

solve minimize
    obj * 10000 - engagement;
    
%minimizamos el obj que es la polarización, y además el engagement nos beneficia bajando también ese valor

%solve :: int_search(
%    [assignment[a,t] | a in AGENT, t in TIME],
%    first_fail,
%    indomain_min,
%    complete
%)
%minimize obj;

% --- Bloque de Salida Robusto ---
output [
    "Polarización Final: \(obj)\n",
    "MATRIZ DE ASIGNACIÓN (ID Contenido : Valor)\n",
    "=========================================\n"
] ++ [
    if t == 1 then "\nAgente \(a) | " else "" endif ++
    if fix(assignment[a,t]) > 0 then 
        "(\(assignment[a,t])): " ++ show(contentValue[assignment[a,t]]) ++ "\t"
    else 
        "(--): N/A\t" 
    endif ++
    if t == Iend then "\n" else "" endif
| a in AGENT, t in TIME
] ++ [
    "\nOpiniones Finales: " ++ show([opinion[a, Iend] | a in AGENT])
];