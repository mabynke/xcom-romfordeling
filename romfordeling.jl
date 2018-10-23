# Tips: Bruk Julia 0.7.

using Pkg
Pkg.activate(".")
Pkg.instantiate()

# Tips: Bruk JuMP#release-0.18.
@info "Importerer JuMP."
using JuMP
# Tips: Bruk Cbc#master.
# using Cbc
@info "Importerer Gurobi."
try
	using Gurobi
catch e
	println("Det kan se ut til at Gurobi ikke har blitt bygd skikkelig. Prøver å bygge. Dersom vi er «Unable to locate Gurobi installation», pass på at Gurobi er skikkelig installert, og at miljøvariabler er satt slik at vi kan finne Gurobi. Se Gurobis «Quick start guide».")
	if e isa ErrorException
		Pkg.build("Gurobi")
		using Gurobi
	end
end

@info "Importerer innebygde biblioteker"
using Statistics
using Random: randsubseq
using Dates: now

println("\n\n")

LAGREMODELL = false

function kjør(iterasjon)
	# Mindre rom ser ut til å gi lengre kjøretid.
	# tmpromstørrelse = 6

	# rom = fill(tmpromstørrelse, cld(antalldeltakere, tmpromstørrelse))
	kyotorom = vcat(fill(6, 6), fill(5, 5), fill(4, 11), fill(2, 4), fill(1, 1))

	rom = [i for i in 1:6 for j in 1:3+iterasjon]
	# antalldeltakere = sum(rom)
	antalldeltakere = sum(rom)

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
	    for j in randsubseq(1:antalldeltakere, 1//antalldeltakere)
	    # for j in i+1:i+2
	        i == j && continue
	        ønsker[i, j] = 1
	        ønsker[j, i] = 1
	        # ønsker[j, i] = 1
	    end
	end

	# MODELLEN
	@info "Oppretter modellen."
	# Oversikt over nyttige valg: https://github.com/JuliaOpt/Cbc.jl
	# m = Model(solver = CbcSolver(logLevel=1, ratioGap=0.99, seconds=200))
	# Oversikt over valg: http://www.gurobi.com/documentation/8.1/refman/parameters.html#sec:Parameters
	# Automatisk innstilling «tuning» anbefaler Heuristics=0, MIPFocus=1, GomoryPasses=5, Presolve=2
	# MIPGap: Stopp når den beste funnede løsningen er maks så mye dårligere enn den optimale
	# TimeLimit: Stopp etter så mange sekunder og gi den beste løsningen så langt.
	m = Model(solver = GurobiSolver(Heuristics=0, MIPFocus=1, GomoryPasses=5, Presolve=2, MIPGap=.16, TimeLimit=3600))

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
	if LAGREMODELL
		mkdir("modeller")
		writeMPS(m, "modeller/modell_" * string(now()) * "_antdelt " * string(antalldeltakere) * ".mps")
	end
	@time status = solve(m)
	# tidsbruk = getsolvetime(m)

	@info "Ferdig!" status getobjectivevalue(m) getobjectivebound(m)

	println("Målverdi: ", getobjectivevalue(m))
	bori = getvalue(bori)
	println()
	println("Ønsker:")
	display(ønsker)
	println()
	# println("Romplassering. Rader: deltakere. Kolonner: rom.")
	# display(bori)
	# println()

	deltakerepårom = [[i for i in 1:antalldeltakere if bori[i, rom] == 1] for rom in 1:length(rom)]
	println("Romplassering (hver liste er et rom, tallene er deltakere):")
	display(deltakerepårom)
	println()

	println("Antall ønsker oppfylt for hver deltaker:")
	aoø = getvalue(aoø)
	display(aoø)
	println()

	@info "Gjennomsnittlig antall ønsker oppfylt for hver deltaker:" mean(aoø)
end

function main()
	for i in 1:3
		kjør(i)
		sleep(600)
	end
end

main()
