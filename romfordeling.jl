# Tips: Bruk Julia 0.7.

# Tips: Bruk JuMP#release-0.18.
using JuMP
# Tips: Bruk Cbc#master.
using Cbc

println("\n\n")

antalldeltakere = 6
rom = [2, 2, 3, 5]
ønsker = fill(zero(Int), (antalldeltakere, antalldeltakere))

# Fylle ønskematrisen
ønsker[1, 2] = 1
ønsker[1, 3] = 1
ønsker[1, 4] = 1
ønsker[1, 5] = 1
ønsker[1, 6] = 1

# MODELLEN
m = Model(solver = CbcSolver())

# HOVEDVARIABLER
# bori[d, r]: Deltaker d bor på rom r. (RomFordeling)
@variable(m, bori[1:antalldeltakere, 1:length(rom)], Bin)

# KRAV
# Hver person bor på ett rom.
for deltakernummer in 1:antalldeltakere
    @constraint(m, sum(bori[deltakernummer, :]) == 1)
end
# Antall personer på et rom må ikke være høyere enn rommet sin kapasitet.
for romnummer in 1:length(rom)
    @constraint(m, sum(bori[:, romnummer]) <= rom[romnummer])
end

# HJELPEVARIABLER
# bsr[i, j, r]: Deltaker i og deltaker j bor sammen på rom r.
@variable(m, bsr[1:antalldeltakere, 1:antalldeltakere, 1:length(rom)], Bin)
for i in 1:antalldeltakere
    for j in 1:antalldeltakere
        for r in 1:length(rom)
            @constraint(m, bsr[i, j, r] <= bori[i, r])
            @constraint(m, bsr[i, j, r] <= bori[j, r])
            @constraint(m, bsr[i, j, r] >= bori[i, r] + bori[j,r] - 1)
        end
    end
end

# aoø[i]: Antall Oppfylte Ønsker for deltaker nr. i.
@variable(m, aoø[1:antalldeltakere], Int)
for i in 1:antalldeltakere
    @info "Punkt 1"
    filter = []
    @info "Punkt 2"
    for j in 1:antalldeltakere
        @info "Punkt 3"
        if ønsker[i,j] == 1
            @info "Punkt 4"
            push!(filter, j)
        end
    end
    @info "Punkt 5" filter
    @constraint(m, aoø[i] == sum([sum(bsr[i, k, :]) for k in filter]))
    # @constraint(m, aoø[i] == sum([sum(bsr[i, j, :]) for j in 1:antalldeltakere if ønsker[i,j] == 1])) # Fungerer ikke!
end


# MÅLFUNKSJON
# Dummymålfunksjon: Plassere flest mulig personer på rom
@objective(m, Max, sum([sum(bsr[i, j, :]) for i in 1:antalldeltakere, j in 1:antalldeltakere if ønsker[i,j] == 1]))

# println(m)

status = solve(m)

println(status)

println("Målverdi: ", getobjectivevalue(m))
bori = getvalue(bori)
display(bori)
