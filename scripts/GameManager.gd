extends Node

# Questa variabile rimarrà in memoria per tutto il gioco
var first_time_in_room = true

# Sessione del PC: stato delle finestre aperte nel monitor, mantenuto tra una
# visita e l'altra (sessione continua). null = nessuna sessione salvata.
var pc_session = null

# Ultima "foto" del desktop, mostrata sullo schermo del monitor nella stanza.
var pc_screenshot: Image = null

# True quando si torna dal PC alla stanza: attiva l'animazione inversa (zoom-out + dissolvenza).
var returning_from_pc = false

# Stato di accensione del "case" (il computer). true = acceso: il monitor riceve
# segnale. Si accende/spegne dal pulsante del case nella stanza (o con "Spegni il
# PC" dal menu Start). A PC spento il monitor mostra "nessun segnale".
var pc_on := false

# True dopo aver inserito la password: distingue la schermata di login dal
# desktop. Resta true uscendo con ESC (sessione continua), torna false allo
# spegnimento. Un PC puo' essere acceso ma non ancora loggato (mostra il login).
var logged_in := false
