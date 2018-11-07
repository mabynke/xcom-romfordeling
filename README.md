# xcom-romfordeling
Verktøy for optimal fordeling av ekskursjonsdeltakere på rom.
Spesielt lagd for datateknologi på NTNU sin ekskursjon våren 2019.

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
