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

function naivløsning(antalldeltakere, rom)
	bori = zeros(antalldeltakere, length(rom))

	deltakernr = 1
	for romnr in 1:length(rom)
		for i in 1:rom[romnr]
			bori[deltakernr, romnr] = 1
			deltakernr += 1
			if deltakernr > antalldeltakere
				break
			end
		end
		if deltakernr > antalldeltakere
			break
		end
	end

	return bori
end

function kjør()
	@info "Starter kjør()."
	# Mindre rom ser ut til å gi lengre kjøretid.
	# tmpromstørrelse = 6

	# rom = fill(tmpromstørrelse, cld(antalldeltakere, tmpromstørrelse))
	tokyodyrrom = vcat(fill(2, 34), fill(3, 1))
	tokyobilligrom = vcat(fill(6, 7), fill(4, 2))
	kyotorom = vcat(fill(6, 6), fill(5, 5), fill(4, 10), fill(2, 3))
	seoulrom_alt1 = vcat(fill(3, 4), fill(2, 17))
	seoulrom_alt2 = vcat(fill(3, 2), fill(2, 20))
	# kyotoantalldeltakere = 107

	# rom = [i for i in 2:4 for j in 1:1]
	rom = tokyobilligrom
	# antalldeltakere = kyotoantalldeltakere
	antalldeltakere = sum(rom)


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
	ønsker = dummyønsker(antalldeltakere)
	# ønsker = tolkønskestreng("17;5;47,52,58,96;33,59;2;;;10;84;8,52;71,91;47,51,67;74;36,77,107;;44,65,76;1,77,93,105;19,25,44,88;18,25,107;47,66,79,84,89;72;25,103;33,57,82,85;;18,19,22;42,82;49,99,107;68,85;;55,68,72,102;101;41;4,23,34;33,57,58;80;14;;49;72,97;56,59,71,100;32;26;48,53,54,87;16,18,104;;52,66,71;3,12,20,65;43,64;27,38,93,96;;12;3,10,46,76;43;43,94;30,84;40;23,34;3,34;4,40,79,96;;;81;;48;16,47;20,46;12;28,30,96;;;11,40,46;21,30,39;91;13;85;16,52,89;14,17;;20,59,91,102;35;62;23,26;99;9,20,55;23,28,75,87,98;;43,85;18;20,76;;11,73,79,94;;17,49,104;54,91;;3,49,59,68;39;85;27,83;40;31;30,79;22;44,93;17;;14,19,27")

	# MODELLEN
	@info "Oppretter modellen."
	# Oversikt over nyttige valg: https://github.com/JuliaOpt/Cbc.jl
	# m = Model(solver = CbcSolver(logLevel=1, ratioGap=0.99, seconds=200))

	# Oversikt over valg: http://www.gurobi.com/documentation/8.1/refman/parameters.html#sec:Parameters
	# Automatisk innstilling («tuning») anbefaler Heuristics=0, MIPFocus=1, GomoryPasses=5, Presolve=2
	# MIPGap: Stopp når den beste funnede løsningen er maks så mye dårligere enn den optimale
	# TimeLimit: Stopp etter så mange sekunder og gi den beste løsningen så langt.
	m = Model(solver = GurobiSolver(Heuristics=0, MIPFocus=1, GomoryPasses=5, Presolve=2, TimeLimit=60*60))

	# HOVEDVARIABLER
	@info "Definerer variabler."

	# bori[d, r]: Deltaker d bor på rom r. (RomFordeling)

	startbori = naivløsning(antalldeltakere, rom)

# 	startbori = tolkbolistestreng(
# "101 95 78 67 58 29
# 105 81 41 25 4 1
# 57 56 33 32 22 3
# 98 92 82 48 37 26
# 99 94 79 55 39 34
# 102 87 24 21 18 17
# 100 91 30 9 7
# 86 63 52 47 42
# 88 75 65 51 45
# 93 89 73 53 12
# 66 50 46 11 2
# 103 64 43 15
# 85 77 40 31
# 97 27 74 84
# 60 23 68 62
# 59 13 35 106
# 76 104 16 0
# 20 96 38 71
# 54 8 83 19
# 70 10 72 90
# 6 69 36 5
# 80 61
# 49 28
# 44 14")
	@variable(m, bori[d=1:antalldeltakere, r=1:length(rom)], Bin, start=startbori[d, r])

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
	skrivønskestreng(ønsker, antalldeltakere)

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

	skrivproblem(antalldeltakere, ønsker)

	aoø = getvalue(aoø)
	skrivløsning(antalldeltakere, rom, bori, aoø)

end

function skrivønskestreng(ønsker, antalldeltakere)
	ønskelisterstreng = join([join([j for j in 1:antalldeltakere if ønsker[i, j] == 1], ",") for i in 1:antalldeltakere], ";")
	println(ønskelisterstreng)
end

function tolkønskestreng(ønskelistestreng, skille1=",", skille2=";")
	ønskelister = strengtillisteliste(ønskelistestreng, skille1, skille2)
	antalldeltakere = length(ønskelister)
	ønsker = zeros(Int, antalldeltakere, antalldeltakere)

	for d1 in 1:antalldeltakere
		for d2 in ønskelister[d1]
			ønsker[d1, d2] = 1
		end
	end
	return ønsker
end

function strengtillisteliste(streng, skille1=" ", skille2="\n")
	indrelistestrenger = split(streng, skille2)
	indrelistestrenger = strip.(indrelistestrenger)
	ytreliste = [split(x, skille1) for x in indrelistestrenger]

	listeliste = []
	for liste in ytreliste
		if liste == [""]
			push!(listeliste, [])
		else
			intliste = [parse(Int, num) for num in liste]
			push!(listeliste, intliste)
		end
	end
	return listeliste
end

function bolistetilmatrise(boliste)
	# Antar 0-indeksert!!

	antalldeltakere = sum(length(x) for x in boliste)
	antallrom = length(boliste)
	bori = zeros(antalldeltakere, antallrom)

	for r in 1:antallrom
		for d in boliste[r]
			bori[d+1, r] = 1
		end
	end

	return bori
end

function tolkbolistestreng(streng)
	boliste = strengtillisteliste(streng, " ", "\n")
	return bolistetilmatrise(boliste)
end

function dummyønsker(antalldeltakere)
	ønsker = fill(zero(Int), (antalldeltakere, antalldeltakere))

	for i in 1:1:antalldeltakere
		for j in randsubseq(1:antalldeltakere, 1//antalldeltakere)
			i == j && continue
			ønsker[i, j] = 1
			ønsker[j, i] = 1
		end
	end
	return ønsker
end

function skrivproblem(antalldeltakere, ønsker)
	println("Ønsker:")
	ønskelister = [(i, [j for j in 1:antalldeltakere if ønsker[i, j] == 1]) for i in 1:antalldeltakere]
	println("Ønskelister (hver liste er en deltakers ønsker, tallene er andre deltakere):")
	display(ønskelister)
	println()
end

function skrivløsning(antalldeltakere, rom, bori, aoø)
	deltakerepårom = [[i for i in 1:antalldeltakere if bori[i, rom] == 1] for rom in 1:length(rom)]
	println("Romplassering (hver liste er et rom, tallene er deltakere):")
	display(deltakerepårom)
	println()

	println("Antall ønsker oppfylt for hver deltaker:")
	display(aoø)
	println()

	@info "Gjennomsnittlig antall ønsker oppfylt for hver deltaker:" mean(aoø)
end

function main()
	kjør()
end

main()
