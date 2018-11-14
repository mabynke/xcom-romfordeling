using JSON

# Bruk: argument 1: filen som skal tolkes.

const D = JSON.parse(read(ARGS[1], String)) # Dict{String,Any}

"Regner ut verdien beskrevet i README.md. d1 og d2 er deltaker-ID-er."
function f(d1, d2)
    if d1 == d2
        return 0
    end
    return a(d1, d2) + b(d1, d2) + c(d1, d2)
end

function f_uten_a(d1, d2)
    if d1 == d2
        return 0
    end
    return b(d1, d2) + c(d1, d2)
end

"Er d2 på listen over d1 sine ønsker?"
function a(d1, d2::String)
    return d2 in [string(d) for d in D[d1]["ønsker"]] ? 1 : 0
end

"Kjønn"
function b(d1, d2)
    # Ignorer dersom d2 er på listen over d1 sine ønsker.
    # Kaller a en ekstra gang, ytelse er ikke viktig her.
    # Ignorer dersom d1 og d2 er av samme kjønn.
    if a(d1, d2) == 1 || D[d1]["kjønn"] == D[d2]["kjønn"] || D[d1]["kjønnønske"] == 0
        return 0
    end

    if D[d1]["kjønnønske"] == 1
        return -1.5
    elseif D[d1]["kjønnønske"] == 2
        return -100
    end
    @assert false "Det skal ikke være mulig å komme til denne linjen"
end

function c(d1, d2)
    ro1 = D[d1]["roønske"]
    ro2 = D[d2]["roønske"]

    if a(d1, d2) == 1 || ro1 == 0 || ro2 == 0  # Bryr seg ikke
        return 0
    elseif ro1 == ro2  # De er enige
        return 0.1
    else  # De er uenige
        return -0.1
    end
end

function lagidliste()
    global D
    return keys(D)
end

lagverdimatrise(idliste) = [f(d1, d2) + f(d2, d1) for d1 in idliste, d2 in idliste]
lagnabomatrise(idliste) = [a(d1, d2) for d1 in idliste, d2 in idliste]
lagrestmatrise(idliste) = [f_uten_a(d1, d2) for d1 in idliste, d2 in idliste]

# Kopiert fra mip-fordeling.jl og tilpasset litt
function lagønskestreng(ønsker, antalldeltakere)
	return join([join([j for j in 1:antalldeltakere if ønsker[i, j] == 1], " ") for i in 1:antalldeltakere], "\n")
end


function main()
    # Til MIP:
    # Skal tilsvare f i README.md bortsett fra at denne er gjort symmetrisk slik at vi bare trenger å se på halve matrisen i optimaliseringen.
    idliste = lagidliste()
    verdimatrise = lagverdimatrise(idliste)

    # Til (nesten-)GA (OBS! Ikke symmetrisk):
    nabomatrise = lagnabomatrise(idliste)
	nabostreng = lagønskestreng(nabomatrise, length(idliste))
    restmatrise = lagrestmatrise(idliste)

	# Sjekke at det ikke har skjedd noe galt
	for i in 1:length(idliste), j in 1:length(idliste)
		if nabomatrise[i, j] == 1
			print(restmatrise[i,j])
			@assert restmatrise[i,j] == 0
		end
	end

    display(verdimatrise)
    println()

    utfilnavnstart = endswith(lowercase(ARGS[1]), ".json") ? ARGS[1][1:end-5] : ARGS[1]
    utfilnavn = utfilnavnstart * "_verdimatrise.json"
    utjson = Dict(
        "idliste" => idliste,
        "verdimatrise" => verdimatrise,
        "nabostreng" => nabostreng,
		"restmatrise" => restmatrise
    )
    open(utfilnavn, "w") do fil
        JSON.print(fil, utjson, 2)
    end
    print("Obs! Matrisen blir skrevet kolonne for kolonne i JSON-filen.")
end

main()
