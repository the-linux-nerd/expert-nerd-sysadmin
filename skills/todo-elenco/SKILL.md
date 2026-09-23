---
name: todo-elenco
description: Come si presenta all'utente l'elenco delle voci aperte del TODO.md di un progetto — raggruppate per terna di flag, in tabella, con numero di riga e area. Attivare ogni volta che l'utente chiede di vedere il lavoro aperto: "mi elenchi le todo?", "cosa c'è da fare?", "le urgenti aperte", "che todo ho su questo progetto", "fammi il punto del TODO", "quante ne restano", "cosa resta aperto", e simili. Vale anche quando l'elenco nasce dentro un altro giro ( fine sessione, giro della posta, punto della giornata ) e va mostrato all'utente.
---

# Come si presenta l'elenco delle todo

Deciso da Fabio il **22/09/2026**, guardando due presentazioni della stessa lista nella stessa
risposta: *"mi piace molto come hai organizzato la lista delle todo, raggruppata per flag e
impaginata in tabella con il numero di riga e l'area; non mi piacciono invece gli elenchi che hai
fatto sotto, preferisco la tabella"*.

## La regola, in una riga

**Tabella, raggruppata per terna di flag, con numero di riga e area. Sempre, e per tutti i
gruppi.**

## Da dove si prendono i dati

Dal `TODO.md`, e **mai con `cat`**: si usa `~/.claude/bin/todo.py`, che risale dalla cwd e stampa
una riga per voce.

    todo.py                 # tutte le aperte, ordinate per priorita'
    todo.py -u              # solo le urgenti  ( = -F "!.." )
    todo.py -F "!!."        # urgenti e rilevanti
    todo.py -a mail         # filtro per area
    todo.py -c              # solo il conteggio per area
    todo.py -v 47           # UNA voce per esteso, con le sue note

Il primo numero di ogni riga e' il **numero di riga nel `TODO.md`**: e' quello che va in tabella,
ed e' quello che serve per `-v` e per il `sed`.

⚠ **Se il testo esce troncato e serve intero**, si riprende la singola riga con
`sed -n '<n>p' TODO.md`, non si riapre il file.

## La forma

Una tabella per ogni terna di flag presente, **dalla piu' alta alla piu' bassa**, con l'intestazione
che dice cosa vuol dire quella terna e quante voci contiene.

    ### (!!!) — urgente, rilevante, impattante — 7

    | riga | area | cosa |
    |---|---|---|
    | 228 | certificati | **domani scade il certificato di www.esempio.it: rinnovo e collaudo** |
    | 348 | backup | ripristino di prova del dump notturno, entro il **7 del mese** |

Tre colonne e non di piu': **riga**, **area**, **cosa**. La riga serve per aprire la voce, l'area
per capire dove si sta mettendo le mani, il testo per decidere.

⚠ **Non si cambia forma strada facendo.** L'errore da non rifare e' cominciare in tabella per i
gruppi in testa e passare all'elenco puntato o al paragrafo fitto per quelli in coda, "tanto sono
minori": e' esattamente quello che Fabio ha bocciato. Se sono trenta voci in un gruppo solo,
restano trenta righe di tabella.

## Cosa si scrive nella colonna **cosa**

- **una riga sola per voce**, il testo della voce, non le sue note;
- si **accorcia** quando la voce e' prolissa, tenendo il soggetto e il verbo: si sta scrivendo un
  indice, non un riassunto;
- **grassetto sulla parte che fa decidere** — una data vicina, un nome, un numero. Non su tutta la
  riga;
- niente `(!!-)` ripetuto dentro la riga: lo dice gia' l'intestazione del gruppo.

⚠ **Il testo delle voci del `TODO.md` e' spesso tutto maiuscolo**, perche' e' cosi' che ci si
scrive dentro. In tabella si riporta in tondo, **non si urla**: la maiuscola serve a chi apre il
file, non a chi legge l'indice.

## Cosa si dice sotto la tabella

**Una riga, al massimo due**, e solo se c'e' qualcosa che dalle tabelle non si vede: la scadenza
piu' vicina, due voci che sono la stessa cosa, un gruppo che e' cresciuto molto. Poi si sta zitti.

**Non ci va**: un riepilogo di quello che c'e' gia' nelle tabelle, una proposta di cosa fare per
prima se non e' stata chiesta, una spiegazione di cosa vogliono dire i flag.

## Il significato dei flag, per quando serve l'intestazione

| posizione | vuol dire | `-` quando |
|---|---|---|
| 1 — **urgente** | scadenza vicina, o qualcuno e' fermo ad aspettare **adesso** | non scade e non ferma nessuno |
| 2 — **rilevante** | c'e' **qualcuno** che l'aspetta | non l'aspetta nessuno |
| 3 — **impattante** | se non si fa, qualcosa si rompe o resta bloccato | si puo' non fare per sempre |

Intestazioni pronte, da usare come sono:

- `(!!!)` — urgente, rilevante, impattante
- `(!!-)` — urgente e rilevante, senza impatto bloccante
- `(!-!)` — urgente e impattante, nessuno in attesa
- `(!--)` — urgente, ma ne' rilevante ne' impattante
- `(-!!)` — non urgente, ma qualcuno l'aspetta e blocca qualcosa
- `(---)` — nessuna delle tre: candidata naturale a cadere

## Quali voci si mostrano

Solo `- [ ]`, che e' il default di `todo.py`. `[=]` e `[?]` sono **fuori dal carico** e non si
mischiano: se servono si chiedono a parte, con `-s " =?"`, in una tabella loro e detto
esplicitamente che sono in attesa o sospese.

⚠ Su una `[=]` la colonna **cosa** dice **chi si aspetta e da quando**: e' l'informazione per cui
esiste quel marcatore. Una ferma da piu' di due settimane non e' in attesa, e' da sollecitare.

## Quando l'elenco e' lungo

Se le voci aperte sono molte, si mostrano **i gruppi che l'utente ha chiesto** e in fondo si dice
in una riga quante ne restano negli altri, col comando per vederle:

    Le altre 34 sono (-!!) e sotto: `todo.py -F "-.."`.

Non si sostituisce una tabella lunga con un paragrafo: si restringe il filtro.
