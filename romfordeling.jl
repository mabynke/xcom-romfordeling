# Tips: Bruk Julia 0.7.

using Pkg
Pkg.activate(".")

# Tips: Bruk JuMP#release-0.18.
using JuMP
# Tips: Bruk Cbc#master.
using Cbc
using Gurobi

using Statistics
using Random: randsubseq

println("\n\n")

antalldeltakere = 32
rom = fill(3, cld(antalldeltakere, 3))
ønsker = fill(zero(Int), (antalldeltakere, antalldeltakere))
# kjønn[i] == k ⟺ deltaker nummer i er av kjønn k
kjønn = rand([:gutt, :jente], antalldeltakere)
# kjønnønske[i] == k representerer deltaker nummer i sitt ønske om å bo kun med eget kjønn. Verdier av k er 0 (uviktig), 1 (litt viktig) og 2 (veldig viktig)
kjønnønske = rand(0:2, antalldeltakere)
# hotellønske[i] == 1 ⟺ deltaker nummer i vil bo på hotell nummer 1 (regner også hostell som hotell her)
hotellønske = rand(0:1, antalldeltakere)
# roønske[i] == ikke bestemt enda
roønske = rand(0:2)

@info "Lager dummyønsker."
# Fylle ønskematrisen
for i in 1:1:antalldeltakere
    for j in randsubseq(1:antalldeltakere, 2//antalldeltakere)
    # for j in i+1:i+2
        i == j && continue
        ønsker[i, j] = 1
        # ønsker[j, i] = 1
    end
end

# MODELLEN
@info "Oppretter modellen."
# Oversikt over nyttige valg: https://github.com/JuliaOpt/Cbc.jl
# m = Model(solver = CbcSolver(logLevel=1, ratioGap=0.99, seconds=200))
m = Model(solver = GurobiSolver())

# HOVEDVARIABLER
@info "Definerer variabler."
# bori[d, r]: Deltaker d bor på rom r. (RomFordeling)
@variable(m, bori[1:antalldeltakere, 1:length(rom)], Bin)

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


# KRAV
@info "Definerer krav."
# Hver person bor på ett rom.
for deltakernummer in 1:antalldeltakere
    @constraint(m, sum(bori[deltakernummer, :]) == 1)
end
# Antall personer på et rom må ikke være høyere enn rommet sin kapasitet.
for romnummer in 1:length(rom)
    @constraint(m, sum(bori[:, romnummer]) <= rom[romnummer])
end
# Personer som det er viktig å bo med kun eget kjønn for, skal kun bo med eget kjønn.
for i in 1:antalldeltakere
    if kjønnønske[i] == 2
        # TODO
    end
end


# MÅLFUNKSJON
@info "Definerer målfunksjon."
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
println("Ønsker:")
display(ønsker)
print()
println("Romplassering. Rader: deltakere. Kolonner: rom.")
display(bori)
println()
println("Antall ønsker oppfylt for hver deltaker:")
aoø = getvalue(aoø)
display(aoø)

@info "Gjennomsnittlig antall ønsker oppfylt for hver deltaker:" mean(aoø)
