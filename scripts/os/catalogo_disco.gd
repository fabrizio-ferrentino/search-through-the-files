class_name CatalogoDisco
extends RefCounted

# IL CATALOGO DEL DISCO (18/10/2026): cosa PUO' esserci sul disco di una partita.
# Solo dati. Chi li usa e' OSContent._riempi_disco, che a ogni partita pesca da qui -- col
# seme del run, quindi stessa partita = stesso disco -- e mette file e cartelle a caso.
# Lo scheletro (unita', C:\WHALE, Programmi, Documenti\Immagini, TEMP, Cestino) NON sta
# qui: e' fisso, in OSContent._disco_c, perche' e' quello che ogni PC del '98 aveva e che
# il gioco stesso cerca.
#
# ===================== COME AGGIUNGERE UN FILE =====================
# 1. In locale/ui.csv due righe nuove, una col NOME e una col TESTO, in inglese e italiano:
#        FN_HR_MIOFILE,my_file.txt,mio_file.txt
#        FT_HR_MIOFILE,First line\nSecond line,Prima riga\nSeconda riga
#    (gli "a capo" si scrivono \n; una cella con una virgola va fra virgolette "...")
# 2. Qui sotto una riga in FILE_EPOCA (file normali d'epoca) o FILE_HORROR:
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

# --- file HORROR: [nome, testo, zone]. Pochi per partita (vedi QUANTI_HORROR): rari,
# cosi' quando se ne trova uno fa effetto. Alcuni si travestono da file normali. ---
const FILE_HORROR := [
	["FN_HR_STILL_ON", "FT_HR_STILL_ON", [DOCUMENTI, TEMP]],
	["FN_HR_52HZ", "FT_HR_52HZ", [SISTEMA, TEMP]],
	["FN_HR_README", "FT_HR_README", [PROGRAMMA, EXTRA, RADICE]],
	["FN_HR_PREVIOUS", "FT_HR_PREVIOUS", [DOCUMENTI]],
	["FN_HR_SCANDISK", "FT_HR_SCANDISK", [RADICE, SISTEMA]],
	["FN_HR_DONT", "FT_HR_DONT", [DOCUMENTI, TEMP]],
	["FN_HR_CALL", "FT_HR_CALL", [TEMP, EXTRA, SISTEMA]],
	["FN_HR_AUTOSAVE", "FT_HR_AUTOSAVE", [TEMP]],
	["FN_HR_INVENTORY", "FT_HR_INVENTORY", [DOCUMENTI, EXTRA]],
	["FN_HR_WHALE", "FT_HR_WHALE", [SISTEMA, DOCUMENTI]],
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
const QUANTI_HORROR := [2, 3]
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
