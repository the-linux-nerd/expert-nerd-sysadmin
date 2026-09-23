#!/usr/bin/env python3
# todo.py — elenco filtrato e ordinato delle voci di TODO.md
#
# Serve a non tirarsi in conversazione le centinaia di righe del file quando ne bastano venti:
# un TODO.md da 500 righe sono ~10k token riletti a ogni turno della sessione, e il pattern
# giusto e' "panoramica compatta -> apro con -v solo la voce su cui lavoro".
#
# Il file si trova da solo risalendo dalla cwd ( funziona anche lanciandolo da dentro dev/ ).
# Sola lettura: per scrivere nel TODO si usa Edit ancorato al testo, cosi' due sessioni
# aperte sullo stesso deploy non si cancellano a vicenda.
#
# Convenzioni: vedi "I cinque file di un progetto" in _etc/_claude/_claude.framework.md.

import argparse, os, re, signal, sys

signal.signal( signal.SIGPIPE, signal.SIG_DFL )   # niente traceback con | head

RE_SEZIONE = re.compile( r'^##+\s+(.*?)\s*$' )
RE_VOCE    = re.compile( r'^- \[([ =?vx])\]\s*(?:\(([-!?])([-!?])([-!?])\))?\s*(.*)$' )

def trova_file( esplicito ):
    if esplicito:
        return esplicito
    d = os.getcwd()
    while True:
        c = os.path.join( d, 'TODO.md' )
        if os.path.exists( c ):
            return c
        p = os.path.dirname( d )
        if p == d:
            sys.exit( 'nessun TODO.md risalendo da ' + os.getcwd() + ' ( usa -f )' )
        d = p

def pulisci( t ):
    t = re.sub( r'\*\*(.+?)\*\*', r'\1', t )
    t = re.sub( r'`(.+?)`', r'\1', t )
    t = re.sub( r'\s+', ' ', t )
    return t.strip()

def leggi( percorso ):
    voci = []
    sezione = '( senza area )'
    with open( percorso, encoding = 'utf-8' ) as f:
        righe = f.read().splitlines()
    for n, riga in enumerate( righe, 1 ):
        m = RE_SEZIONE.match( riga )
        if m:
            sezione = m.group( 1 )
            continue
        # intestazione setext: la riga precedente sottolineata da ===
        if re.match( r'^=+\s*$', riga ) and n > 1:
            prec = righe[ n - 2 ].strip()
            if prec and not prec.startswith( ( '- ', '--', '#', '>' ) ):
                sezione = pulisci( prec )
                continue
        m = RE_VOCE.match( riga )
        if m:
            voci.append( {
                'riga'  : n,
                'stato' : m.group( 1 ),
                'flag'  : ( m.group( 2 ) or '?' ) + ( m.group( 3 ) or '?' ) + ( m.group( 4 ) or '?' ),
                'testo' : pulisci( m.group( 5 ) ),
                'area'  : sezione,
                'note'  : [],
            } )
        elif voci and ( riga.startswith( '--' ) or ( riga.startswith( '   ' ) and riga.strip() ) ):
            if voci[ -1 ][ 'riga' ] >= n - 60:
                voci[ -1 ][ 'note' ].append( riga.rstrip() )
    return voci

def peso( v ):
    f = v[ 'flag' ]
    return -( ( 4 if f[ 0 ] == '!' else 0 ) + ( 2 if f[ 1 ] == '!' else 0 ) + ( 1 if f[ 2 ] == '!' else 0 ) )

def main():
    p = argparse.ArgumentParser(
        description = 'elenca, filtra e ordina le voci di TODO.md',
        epilog = 'esempi:  todo.py -c  |  todo.py -u  |  todo.py -a mail -g bonifico  |  todo.py -v 47' )
    p.add_argument( '-f', '--file',      help = 'TODO.md da leggere ( default: il primo risalendo dalla cwd )' )
    p.add_argument( '-a', '--area',      help = 'regex sul nome dell\'area' )
    p.add_argument( '-g', '--grep',      help = 'regex su testo e note della voce' )
    p.add_argument( '-s', '--stato',     default = ' ', help = 'marcatori da mostrare, es. " =?" ( default: solo " " )' )
    p.add_argument( '-F', '--flag',      help = 'pattern sui tre flag, "." jolly: "!.." urgenti, "!!." urgenti e rilevanti' )
    p.add_argument( '-u', '--urgenti',   action = 'store_true', help = 'scorciatoia per -F "!.."' )
    p.add_argument( '-v', '--voce',      type = int, help = 'stampa per esteso la voce a quel numero di riga' )
    p.add_argument( '-d', '--dettaglio', action = 'store_true', help = 'stampa anche le note sotto ogni voce' )
    p.add_argument( '-c', '--conta',     action = 'store_true', help = 'solo il conteggio per area' )
    p.add_argument( '-A', '--tutte',     action = 'store_true', help = 'tutti i marcatori, [v] e [x] compresi' )
    p.add_argument( '-w', '--larghezza', type = int, default = 96, help = 'colonne per il testo ( 0 = non troncare )' )
    p.add_argument( '--per-area',        action = 'store_true', help = 'raggruppa per area invece di ordinare per priorita' )
    a = p.parse_args()

    percorso = trova_file( a.file )
    if not os.path.exists( percorso ):
        sys.exit( 'manca ' + percorso )

    voci = leggi( percorso )

    if a.voce:
        for v in voci:
            if v[ 'riga' ] == a.voce:
                print( '## ' + v[ 'area' ] )
                print( '- [%s] (%s) %s' % ( v[ 'stato' ], v[ 'flag' ], v[ 'testo' ] ) )
                print( '\n'.join( v[ 'note' ] ) )
                return
        sys.exit( 'nessuna voce alla riga %d di %s' % ( a.voce, percorso ) )

    stati = None if a.tutte else set( a.stato )
    rflag = re.compile( '^' + ( '!..' if a.urgenti else a.flag ) + '$' ) if ( a.flag or a.urgenti ) else None
    rarea = re.compile( a.area, re.I ) if a.area else None
    rgrep = re.compile( a.grep, re.I ) if a.grep else None

    sel = []
    for v in voci:
        if stati is not None and v[ 'stato' ] not in stati: continue
        if rflag and not rflag.match( v[ 'flag' ] ):        continue
        if rarea and not rarea.search( v[ 'area' ] ):       continue
        if rgrep and not rgrep.search( v[ 'testo' ] + ' ' + ' '.join( v[ 'note' ] ) ): continue
        sel.append( v )

    if a.conta:
        aree = {}
        for v in sel:
            aree.setdefault( v[ 'area' ], 0 )
            aree[ v[ 'area' ] ] += 1
        for area, n in aree.items():
            print( '%4d  %s' % ( n, area ) )
        print( '%4d  TOTALE' % len( sel ) )
        return

    sel.sort( key = ( lambda v: ( v[ 'area' ], peso( v ), v[ 'riga' ] ) ) if a.per_area
              else   ( lambda v: ( peso( v ), v[ 'area' ], v[ 'riga' ] ) ) )

    area_corrente = None
    for v in sel:
        if a.per_area and v[ 'area' ] != area_corrente:
            area_corrente = v[ 'area' ]
            print( '\n## ' + area_corrente )
        testo = v[ 'testo' ]
        if a.larghezza and len( testo ) > a.larghezza:
            testo = testo[ : a.larghezza - 1 ] + '…'
        if a.per_area:
            print( '%4d  [%s] %s  %s' % ( v[ 'riga' ], v[ 'stato' ], v[ 'flag' ], testo ) )
        else:
            print( '%4d  [%s] %s  %-28.28s  %s' % ( v[ 'riga' ], v[ 'stato' ], v[ 'flag' ], v[ 'area' ], testo ) )
        if a.dettaglio:
            for r in v[ 'note' ]:
                print( '      ' + r )

    print( '\n-- %d voci in %s' % ( len( sel ), percorso ), file = sys.stderr )

if __name__ == "__main__":
    main()
