# Prima interfaccia Shiny: decisioni e revisione

Specifica autorizzata: docs/superpowers/plans/2026-11-24-first-shiny-interface.md. Nessun commit/push fino ad approvazione successiva.

- Tre viste approvate: Dati e configurazione, Anteprima, Storico; nessun motore scientifico o reporting aggiunto.
- Ruling: conservare separatamente il nome originale del browser mediante original_names opzionale in register_input. I nomi non diventano percorsi di storage; i byte sono copiati e verificati come nella fondazione.
- Ruling: un solo modulo Shiny coordina servizi e repository gia' separati; ogni sessione possiede la propria connessione. I form legano versione, risorsa e configurazione mediante un token; una revisione storica non permette salvataggi.
- Ruling: run_app imposta il limite Shiny di processo a 201 MiB per essere coerente con il percorso launcher. Registrazione e quote di storage restano controllate indipendentemente dal trasporto.
- Review: un revisore indipendente ha identificato lo stato UI obsoleto dopo un errore, il limite incoerente nell'API pubblica e il README superato. Tutti corretti con test pertinenti o verifica della documentazione; nessun finding rinviato.
- Browser regression: trovato e riprodotto l'errore di indice su risultati senza tabelle; corretto req(length(tables) > 0). La suite ora forza anche l'output HTML.
- Package verification: corretti import inutilizzato e Unicode non portabile. Ultimo R CMD check: Status: OK.
- Final evidence: 187 asserzioni passate senza errori/warning; collaudo browser integrato a 1280 e 390 px; revisione salvata, storico, limitazioni e persistenza verificati.
- Ruling: il selettore file nativo non e' dichiarato automatizzato nel browser integrato, che non espone l'evento filechooser. Upload e buffer sono coperti dai test Shiny/SQLite; il collaudo visivo usa raccolte sintetiche aggiunte tramite il servizio e conserva i dati reali gia' presenti.
