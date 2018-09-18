# Tips: Bruk Julia 0.7.

# Tips: Bruk JuMP#release-0.18.
using JuMP
# Tips: Bruk Cbc#master.
using Cbc

println("\n\n")

antalldeltakere = 6
rom = [2, 2, 3]
ønsker = fill(0, (antalldeltakere, antalldeltakere))

# Fylle ønskematrisen
ønsker[1, 2] = 1

m = Model(solver = CbcSolver())

# rf[r, d]: Deltaker d bor på rom r. (RomFordeling)
@variable(m, rf[1:length(rom), 1:antalldeltakere], Bin)
# bsr[i, j, r]: Deltaker i og deltaker j bor sammen på rom r.
@variable(m, bsr[1:antalldeltakere, 1:antalldeltakere, 1:length(rom)], Bin)
#

# Dummymålfunksjon: Plassere flest mulig personer på rom
@objective(m, Max, sum([rf[r, i] * rf[r, j] for r in 1:length(rom), i in 1:antalldeltakere, j in 1:antalldeltakere if ønsker[i,j] == 1]))

# Hver person bor på ett rom.
for deltakernummer in 1:antalldeltakere
    @constraint(m, sum(rf[:, deltakernummer]) == 1)
end
# Antall personer på et rom må ikke være høyere enn rommet sin kapasitet.
for romnummer in 1:length(rom)
    @constraint(m, sum(rf[romnummer, :]) <= rom[romnummer])
end

println(m)

status = solve(m)

println(status)

println("Målverdi: ", getobjectivevalue(m))
rf = getvalue(rf)
