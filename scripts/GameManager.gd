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
