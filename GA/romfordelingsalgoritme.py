import argparse
import json
from random import shuffle, randint, random, sample
from copy import deepcopy
from multiprocessing import Pool

parser = argparse.ArgumentParser(description='Romfordelingsalgorime')
parser.add_argument("-r", "--rom", help="Kommaseparert liste med størrelse på rommene")
parser.add_argument("-rf", "--romfil", help="Filsti til fil med størrelse på rommene")
parser.add_argument("-o", "--onsker", help="Kommaseparert liste med ønsker til hver person")
parser.add_argument("-of", "--onskerfil", help="Filsti til fil med ønsker til hver person")
parser.add_argument("-jof", "--jsononskerfil", help="Filsti til JSON-fil med ønsker til hver person")
parser.add_argument("-v", "--verbose", nargs="?", default="10", help="0: Skriv kun én oppsummerende linje. 10: Skriv alt (standard).")
args = parser.parse_args()


# Leser romstørrelsene
if args.rom:
    romstorrelser = [int(rom) for rom in args.rom.strip().split(",")]
    print(romstorrelser)
else:
    with open(args.romfil) as f:
        romstorrelser = [int(rom) for rom in f.readlines()]

# Leser ønskene. NB! Ønskene er 1-indekser, men behandles som 0-indeksert internt
if args.onsker:
    # Eks. `2,3;1,3;1,2` betyr at person 1 ønsker 2 og 3, person 2 ønsker 1, 3 og person 3 ønker 1, 2
    onskeliste = [[int(p) for p in person.split(',')] if person else [] for person in args.onsker.strip().split(";")]
elif args.onskerfil:
    with open(args.onskerfil) as f:
        onskeliste = [[int(i)-1 for i in line.split()] for line in f.readlines()]
else:
    with open(args.jsononskerfil) as f:
        nabostreng = json.loads(f.read())["nabostreng"]
        onskeliste = [[int(i)-1 for i in line.split()] for line in nabostreng.split("\n")]

print("Laster restverdimatrisen (verdiene som gjelder ønsker om kjønn og ro) ...")
with open(args.jsononskerfil) as f:
    # Merk at denne matrisen er lagret «kolonne først»
    verdijson = json.loads(f.read())
    restverdimatrise = verdijson["restmatrise"]
    idliste = verdijson["idliste"]


for (personnummer, onsker) in enumerate(onskeliste):
    if args.verbose == "10":
        print("%d: %s" % (personnummer, " ".join([str(i) for i in onsker])))


ANTALL_ROMFORDELINGER = 256
HALVPARTEN_AV_ROMFORDELINGER = ANTALL_ROMFORDELINGER // 2
ANTALL_PERSONER = len(onskeliste)


# Lager en global variabel for ønskene hvor oppslag tar lineær tid
onskemengde = dict()
for (personnummer, onsker) in enumerate(onskeliste):
    onskemengde[personnummer] = set(onsker)

ANTALL_ROM = len(romstorrelser)


def lag_liste_med_romintervaller():
    romintervaller = []
    venstre_romindeks = 0
    for rom in romstorrelser:
        romintervaller.append((venstre_romindeks, venstre_romindeks + rom - 1))
        venstre_romindeks += rom
    return romintervaller

romintervaller = lag_liste_med_romintervaller()

def lag_indeks_til_rom_liste():
    romindeks_til_rom = []
    rom = 0
    for romstorrelse in romstorrelser:
        for _ in range(romstorrelse):
            romindeks_til_rom.append(rom)
        rom += 1
    return romindeks_til_rom


romindeks_til_rom = lag_indeks_til_rom_liste()
ROMPOPULASJON = list(range(ANTALL_ROM))


def print_nabomatrise_fra_onskeliste():
    for ol in onskeliste:
        print(" ".join(["1" if i+1 in ol else "0" for i in range(len(onskeliste))]))


def evaluer_romfordeling(romfordeling, verbose=False):
    # romfordeling er en liste [v, l] der v er verdien så langt og l er en liste med den faktiske plasseringen.
    malverdi = 0.0
    for rom in range(ANTALL_ROM):
        malverdi_for_rom = evaluer_antall_onsker_for_rom(romfordeling[1], rom, verbose=verbose)
        malverdi += malverdi_for_rom
        if verbose:
            print("Rommet har målverdi %.1f" % malverdi_for_rom)
    return malverdi


def evaluer_antall_onsker_for_rom(romfordeling, romindeks, verbose):
    malverdi = 0.0

    # For hver person på rommet
    for i in range(romintervaller[romindeks][0], romintervaller[romindeks][1]+1):
        antall_romkamerater_pa_onskelisten = 0
        verdi_for_person_i = 0

        # For hver romkamerat
        for j in range(romintervaller[romindeks][0], romintervaller[romindeks][1]+1):
            if j == i:
                continue

            restverdi = restverdimatrise[romfordeling[j]][romfordeling[i]]   # Merk den uvante rekkefølgen på indeksene.

            # Sjekk om person i ønsker person j
            if romfordeling[j] in onskemengde[romfordeling[i]]:
                antall_romkamerater_pa_onskelisten += 1
                if restverdi != 0:
                    abcd = 1234
                assert(restverdi == 0)

            # Regne inn verdi fra ønsker om kjønn og ro.
            # if verbose:
            #     print("%d: Person %d har restverdi %.1f for person %d." % (romindeks, romfordeling[i], restverdimatrise[j][i], romfordeling[j]))
            verdi_for_person_i += restverdi

        verdi_for_person_i += antall_onsker_til_verdi(antall_romkamerater_pa_onskelisten)  # Trenger ikke å være lineært

        if verbose:
            print("%d: Person «%s» har %d/%d oppfylt og har målverdi %.1f" % (romindeks,
                                                                            idliste[romfordeling[i]],
                                                                            antall_romkamerater_pa_onskelisten,
                                                                            len(onskemengde[romfordeling[i]]),
                                                                            verdi_for_person_i))
            # print("%d: Verdi for person %d: %.1f" % (romindeks, romfordeling[i], verdi_for_person_i))
        malverdi += verdi_for_person_i
    return malverdi

def antall_onsker_til_verdi(antall):
    # Tar inn antall romkamerater en person har ønsket seg, og regner ut hvilken verdi dette gir personen
    return antall ** 0.5

def _muter_par(romfordeling):
    rom = sample(ROMPOPULASJON, 2)
    i = randint(romintervaller[rom[0]][0], romintervaller[rom[0]][1])
    j = randint(romintervaller[rom[1]][0], romintervaller[rom[1]][1])
    romfordeling[i], romfordeling[j] = romfordeling[j], romfordeling[i]

def muter_romfordeling(romfordeling, antall_muteringer):
    for _ in range(antall_muteringer):
        _muter_par(romfordeling)

def muter_romfordeling_exp(romfordeling, p):
    # p er sannsynligheten for å gjøre enda en mutering.
    assert(0 <= p < 1)
    while True:
        _muter_par(romfordeling)
        if p < random():
            break


def lag_romliste_fra_romfordeling(romfordeling, indeksering):
    # Lage en liste over rom der hvert rom er en liste over personene på rommet.
    romliste = []

    startindeks = 0
    for rom in romstorrelser:
        rom_i = []
        for i in range(startindeks, startindeks + rom):
            rom_i.append(romfordeling[i] + indeksering)
            # if args.verbose == "10":
            #     print((idliste[romfordeling[i]]), end=", ")
        romliste.append(rom_i)
        startindeks += rom
        # if args.verbose == "10":
        #     print()

    return romliste


def kjoring(P):
    # Begynner med `ANTALL_ROMFORDELINGER` tilfeldigfordelte romfordelinger
    romfordelinger = []
    for i in range(ANTALL_ROMFORDELINGER):
        l = list(range(ANTALL_PERSONER))
        shuffle(l)
        romfordelinger.append([0,l])

    ANTALL_SIMULERINGER = 100000

    p = Pool(12)    # Bør ikke hardkodes

    antall_ganger_samme_maksverdi = 0
    gammel_maksverdi = -10000

    # Denne løkken er hver runde av en form for genetisk algoritme
    for _ in range(ANTALL_SIMULERINGER):

        # Regner ut målverdier. Dette er den mest tidkrevende delen
        malverdier = p.map(evaluer_romfordeling, romfordelinger)
        for i in range(len(malverdier)):
            romfordelinger[i][0] = malverdier[i]

        # Mutere de romfordelingene som ikke er gode nok
        romfordelinger.sort(reverse=True)
        if romfordelinger[0][0] > gammel_maksverdi:
            gammel_maksverdi = romfordelinger[0][0]
            antall_ganger_samme_maksverdi = 0
        else:
            antall_ganger_samme_maksverdi += 1
            if antall_ganger_samme_maksverdi > 3000:
                break
        for i in range(HALVPARTEN_AV_ROMFORDELINGER):
            romfordelinger[i+HALVPARTEN_AV_ROMFORDELINGER] = deepcopy(romfordelinger[i])
            muter_romfordeling_exp(romfordelinger[i + HALVPARTEN_AV_ROMFORDELINGER][1], P)
            #muter_romfordeling(romfordelinger[i + HALVPARTEN_AV_ROMFORDELINGER][1], 1)

        # Skrive ut fremgang
        if args.verbose == "10":
            if _ % 100 == 0:
                print(_, end=": ")
                for i in romfordelinger[:HALVPARTEN_AV_ROMFORDELINGER]:
                    print(int(i[0]), end=",")
                print()

    if args.verbose == "10":
        print('Evaluerer beste romfordeling')
    evaluer_romfordeling(romfordelinger[0], verbose=args.verbose == "10")

    if args.verbose == "10":
        print("====================Romfordeling====================")

    beste_romfordeling = romfordelinger[0][1]
    beste_romfordeling_liste = lag_romliste_fra_romfordeling(beste_romfordeling, indeksering=1)

    print(beste_romfordeling_liste)
    print([[idliste[indeks - 1] for indeks in rom] for rom in beste_romfordeling_liste])


    antall_onsker = sum([len(i) for i in onskeliste])
    if args.verbose == "10":
        print("Verdi: %.1f" % romfordelinger[0][0])
        print("Antall ønsker: " + str(antall_onsker))
    else:
        print("{1}\t{0}".format(romfordelinger[0][0], P))


def main():
    if True:
        kjoring(0.75)
    else:
        for _ in range(10000):
            P = random()
            if P == 1:
                continue
            kjoring(random())

main()
