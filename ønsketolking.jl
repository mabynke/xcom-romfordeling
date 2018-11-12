using JSON

# Bruk: argument 1: filen som skal tolkes.

const D = JSON.parse(read(ARGS[1], String)) # Dict{String,Any}

"Regner ut verdien beskrevet i README.md. d1 og d2 er deltaker-ID-er."
function f(d1, d2)
    # @info "Regner ut f" d1 d2 a(d1, d2) b(d1, d2) c(d1, d2)

    if d1 == d2
        return 0
    end
    return a(d1, d2) + b(d1, d2) + c(d1, d2)
end

"Er d2 på listen over d1 sine ønsker?"
function a(d1, d2::String)
    return d2 in [string(d) for d in D[d1]["ønskeliste"]] ? 1 : 0
end

"Kjønn"
function b(d1, d2)
    # Ignorer dersom d2 er på listen over d1 sine ønsker.
    # Kaller a en ekstra gang, ytelse er ikke viktig her.
    # Ignorer dersom d1 og d2 er av samme kjønn.
    if a(d1, d2) == 1 || D[d1]["kjønn"] == D[d2]["kjønn"]
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
        return 1
    else  # De er uenige
        return -1
    end
end

function lagverdimatrise()
    global D

    verdimatrise = [f(d1, d2) for d1 in keys(D), d2 in keys(D)]
    return verdimatrise
end

function main()
    verdimatrise = lagverdimatrise() # Resultatet av kjøringen. Skal tilsvare f i README.md.

    display(verdimatrise)
    println()

    utfilnavnstart = endswith(lowercase(ARGS[1]), ".json") ? ARGS[1][1:end-5] : ARGS[1]
    utfilnavn = utfilnavnstart * "_ønskematrise.json"
    open(utfilnavn, "w") do fil
        JSON.print(fil, verdimatrise, 2)
    end
    print("Obs! Matrisen blir skrevet kolonne for kolonne i JSON-filen.")
end

main()
