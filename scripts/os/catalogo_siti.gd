class_name CatalogoSiti
extends RefCounted

# IL CATALOGO DEI SITI (19/10/2026): quali siti PUO' avere il web di una partita. Solo dati.
# Chi li usa e' WebRuntime.build(), che a ogni partita pesca da qui -- col seme del run,
# quindi stessa partita = stessi siti -- da SITI_MIN a SITI_MAX siti, di cui da LORE_MIN a
# LORE_MAX di lore (WebRuntime). Tutti quelli estratti stanno nel portale WebNet.
# L'elenco completo previsto (30 siti) e il punto a cui e' ognuno: docs/WEB_CATALOG.md.
#
# UN SITO E' UNA CARTELLA: web/pages/<lingua>/<id>/, con index.html e le sue pagine. I NOMI
# delle pagine sono identificatori, uguali in tutte le lingue (cambia il contenuto); dentro
# una pagina i link fra pagine dello stesso sito sono RELATIVI (href="regole.html"); gli
# unici ASSOLUTI sono il portale (href="http://www.webnet.it") e gli indirizzi morti.
#
# ===================== COME AGGIUNGERE UN SITO =====================
# 1. La cartella web/pages/en/<id>/ e web/pages/it/<id>/ con gli STESSI file .html
#    (almeno index.html). Le regole dell'HTML: docs/WEB_AUTHORING.md.
# 2. In locale/ui.csv due righe: il nome e la descrizione che il portale mostra
#        WS_MIOSITO,My site,Il mio sito
#        WS_MIOSITO_D,What it is about,Di cosa parla
# 3. Qui sotto una riga in SITI (vedi i campi), con l'elenco delle sue pagine.
# 4. L'import (Godot lo fa da solo all'apertura dell'editor) e tests/siti_catalogo_test:
#    controlla che le pagine ci siano in tutte le lingue, che i link portino da qualche
#    parte, che i domini non si ripetano e che nessun testo somigli a una CHIAVE.
#
# I CAMPI di un sito:
#   id        il nome della cartella e del sito (mai tradotto)
#   nome      la chiave CSV del nome che il portale mostra
#   desc      la chiave CSV della descrizione
#   en, it    il DOMINIO in ogni lingua (www.newstoday.com / www.newsoggi.it): un sito
#             inglese su un .it si nota subito. Puo' avere un percorso (lo spazio
#             personale sull'ISP: www.webnet.it/~jack99)
#   tipo      "normale" o "lore"
#   voce      solo per la lore: di chi parla -- "padre", "ragazzo" o "maledizione" (la
#             regola di estrazione vuole almeno un sito del padre e uno del ragazzo)
#   featured  nel portale fra i PREFERITI (true) o fra i visitati di RECENTE (false)
#   stato     "segnaposto" (da riscrivere) o "completo" (scritto per davvero: il test
#             pretende almeno COMPLETO_PAGINE pagine e COMPLETO_TESTO caratteri di testo)
#   pagine    i file del sito senza ".html", index per primo. La chiave web puo' finire
#             in UNA qualunque di queste
#   morti     (facoltativo) i link morti VOLUTI: una pagina del sito che non esiste
#             apposta ("removed": la discussione rimossa del forum, che da' la 404), o
#             l'indirizzo di un sito che non c'e' piu' (le pagine sparite degli amici: "server
#             non trovato"). Il test dei link li accetta; tutto il resto deve portare da
#             qualche parte
#
# Le regole per i testi (le controlla tests/siti_catalogo_test):
#  - niente che sembri una chiave (una cifra, un trattino e quattro lettere/cifre);
#  - la storia e' quella di docs/GDD.md §2b, e cio' che li' e' APERTO (i nomi, come passa la
#    maledizione) nei testi non si inventa: si scrive attorno;
#  - un sito e' CHIUSO in se stesso (proprietario, 20/10/2026): niente link a un altro sito
#    del catalogo, solo al portale WebNet o a un indirizzo morto elencato in "morti";
#  - niente <input>, <form>, <button>: il browser non li sa usare, quindi un accesso, una
#    ricerca, un carrello si scrivono CHIUSI ("accesso sospeso", "ordini sospesi");
#  - le date sono assolute e non vanno oltre il 1999 (il web del PC e' fermo li', GDD §2b):
#    mai "oggi, 21:05" o "ieri".
# Per vederli tutti in una partita: pannello F12, "All sites: ON".

const COMPLETO_PAGINE := 5          # un sito "completo" ha almeno tante pagine...
const COMPLETO_TESTO := 6000        # ...e almeno tanti caratteri di testo visibile, per lingua

const SITI := [
	{"id": "forum", "nome": "WS_FORUM", "desc": "WS_FORUM_D",
		"en": "www.retroforum.com", "it": "www.retroforum.it",
		"tipo": "normale", "voce": "", "featured": false, "stato": "completo",
		"pagine": ["index", "hardware", "software", "internet", "market", "offtopic", "members",
				"profile_anna", "rules", "login", "thread", "thread_modem", "thread_pc", "thread_y2k"],
		"morti": ["removed"]},
	{"id": "shop", "nome": "WS_SHOP", "desc": "WS_SHOP_D",
		"en": "www.buyitall.com", "it": "www.compratutto.com",
		"tipo": "normale", "voce": "", "featured": true, "stato": "completo",
		"pagine": ["index", "computers", "home", "fun", "product_pc", "product_vcr", "cart",
				"terms", "help"]},
	# l'archivio del quotidiano locale: l'articolo sulla tragedia della famiglia (GDD §2b)
	{"id": "cronaca", "nome": "WS_HERALD", "desc": "WS_HERALD_D",
		"en": "www.countyherald.com", "it": "www.gazzettadellaprovincia.it",
		"tipo": "lore", "voce": "padre", "featured": false, "stato": "completo",
		"pagine": ["index", "cronaca", "tragedia", "seguito", "fiera", "furto", "archivio",
				"redazione"]},
	# un forum di genitori: dentro, i messaggi del padre che scivola (GDD §2b)
	{"id": "genitori", "nome": "WS_KITCHEN", "desc": "WS_KITCHEN_D",
		"en": "www.kitchentableforum.com", "it": "www.tavolodicucina.it",
		"tipo": "lore", "voce": "padre", "featured": false, "stato": "completo",
		"pagine": ["index", "dads", "school", "thread_seaside", "thread_sleep", "thread_voice",
				"thread_boys", "profile_dad", "login"]},
	# la pagina personale del ragazzo da cui la maledizione e' partita (GDD §2b), sullo
	# spazio gratuito dell'ISP. I link morti sono le pagine degli amici, sparite
	{"id": "balena", "nome": "WS_WHALE", "desc": "WS_WHALE_D",
		"en": "www.webnet.com/~whale52", "it": "www.webnet.it/~balena52",
		"tipo": "lore", "voce": "ragazzo", "featured": false, "stato": "completo",
		"pagine": ["index", "about", "whale", "links", "thoughts", "guestbook", "update"],
		"morti": ["www.webnet.com/~danny", "www.webnet.com/~steve_and_amy", "www.lonelyring.com",
				"www.webnet.it/~gianlu", "www.webnet.it/~sere_e_ale", "www.anellodeisolitari.it"]},
	{"id": "news", "nome": "WS_NEWS", "desc": "WS_NEWS_D",
		"en": "www.thenewstoday.com", "it": "www.notizieoggi.it",
		"tipo": "normale", "voce": "", "featured": true, "stato": "completo",
		"pagine": ["index", "about", "art_cup", "art_rain", "art_traffic", "art_web", "art_y2k", "national", "sport", "tech", "world"]},
	{"id": "meteo", "nome": "WS_WEATHER", "desc": "WS_WEATHER_D",
		"en": "www.weathernow-online.com", "it": "www.meteonow.it",
		"tipo": "normale", "voce": "", "featured": true, "stato": "completo",
		"pagine": ["index", "cities", "glossary", "satellite", "sea", "seasonal"]},
	{"id": "giochi", "nome": "WS_GAMES", "desc": "WS_GAMES_D",
		"en": "www.playwebgames.com", "it": "www.giocaweb.com",
		"tipo": "normale", "voce": "", "featured": true, "stato": "completo",
		"pagine": ["index", "chart", "cheats", "download", "new", "review_starhauler", "reviews"]},
	{"id": "mail", "nome": "WS_MAIL", "desc": "WS_MAIL_D",
		"en": "webmail.webnet.com", "it": "webmail.webnet.it",
		"tipo": "normale", "voce": "", "featured": true, "stato": "completo",
		"pagine": ["index", "help", "news", "safety", "space", "terms"]},
	# la pagina di un ragazzo felice, con gli amici e un guestbook pieno: il rovescio di balena
	{"id": "blog", "nome": "WS_JACK", "desc": "WS_JACK_D",
		"en": "www.webnet.com/~jack99", "it": "www.webnet.it/~jack99",
		"tipo": "normale", "voce": "", "featured": false, "stato": "completo",
		"pagine": ["index", "about", "band", "gang", "guestbook", "links", "trip"],
		"morti": ["www.webnet.com/~sarah_b", "www.webnet.com/~freddie82", "www.webnet.com/~thegarageband", "www.webnet.it/~sara_b", "www.webnet.it/~fede82", "www.webnet.it/~ilgaragedeiricci"]},
	{"id": "biblioteca", "nome": "WS_LIBRARY", "desc": "WS_LIBRARY_D",
		"en": "www.millbrooklibrary.org", "it": "www.bibliotecasanvito.it",
		"tipo": "normale", "voce": "", "featured": false, "stato": "completo",
		"pagine": ["index", "catalog", "events", "history", "hours", "loans", "new"]},
	{"id": "ricette", "nome": "WS_GRANNY", "desc": "WS_GRANNY_D",
		"en": "www.webnet.com/~grannyrose", "it": "www.webnet.it/~nonnarosa",
		"tipo": "normale", "voce": "", "featured": false, "stato": "completo",
		"pagine": ["index", "about", "desserts", "easter_cake", "first", "lasagne", "letters", "mains"]},
	{"id": "calcio", "nome": "WS_FOOTBALL", "desc": "WS_FOOTBALL_D",
		"en": "www.griffinsfanclub.com", "it": "www.forzagrifoni.it",
		"tipo": "normale", "voce": "", "featured": false, "stato": "completo",
		"pagine": ["index", "away", "board", "club", "history", "results", "squad"]},
	{"id": "tv", "nome": "WS_TV", "desc": "WS_TV_D",
		"en": "www.couchguide.com", "it": "www.teleguida.it",
		"tipo": "normale", "voce": "", "featured": true, "stato": "completo",
		"pagine": ["index", "films", "kids", "letters", "series", "week"]},
	{"id": "musica", "nome": "WS_MIDI", "desc": "WS_MIDI_D",
		"en": "www.midimania.com", "it": "www.midiworld.it",
		"tipo": "normale", "voce": "", "featured": false, "stato": "completo",
		"pagine": ["index", "chart", "howto", "lyrics", "midi", "requests"]},
	{"id": "viaggi", "nome": "WS_TRAVEL", "desc": "WS_TRAVEL_D",
		"en": "www.sunandsea-travel.com", "it": "www.viaggisolemare.it",
		"tipo": "normale", "voce": "", "featured": false, "stato": "completo",
		"pagine": ["index", "agency", "booking", "destinations", "families", "honeymoon", "offers"]},
	{"id": "comune", "nome": "WS_TOWN", "desc": "WS_TOWN_D",
		"en": "www.millbrooktown.org", "it": "www.comune.sanvitoallago.it",
		"tipo": "normale", "voce": "", "featured": false, "stato": "completo",
		"pagine": ["index", "certificates", "events", "notices", "offices", "town", "waste"]},
	{"id": "scuola", "nome": "WS_SCHOOL", "desc": "WS_SCHOOL_D",
		"en": "www.millbrookhigh.org", "it": "www.liceogalilei-sanvito.it",
		"tipo": "normale", "voce": "", "featured": false, "stato": "completo",
		"pagine": ["index", "calendar", "circulars", "computers", "contacts", "paper", "trips"]},
	{"id": "driver", "nome": "WS_DRIVERS", "desc": "WS_DRIVERS_D",
		"en": "www.driverzone.com", "it": "www.driverzone.it",
		"tipo": "normale", "voce": "", "featured": false, "stato": "completo",
		"pagine": ["index", "faq", "modem", "printers", "sound", "utilities", "video"]},
	{"id": "animali", "nome": "WS_SHELTER", "desc": "WS_SHELTER_D",
		"en": "www.faithfulfriendshelter.org", "it": "www.rifugioamicofedele.it",
		"tipo": "normale", "voce": "", "featured": false, "stato": "completo",
		"pagine": ["index", "adopt", "cats", "dogs", "help", "stories", "volunteers"]},
	{"id": "oroscopo", "nome": "WS_STARS", "desc": "WS_STARS_D",
		"en": "www.thestarsweekly.com", "it": "www.lestelle.it",
		"tipo": "normale", "voce": "", "featured": false, "stato": "completo",
		"pagine": ["index", "letters", "love", "moon", "signs", "week"]},
	# un sito di misteri: computer che guardano, oggetti che passano qualcosa, la balena dei 52 Hz
	{"id": "misteri", "nome": "WS_MYST", "desc": "WS_MYST_D",
		"en": "www.hiddentruths.net", "it": "www.veritanascoste.net",
		"tipo": "lore", "voce": "maledizione", "featured": false, "stato": "completo",
		"pagine": ["index", "about", "last", "letters", "objects", "reports", "whale"]},
	# sembra normale: fra case e auto, la rubrica dei cuori solitari col suo annuncio che torna uguale
	{"id": "annunci", "nome": "WS_ADS", "desc": "WS_ADS_D",
		"en": "www.freeadsboard.com", "it": "www.annuncigratis.it",
		"tipo": "lore", "voce": "ragazzo", "featured": true, "stato": "completo",
		"pagine": ["index", "cars", "hearts", "hearts_archive", "homes", "jobs", "misc", "rules"]},
	# sembra normale: nell'archivio delle conversazioni lui saluta e nessuno risponde
	{"id": "chat", "nome": "WS_CHAT", "desc": "WS_CHAT_D",
		"en": "www.chatpointlive.com", "it": "www.chatpoint.it",
		"tipo": "lore", "voce": "ragazzo", "featured": true, "stato": "completo",
		"pagine": ["index", "archive", "log_last", "log_owls", "log_party", "rooms", "rules", "smileys"]},
	# sembra normale: nel forum le sue domande ricevono risposte sbrigative
	{"id": "lavoro", "nome": "WS_JOBS", "desc": "WS_JOBS_D",
		"en": "www.jobfinderboard.com", "it": "www.cercolavoro.it",
		"tipo": "lore", "voce": "ragazzo", "featured": false, "stato": "completo",
		"pagine": ["index", "cv", "forum", "interview", "offers", "rules", "thread_night", "thread_smile"]},
	# il "metodo" venduto per corrispondenza, e l'area clienti dove lui ha scritto
	{"id": "vincente", "nome": "WS_METHOD", "desc": "WS_METHOD_D",
		"en": "www.thewinnermethod.com", "it": "www.metodovincente.it",
		"tipo": "lore", "voce": "ragazzo", "featured": false, "stato": "completo",
		"pagine": ["index", "clients", "faq", "method", "order", "stories", "thread_diary"]},
	# la linea d'ascolto rimasta senza volontari: i suoi messaggi, senza risposta
	{"id": "ascolto", "nome": "WS_LISTEN", "desc": "WS_LISTEN_D",
		"en": "www.someonelistens.org", "it": "www.qualcunoascolta.it",
		"tipo": "lore", "voce": "ragazzo", "featured": false, "stato": "completo",
		"pagine": ["index", "board", "how", "letter", "volunteers", "waiting"]},
	# il tecnico a domicilio: le note di intervento a casa del padre
	{"id": "tecnico", "nome": "WS_REPAIR", "desc": "WS_REPAIR_D",
		"en": "www.pcdoctorathome.com", "it": "www.dottoredelpc.it",
		"tipo": "lore", "voce": "padre", "featured": false, "stato": "completo",
		"pagine": ["index", "notes", "notice", "prices", "services", "tips"]},
	# annunci normali, e un vecchio PC rimesso in vendita piu' volte, con chi scrive "non compratelo"
	{"id": "mercatino", "nome": "WS_MARKET", "desc": "WS_MARKET_D",
		"en": "www.usedpcmarket.com", "it": "www.mercatinopc.it",
		"tipo": "lore", "voce": "maledizione", "featured": false, "stato": "completo",
		"pagine": ["index", "check", "computers", "feedback", "monitors", "parts", "rules", "wanted"]},
	# una pagina che non dovrebbe esserci: la maledizione parla a chi e' al PC adesso (GDD 2b)
	{"id": "nessuno", "nome": "WS_NOBODY", "desc": "WS_NOBODY_D",
		"en": "www.nobodyhome.net", "it": "www.nessunoincasa.it",
		"tipo": "lore", "voce": "maledizione", "featured": false, "stato": "completo",
		"pagine": ["index", "door", "family", "keys", "visitors", "whale", "windows", "you"]},
]

# Il sito con quell'id ({} se non c'e').
static func sito(id: String) -> Dictionary:
	for s in SITI:
		if str(s["id"]) == id:
			return s
	return {}
