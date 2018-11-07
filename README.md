# xcom-romfordeling
Verktøy for optimal fordeling av ekskursjonsdeltakere på rom.
Spesielt lagd for datateknologi på NTNU sin ekskursjon våren 2019.

## Problemet
Vi har en mengde med (ekskursjons)deltakere og en mengde med hotellrom av ulike størrelser.
Hver deltaker har oppgitt ønsker som påvirker hvilket rom de skal bli satt på.
Målet er at flest mulig ønsker blir oppfylt.

### Ønsker for hver deltaker:
- en liste med personer som deltakeren vil bo på rom med
- hvorvidt deltakeren vil bo bare med sitt eget kjønn.
  Mulige verdier:
  - 0 (ikke viktig)
  - 1 (litt viktig)
  - 2 (veldig viktig)
- hvorvidt deltakeren vil bo på et livlig eller rolig rom.
  Mulige verdier:
  - -1 (rolig)
  - 0 (ikke viktig)
  - 1 (livlig)

### Målfunksjon
Vi definerer målfunksjonen M (verdien som skal maksimeres) slik:

```
M = Summen av f[d1, d2] for alle deltakere d1 og alle deltakere d2 som bor på samme rom som d1

f[d1, d2] = a[d1, d2] + b[d1, d2] + c[d1, d2]

a[d1, d2] =
    1 dersom d1 hadde d2 på listen over ønsker
    0 ellers    

b[d1, d2] =
   -1 dersom d1 sitt ønske om kjønn er 1
      og d1 og d2 er av ulikt kjønn
 -100 dersom d1 sitt ønske om kjønn er 2
      og d1 og d2 er av ulikt kjønn
    0 ellers

c[d1, d2] =
    1 dersom d1 og d2 har samme ønske om ro
      og dette ønsket er 1 eller -1
   -1 dersom d1 og d2 har motsatte ønsker om ro (-1 og 1 eller 1 og -1)
    0 ellers
```

## MIP
Et heltallsprogram (integer program) ligger i mappen `MIP`.

Denne bruker JuMP.jl og Gurobi og Gurobi.jl.
Gurobi må du selv installere, det kan lastes ned fra deres egen nettside.
Følg dokumentasjonen der for hvordan det settes opp.
Man kan få en gratis akademisk lisens.

Det følger med et Julia-miljø i mappen `MIP` (`Project.toml` og `Manifest.toml`) slik at de riktige pakkene blir installert.
`mip-fordeling.jl` tar seg av å aktivere dette miljøet og installere pakkene.

### For å kjøre:
```bash
cd MIP
julia mip-fordeling.jl
```
