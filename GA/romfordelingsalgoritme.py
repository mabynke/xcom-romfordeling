import argparse
from random import shuffle, randint, sample
from copy import deepcopy
from multiprocessing import Pool

parser = argparse.ArgumentParser(description='Romfordelingsalgorime')
parser.add_argument("-r", "--rom", help="Kommaseparert liste med størrelse på rommene")
parser.add_argument("-rf", "--romfil", help="Filsti til fil med størrelse på rommene")
parser.add_argument("-o", "--onsker", help="Kommaseparert liste med ønsker til hver person")
parser.add_argument("-of", "--onskerfil", help="Filsti til fil med ønsker til hver person")
args = parser.parse_args()


# Leser romstørrelsene
if args.rom:
    romstorrelser = [int(rom) for rom in args.rom.strip().split(",")]
    print(romstorrelser)
else:
    #TODO: Lese romstørrelser fra streng
    with open(args.romfil) as f:
        romstorrelser = [int(rom) for rom in f.readlines()]

# Leser ønskene. NB! Ønskene er 1-indekser, men behandles som 0-indeksert internt
if args.onsker:
    # Eks. `2,3;1,3;1,2` betyr at person 1 ønsker 2 og 3, person 2 ønsker 1, 3 og person 3 ønker 1, 2
    onskeliste = [person for person in args.onsker.strip().split(";")]
    for (personnummer, onsker) in enumerate(onskeliste):
        if onsker:
            onskeliste[personnummer] = [int(personnummer)-1  for personnummer in onsker.split(",")]
        else:
            onskeliste[personnummer] = []
    for (personnummer, onsker) in enumerate(onskeliste):
        print("%d: %s" % (personnummer, " ".join([str(i) for i in onsker])))

else:
    with open(args.onskerfil) as f:
        onskeliste = [[int(i)-1 for i in line.split()] for line in f.readlines()]


ANTALL_ROMFORDELINGER = 36
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
    malverdi = 0.0
    for rom in range(ANTALL_ROM):
        malverdi_for_rom = evaluer_antall_onsker_for_rom(romfordeling[1], rom, verbose=verbose)
        malverdi += malverdi_for_rom
        if verbose:
            print("Rommet har målverdi %d" % malverdi_for_rom)
    return malverdi


def evaluer_antall_onsker_for_rom(romfordeling, romindeks, verbose):
    malverdi = 0.0
    for i in range(romintervaller[romindeks][0], romintervaller[romindeks][1]+1):
        onsker_for_person_i = 0
        for j in range(romintervaller[romindeks][0], romintervaller[romindeks][1]+1):
            if j == i:
                continue
            # Sjekk om person i ønsker person j
            if romfordeling[j] in onskemengde[romfordeling[i]]:
                onsker_for_person_i += 1
        if verbose:
            print("%d: Person %d har %d/%d oppfylt" % (romindeks, romfordeling[i], onsker_for_person_i, len(onskemengde[romfordeling[i]])))
        malverdi += onsker_for_person_i # Her kan vi ha en mer sofisikert målfunksjon
    return malverdi


def muter_romfordeling(romfordeling, antall_muteringer):
    for _ in range(antall_muteringer):
        rom = sample(ROMPOPULASJON, 2)
        i = randint(romintervaller[rom[0]][0], romintervaller[rom[0]][1])
        j = randint(romintervaller[rom[1]][0], romintervaller[rom[1]][1])
        romfordeling[i], romfordeling[j] = romfordeling[j], romfordeling[i]


def main():
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
            muter_romfordeling(romfordelinger[i + HALVPARTEN_AV_ROMFORDELINGER][1], 1)

        # Skrive ut fremgang
        if _ % 100 == 0:
            print(_, end=": ")
            for i in romfordelinger[:HALVPARTEN_AV_ROMFORDELINGER]:
                print(int(i[0]), end=",")
            print()

    print('Evaluerer beste romfordeling')
    evaluer_romfordeling(romfordelinger[0], verbose=True)

    print("====================Romfordeling====================")

    beste_romfordeling = romfordelinger[0][1]
    startindeks = 0
    for rom in romstorrelser:
        rom_i = []
        for i in range(startindeks, startindeks+rom):
            rom_i.append(beste_romfordeling[i])
            print((beste_romfordeling[i]), end=" ")
        startindeks += rom
        print()

    print("Verdi: %d" % romfordelinger[0][0])
    print("Antall ønsker: " + str(sum([len(i) for i in onskeliste])))

main()