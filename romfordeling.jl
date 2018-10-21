# Tips: Bruk Julia 0.7.

# Tips: Bruk JuMP#release-0.18.
using JuMP
# Tips: Bruk Cbc#master.
using Cbc

using Statistics
using Random: randsubseq

println("\n\n")

antalldeltakere = 20
rom = repeat([3], cld(antalldeltakere, 3))
ønsker = fill(zero(Int), (antalldeltakere, antalldeltakere))

# Fylle ønskematrisen
for i in 1:3:20
    # for j in randsubseq(1:antalldeltakere, 5//antalldeltakere)
    for j in i+1:i+2
        # i == j && continue
        ønsker[i, j] = 1
        # ønsker[j, i] = 1
    end
end

# ønsker[1, 2] = 1
# ønsker[1, 3] = 1
# ønsker[1, 4] = 1
# ønsker[5, 6] = 1
# ønsker[5, 7] = 1
# ønsker[5, 8] = 1
# ønsker[9, 10] = 1
# ønsker[9, 11] = 1
# ønsker[9, 12] = 1

# MODELLEN
# Oversikt over nyttige valg: https://github.com/JuliaOpt/Cbc.jl
m = Model(solver = CbcSolver(logLevel=1, ratioGap=0.99, seconds=200))

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
# bsr[i, j, r]: Deltaker i og deltaker j Bor Sammen på Rom r.
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
    # Lager en liste med en binær verdi (1 eller 0) for hvert av i sine ønsker.
    # Lagrer listen midlertidig før vi summerer og finner antall oppfylte ønsker
    # for å omgå at sum() ikke vil summere en tom liste (av typen Array{Any, 1}).
    tmp = [sum(bsr[i, j, :]) for j in 1:antalldeltakere if ønsker[i,j] == 1]
    @constraint(m, aoø[i] == sum(isempty(tmp) ? [0] : tmp))
end


# MÅLFUNKSJON
# Maksimer antall oppfylte ønsker.
@objective(m, Max, sum(aoø))

# println(m)

@info "Begynner å løse!" antalldeltakere
@time status = solve(m)
# tidsbruk = getsolvetime(m)

@info "Ferdig!" status getobjectivevalue(m) getobjectivebound(m)

println("Målverdi: ", getobjectivevalue(m))
bori = getvalue(bori)
println()
println("Romplassering. Rader: deltakere. Kolonner: rom.")
display(bori)
aoø = getvalue(aoø)
println()
println("Antall ønsker oppfylt for hver deltaker:")
display(aoø)

@info "Gjennomsnittlig antall ønsker oppfylt for hver deltaker:" mean(aoø)
