class_name CatalogoDisco
extends RefCounted

# IL CATALOGO DEL DISCO (18/10/2026): cosa PUO' esserci sul disco di una partita.
# Solo dati. Chi li usa e' OSContent._riempi_disco, che a ogni partita pesca da qui -- col
# seme del run, quindi stessa partita = stesso disco -- e mette file e cartelle a caso.
# LA STORIA dietro i testi e' in docs/GDD.md §2b: il PC era del PADRE di Noah, che la
# maledizione possedette fino a fargli uccidere la moglie. I file NORMALI sono la vita
# della sua famiglia; i file del PADRE la scivolata; gli HORROR la voce del ragazzo da cui
# tutto e' partito e della maledizione che parla a chi e' al PC adesso. Quello che nel GDD
# e' ancora APERTO (i nomi, come passa la maledizione) nei testi non si inventa.
# Lo scheletro (unita', C:\WHALE, Programmi, Documenti\Immagini, TEMP, Cestino) NON sta
# qui: e' fisso, in OSContent._disco_c, perche' e' quello che ogni PC del '98 aveva e che
# il gioco stesso cerca.
#
# ===================== COME AGGIUNGERE UN FILE =====================
# 1. In locale/ui.csv due righe nuove, una col NOME e una col TESTO, in inglese e italiano:
#        FN_HR_MIOFILE,my_file.txt,mio_file.txt
#        FT_HR_MIOFILE,First line\nSecond line,Prima riga\nSeconda riga
#    (gli "a capo" si scrivono \n; una cella con una virgola va fra virgolette "...")
# 2. Qui sotto una riga in FILE_EPOCA (file normali d'epoca), FILE_LORE_PADRE (i file
#    del padre) o FILE_HORROR (il ragazzo e la maledizione):
#        ["FN_HR_MIOFILE", "FT_HR_MIOFILE", [DOCUMENTI, TEMP]],
#    l'ultima parte dice DOVE puo' finire (le zone sono qui sotto).
# 3. Lanciare l'import (Godot lo fa da solo all'apertura dell'editor), o il gioco
#    continuera' a mostrare le scritte vecchie.
# 4. tests/disco_casuale_test controlla tutto: che le traduzioni ci siano in tutte e due
#    le lingue, che il file compaia davvero in qualche partita, che il nome non vada in
#    conflitto con un altro, e che nessun testo somigli a una CHIAVE.
# Per MODIFICARE un file basta cambiare il testo nel CSV (punto 1) e rifare l'import.
# La guida completa, con le cartelle e i programmi: docs/DISK_CONTENT.md.
#
# Nei testi {PROTAGONISTA} diventa il nome del protagonista (LORE_PROTAGONIST nel CSV,
# oggi "Noah"): se un giorno cambia nome, si cambia quella riga sola.
#
# Due regole:
#  - i NOMI devono essere diversi fra loro (in ogni lingua), anche solo per maiuscole:
#    su un disco Windows "Nota.txt" e "NOTA.TXT" sono lo stesso file;
#  - in un testo non scrivere niente che sembri una chiave (una cifra, un trattino e
#    quattro lettere/cifre, tipo 2-AB7K): la caccia resta leale solo se le chiavi vere
#    sono le uniche con quella forma.
# ===================================================================

# --- le ZONE: dove un file puo' finire ---
const DOCUMENTI := 0   # Documenti e le sue sottocartelle (MAI Immagini: quella e' del puzzle)
const RADICE := 1      # la radice di C:\, accanto ad AUTOEXEC.BAT
const SISTEMA := 2     # C:\WHALE, la cartella del sistema
const TEMP := 3        # C:\TEMP e C:\WHALE\TEMP
const PROGRAMMA := 4   # dentro la cartella di un programma (in Programmi)
const EXTRA := 5       # le cartelle in piu' di C:\ (GAMES, DRIVERS, ...), quando ci sono

# --- file NORMALI d'epoca: [nome, testo, zone] ---
const FILE_EPOCA := [
	["FN_DIARY", "FT_DIARY", [DOCUMENTI]],
	["FN_PASSWORD", "FT_PASSWORD", [DOCUMENTI]],
	["FN_SHOPPING", "FT_SHOPPING", [DOCUMENTI]],
	["FN_LETTER", "FT_LETTER", [DOCUMENTI]],
	["FN_HOMEWORK", "FT_HOMEWORK", [DOCUMENTI]],
	["FN_RECIPE", "FT_RECIPE", [DOCUMENTI]],
	["FN_PHONES", "FT_PHONES", [DOCUMENTI]],
	["FN_TODO", "FT_TODO", [DOCUMENTI]],
	["FN_SCORES", "FT_SCORES", [DOCUMENTI, EXTRA]],
	["FN_SYSNOTES", "FT_SYSNOTES", [SISTEMA]],
	["FN_CONTROL_INI", "FT_CONTROL_INI", [SISTEMA]],
	["FN_PROTOCOL_INI", "FT_PROTOCOL_INI", [SISTEMA]],
	["FN_NETLOG", "FT_NETLOG", [SISTEMA, RADICE, TEMP]],
	["FN_SETUPLOG", "FT_SETUPLOG", [RADICE]],
	["FN_DETLOG", "FT_DETLOG", [RADICE]],
	["FN_SCANDISK", "FT_SCANDISK", [RADICE]],
	["FN_DRIVER_TXT", "FT_DRIVER_TXT", [EXTRA, TEMP]],
]

# --- i file del PADRE: [nome, testo, zone]. Il PC era suo (GDD §2b): diari che partono
# normali e scivolano, la lettera ai figli, l'ultima notte. Il proprietario vuole il peso
# della storia su di lui, quindi in OGNI partita ce n'e' almeno uno (QUANTI_PADRE). ---
const FILE_LORE_PADRE := [
	["FN_DAD_MARCH", "FT_DAD_MARCH", [DOCUMENTI]],
	["FN_DAD_APRIL", "FT_DAD_APRIL", [DOCUMENTI]],
	["FN_DAD_NOTES", "FT_DAD_NOTES", [DOCUMENTI]],
	["FN_DAD_SONS", "FT_DAD_SONS", [DOCUMENTI, TEMP]],
	["FN_DAD_LATE", "FT_DAD_LATE", [TEMP, SISTEMA, DOCUMENTI]],
	["FN_HR_STILL_ON", "FT_HR_STILL_ON", [DOCUMENTI, TEMP]],
	["FN_HR_WHALE", "FT_HR_WHALE", [SISTEMA, DOCUMENTI]],
]

# --- file HORROR: [nome, testo, zone]. La voce del RAGAZZO da cui tutto e' partito (la
# balena da 52 Hz e' il suo emblema: un richiamo a cui nessuno risponde) e quella della
# MALEDIZIONE, che parla a chi e' al PC adesso. Pochi per partita (QUANTI_HORROR), cosi'
# quando se ne trova uno fa effetto. Alcuni si travestono da file normali. ---
const FILE_HORROR := [
	["FN_HR_52HZ", "FT_HR_52HZ", [SISTEMA, TEMP]],
	["FN_HR_LAST", "FT_HR_LAST", [SISTEMA, TEMP, RADICE]],
	["FN_HR_README", "FT_HR_README", [PROGRAMMA, EXTRA, RADICE]],
	["FN_HR_SCANDISK", "FT_HR_SCANDISK", [RADICE, SISTEMA]],
	["FN_HR_CALL", "FT_HR_CALL", [TEMP, EXTRA, SISTEMA]],
	["FN_HR_AUTOSAVE", "FT_HR_AUTOSAVE", [TEMP]],
	["FN_HR_DONT", "FT_HR_DONT", [DOCUMENTI, TEMP]],
	["FN_HR_ALONE", "FT_HR_ALONE", [DOCUMENTI, TEMP, SISTEMA]],
	["FN_HR_INVENTORY", "FT_HR_INVENTORY", [DOCUMENTI, EXTRA]],
]

# --- i file che OGNI programma inventato puo' avere: [nome, testo, probabilita'] ---
# Nel testo {PROG} diventa il nome del programma: un solo LEGGIMI vale per tutti.
const FILE_DEI_PROGRAMMI := [
	["FN_PRG_README", "FT_PRG_README", 0.7],
	["FN_PRG_LICENSE", "FT_PRG_LICENSE", 0.5],
]

# --- PROGRAMMI inventati, in Programmi: [nome, [file binari]] ---
# Nomi di prodotto uguali in ogni lingua (come lo erano i veri) e niente marchi veri.
const PROGRAMMI := [
	["DiskTune 3.1", ["DISKTUNE.EXE", "DTCORE.DLL"]],
	["NetChat 1.2", ["NETCHAT.EXE", "NCSOCK.DLL"]],
	["TuneBox Mixer", ["TUNEBOX.EXE", "TBWAVE.DRV"]],
	["QuickNote 95", ["QNOTE.EXE"]],
	["Atlas 3D", ["ATLAS3D.EXE", "ATLDATA.DAT"]],
	["Mahjong Gold", ["MAHJONG.EXE", "TILES.DAT"]],
]

# --- cartelle in piu' nella radice di C:\: [nome, [file binari]] ---
# Nomi 8.3 maiuscoli e NON tradotti, come le cartelle di sistema.
const CARTELLE_RADICE := [
	["GAMES", ["MINEFLD.EXE", "PATIENCE.EXE"]],
	["DRIVERS", ["VGA.DRV", "AUDIO16.DRV"]],
	["DOWNLOAD", []],
	["INTERNET", ["DIALER.EXE"]],
]

# --- sottocartelle dell'utente dentro Documenti: chiavi del CSV (sono TRADOTTE) ---
const CARTELLE_DOCUMENTI := ["FD_LETTERS", "FD_SCHOOL", "FD_RECIPES", "FD_WORK", "FD_OLD_STUFF"]

# --- binari in piu' in C:\WHALE\SYSTEM (si aggiungono a quelli fissi) ---
const BINARI_SISTEMA := ["SHELL.DLL", "COMMDLG.DLL", "MMSYSTEM.DLL", "TOOLHELP.DLL",
		"KEYBOARD.DRV", "SYSTEM.DRV", "WINSOCK.DLL", "LZEXPAND.DLL", "VER.DLL"]

# --- QUANTITA' per partita: [minimo, massimo] ---
# padre + horror = 2-3 per partita, come scelto dal proprietario ("pochi e rari"), con
# almeno un file del padre sempre
const QUANTI_PADRE := [1, 2]
const QUANTI_HORROR := [1, 1]
const QUANTI_PROGRAMMI := [1, 3]
const QUANTE_CARTELLE_RADICE := [0, 2]
const QUANTE_SOTTOCARTELLE := [1, 3]
const QUANTI_BINARI_SISTEMA := [2, 5]
const QUANTI_TMP := [1, 3]          # file ~DFxxxx.TMP sparsi nelle due TEMP
# file d'epoca per zona
const QUANTI_EPOCA := {
	DOCUMENTI: [3, 6],
	RADICE: [1, 2],
	SISTEMA: [1, 2],
	TEMP: [0, 1],
	EXTRA: [0, 2],
}
