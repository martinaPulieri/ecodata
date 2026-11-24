# Prima interfaccia Shiny: guida e verifica manuale

## Avvio locale

Dal checkout, aprire ecoplatform-r/ e ripristinare le dipendenze descritte nel README. Per una libreria gia' predisposta impostare ECODATA_R_LIBRARY. Avviare:

```text
Rscript --vanilla tools/launch-shiny.R
```

Il server ascolta soltanto su 127.0.0.1:8791. ECODATA_PORT permette di scegliere un'altra porta libera; ECODATA_RUNTIME_ROOT sceglie la cartella locale non sincronizzata dei dati. Senza override usa la cartella dati R dell'utente. Non usare Dropbox per il database attivo. Il processo deve restare avviato mentre si usa il browser.

Il caricamento Shiny ammette un corpo richiesta di 201 MiB; la registrazione controlla i byte effettivi con i limiti di 50 MiB per file e 200 MiB complessivi. Per avviare la cartella direttamente da RStudio e' disponibile anche app.R. Ogni sessione apre e chiude soltanto la propria connessione SQLite; i dati registrati restano disponibili alle sessioni successive.

## Prova dal browser

1. Aprire l'URL locale. A runtime nuovo, i tre contatori mostrano zero. Non e' prevista alcuna autenticazione in questa versione locale; Operatore e' un'etichetta di provenienza inserita dall'utente.
2. In Aggiungi dati, scegliere tests/fixtures/tabular/interface-demo.csv. Scrivere un nome raccolta e un operatore; premere Registra input. La sola selezione di un file non lo registra.
3. Verificare il nome originale interface-demo.csv e la revisione 1. Il separatore viene ora rilevato automaticamente come punto e virgola; codifica UTF-8. Gli identificatori distinguono anche risorse con lo stesso nome; il percorso temporaneo Shiny non diventa il nome del file.
4. Verificare il rilevamento; impostare Separatore decimale dichiarato a Virgola. I cambiamenti manuali non salvano nulla finche' non si preme Salva nuova revisione. Per una configurazione precedente senza rilevamento e' disponibile Rileva formato.
5. Salvare. Compare revisione 2; revisione 1 resta selezionabile e conserva i valori precedenti. Una revisione storica non presenta il pulsante di salvataggio. Un client obsoleto viene respinto anche dal server.
6. Premere Genera anteprima. La scheda Anteprima mostra fino a venti righe. Verificare station 001/002/003, value 1,5/0/<0,1 e date 03/04/25/NA/2025: restano stringhe, senza inferenze di precisione o formato temporale.
7. Aprire Storico. L'operazione di anteprima ha tre eventi queued, running e completed ed e' legata alla revisione 2. Unsupported/unreadable genera invece completed_with_limitations; l'integrita' fallita prima della sottomissione non e' un'anteprima riuscita.
8. Selezionare una revisione/file diverso: l'anteprima precedente deve sparire. Generarne una nuova esplicitamente; non associare una vecchia anteprima alla nuova selezione.
9. Ricaricare la pagina o aprire una seconda sessione. La raccolta, le revisioni e lo storico restano disponibili. Non vengono rieseguite automaticamente anteprime o operazioni pendenti.
10. Ridurre la finestra: sotto 850 px i pannelli si dispongono verticalmente e le tabelle restano scorribili in orizzontale. Verificare che tutti i pulsanti siano raggiungibili.

Per DwC-A i parser delle tabelle sono dichiarati nel meta.xml: il modulo non propone override non supportati. Un archivio senza descrittore riconosciuto resta conservato con una limitazione esplicita. L'anteprima di una versione considera i file di quella versione con la configurazione congelata; la tabella visibile segue il file selezionato.

## Perimetro e codice

Per rimozione reversibile, vista Rimossi, ripristino e relativi controlli manuali,
vedere [workspace-removal.md](workspace-removal.md). La rimozione conserva tutti
i byte e lo storico e riguarda la versione selezionata, con tutti i suoi file.

- app_ui.R: struttura delle tre viste; inst/www/workspace.css: stile locale e responsive.
- mod_workspace.R: reattivita', eventi espliciti e guardie del contesto.
- service_workspace.R: passaggio upload -> registrazione/configurazione e anteprima -> storico.
- run_app.R: connessione posseduta dalla singola sessione; tools/launch-shiny.R: avvio locale.
- test-shiny-workspace.R usa shiny::testServer; test-workspace-services.R verifica i servizi con SQLite reale.

Nessun controllo scientifico, revisione di finding, harvesting o report Quarto e' stato aggiunto. I messaggi di completamento descrivono soltanto l'esecuzione dell'anteprima. Le modifiche richiedono ancora approvazione prima di commit/push.
