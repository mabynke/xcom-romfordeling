# xcom-romfordeling
Skript for optimal fordeling av ekskursjonsdeltakere på rom

Bruker JuMP.jl og Cbc.jl, som ikke er kompatible med Julia 1.0 enda. Jeg har brukt *Julia 0.7* og spesifikke utgaver av disse pakkene som fungerer. Dette er satt opp som et Julia-miljø.

# Sette opp Julia-miljøet
Gå inn i rotmappen i terminal og start Julia 0.7. Skriv `]` for å gå inn i Pkg3-modus. Skriv dette:

```
activate .
instantiate
```

Den første kommandoen aktiverer miljøet, og den andre laster ned og installerer avhengighetene (JuMP og Cbc). Det kan ta lang tid å installere Cbc fordi den skal bygge et stort program fra kildekode.

Når du senere skal kjøre koden, pass på å ha aktivert xcom-rom-miljøet først (f.eks. i REPL i Juno).
