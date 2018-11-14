# Tips: Bruk Julia 0.7.

using Pkg
Pkg.activate(".")
Pkg.instantiate()

@info "Importerer JuMP."
using JuMP
@info "Importerer JSON"
using JSON
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

	# rom = [i for i in 1:2 for j in 1:1]
	rom = kyotorom
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
	# ønsker = dummyønsker(antalldeltakere)
	# ønsker = tolkønskestreng(read("GA/input/04-onsker.txt", String))
	ønsker, idliste = verdierogidlistefrajson(ARGS[1])
	@info "Hentet ID-liste og verdimatrise. OBS! Antar at matrisen er symmetrisk." ønsker idliste

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

	# startbori = naivløsning(antalldeltakere, rom)
	startboliste = [[13, 28, 85, 15, 107, 99], [10, 32, 100, 3, 21, 76], [14, 80, 23, 58, 102, 62], [70, 75, 97, 6, 77, 69], [20, 43, 101, 73, 50, 45], [38, 4, 67, 34, 61, 65], [82, 106, 44, 16, 37], [95, 19, 98, 33, 60], [72, 90, 36, 17, 47], [55, 1, 93, 7, 94], [22, 57, 41, 27, 30], [81, 86, 29, 68], [48, 78, 9, 18], [31, 96, 8, 89], [12, 92, 26, 25], [83, 52, 104, 87], [79, 66, 5, 105], [71, 2, 88, 63], [59, 40, 56, 39], [35, 91, 64, 84], [11, 54, 74, 49], [51, 46], [42, 24], [103, 53]]
	startbori = bolistetilmatrise(startboliste, 1)

	@variable(m, bori[d=1:antalldeltakere, r=1:length(rom)], Bin, start=startbori[d, r])
	# @variable(m, bori[d=1:antalldeltakere, r=1:length(rom)], Bin)

	# HJELPEVARIABLER
	# bsr[i, j, r]: Deltaker i og deltaker j Bor Sammen på Rom r.
	@variable(m, bsr[1:antalldeltakere, 1:antalldeltakere, 1:length(rom)], Bin)
	for i in 1:antalldeltakere
	    for j in 1:i-1
	        for r in 1:length(rom)
	            @constraint(m, bsr[i, j, r] <= bori[i, r])
	            @constraint(m, bsr[i, j, r] <= bori[j, r])
	            @constraint(m, bsr[i, j, r] >= bori[i, r] + bori[j,r] - 1)
	        end
	    end
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


	# MÅLFUNKSJON
	@info "Definerer målfunksjon."
	# Maksimer antall oppfylte ønsker.
	@objective(m, Max, sum(ønsker[i, j] * sum(bsr[i, j, :]) for i in 1:antalldeltakere, j in 1:i-1))

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

	# aoø = getvalue(aoø)
	skrivløsning(antalldeltakere, rom, bori, idliste)

end

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

function skrivønskestreng(ønsker, antalldeltakere)
	ønskelisterstreng = join([join([j for j in 1:antalldeltakere if ønsker[i, j] == 1], ",") for i in 1:antalldeltakere], ";")
	println(ønskelisterstreng)
end

function tolkønskestreng(ønskelistestreng, skille1=" ", skille2="\n")
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

function bolistetilmatrise(boliste, indeksering=0)
	# Antar 0-indeksert!!

	antalldeltakere = sum(length(x) for x in boliste)
	antallrom = length(boliste)
	bori = zeros(antalldeltakere, antallrom)

	for r in 1:antallrom
		for d in boliste[r]
			bori[d + (1-indeksering), r] = 1
		end
	end

	return bori
end

function tolkbolistestreng(streng)
	boliste = strengtillisteliste(streng, " ", "\n")
	return bolistetilmatrise(boliste)
end

function verdierogidlistefrajson(filsti)
	antalldeltakere = 0
	open(filsti, "r") do fil
		tolketjson = JSON.parse(fil)
		jsonarray = tolketjson["verdimatrise"]
		idliste = tolketjson["idliste"]
		antalldeltakere = length(jsonarray)
		# JSON har transponert matrisen og lagt den som en liste av lister.
		return [jsonarray[j][i] for i in 1:antalldeltakere, j in 1:antalldeltakere], idliste
	end
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
	# ønskelister = [(i, [j for j in 1:antalldeltakere if ønsker[i, j] == 1]) for i in 1:antalldeltakere]
	# println("Ønskelister (hver liste er en deltakers ønsker, tallene er andre deltakere):")
	# display(ønskelister)
	display(ønsker)
	println()
end

function skrivløsning(antalldeltakere, rom, bori, idliste)
	deltakerepårom = [[idliste[i] for i in 1:antalldeltakere if bori[i, rom] == 1] for rom in 1:length(rom)]
	deltakerepårom_indeks = [[i for i in 1:antalldeltakere if bori[i, rom] == 1] for rom in 1:length(rom)]
	println("Romplassering (hver liste er et rom, tallene er deltakere):")
	display(deltakerepårom)
	println()
	println(deltakerepårom_indeks)
	print()

	# println("Antall ønsker oppfylt for hver deltaker:")
	# display(aoø)
	# println()
	#
	# @info "Gjennomsnittlig antall ønsker oppfylt for hver deltaker:" mean(aoø)
end

function main()
	@info "Startet main, kaller kjør"
	kjør()
end

main()
