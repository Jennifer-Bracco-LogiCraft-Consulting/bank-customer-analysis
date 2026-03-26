/*  ==============================================================================================
	ANALISI DEI CLIENTI DI UNA BANCA
    
    Obiettivo: creare una tabella denormalizzata per il training di modelli di Machine Learning
	==============================================================================================*/

/*  ==============================================================================================
	SELEZIONE DELLO SCHEMA
    Database: banca
    
    Lo script lavora su un unico database, per questo motivo lo schema viene impostato all'inizio,
    evitando l'uso del prefisso del database in ogni query per migliorare scrittura e leggibilità
    ==============================================================================================*/
USE banca;

/*  ============================================================================================================================
	OVERVIEW TABELLE
    
    Per ciascuna tabella informativa e di dettaglio presente nel database viene effettuata un'overview della struttura
    e del numero dei record, una visualizzazione limitata dei dati e una valutazione per eventuale presenza di valori mancanti;
    per ciascuna tabella descrittiva viene effettuata un'overview della struttura e dei dati.
    ============================================================================================================================*/
-- TABELLA CLIENTE
-- Struttura
DESCRIBE cliente;
-- Numero di record
SELECT COUNT(*) AS n_record FROM cliente;
-- Ispezione dati
SELECT * FROM cliente LIMIT 20;
-- Ispezione valori mancanti
SELECT
	SUM(id_cliente IS NULL) AS id_cliente_null,
	SUM(nome IS NULL) AS nome_null,
    SUM(cognome IS NULL) AS cognome_null,
    SUM(data_nascita IS NULL) AS data_nascita_null
FROM cliente;

-- TABELLA CONTO
-- Struttura
DESCRIBE conto;
-- Numero di record
SELECT COUNT(*) AS n_record FROM conto;
-- Ispezione dati
SELECT * FROM conto LIMIT 20;
-- Ispezione valori mancanti
SELECT
	SUM(id_conto IS NULL) AS id_conto_null,
	SUM(id_cliente IS NULL) AS id_cliente_null,
    SUM(id_tipo_conto IS NULL) AS id_tipo_conto_null
FROM conto;

-- TABELLA TIPO_CONTO
-- Struttura
DESCRIBE tipo_conto;
-- Ispezione dati
SELECT * FROM tipo_conto;

-- TABELLA TIPO_TRANSAZIONE
-- Struttura
DESCRIBE tipo_transazione;
-- Ispezione dati
SELECT * FROM tipo_transazione;

-- TABELLA TRANSAZIONI
-- Struttura
DESCRIBE transazioni;
-- Numero di record
SELECT COUNT(*) AS n_record FROM transazioni;
-- Ispezione dati
SELECT * FROM transazioni LIMIT 20;
-- Ispezione valori mancanti
SELECT
	SUM(data IS NULL) AS data_null,
	SUM(id_tipo_trans IS NULL) AS id_tipo_trans_null,
    SUM(importo IS NULL) AS importo_null,
    SUM(id_conto IS NULL) AS id_conto_null
FROM transazioni;

/*  ========================================================================================================
	CALCOLO DEGLI IDICATORI COMPORTAMENTALI
    
    Per il calcolo degli indicatori comportamentali vengono utilizzate tabelle temporanee, al fine di
    isolare i calcoli e garantire maggiore controllo e affidabilità dei risultati intermedi. Queste tabelle 
    verranno utilizzate per la creazione della tabella finale.
    ========================================================================================================*/
-- Eliminazione preventiva delle tabelle temporanee per garantire la corretta riesecuzione dello script
DROP TEMPORARY TABLE IF EXISTS info_base_tmp, info_transazioni_tmp, info_conti_tmp, info_trans_conto_tmp;

/*  ===================================================================================
	INDICATORI DI BASE
    ===================================================================================*/
-- 1. Età del cliente
CREATE TEMPORARY TABLE info_base_tmp AS
SELECT
	id_cliente,
    TIMESTAMPDIFF(YEAR, data_nascita, CURRENT_DATE()) AS eta
FROM cliente;

-- Visualizzazione di controllo
SELECT * FROM info_base_tmp;

/*  ===================================================================================
	INDICATORI SULLE TRANSAZIONI
    ===================================================================================*/
CREATE TEMPORARY TABLE info_transazioni_tmp AS
SELECT
	conto.id_cliente,
    -- 2. Numero di transazioni in uscita su tutti i conti
    SUM(CASE WHEN tp_trans.segno = "-" THEN 1 ELSE 0 END) AS n_trans_uscita,
    -- 3. Numero di transazioni in entrata su tutti i conti
    SUM(CASE WHEN tp_trans.segno = "+" THEN 1 ELSE 0 END) AS n_trans_entrata,
    -- 4. Importo totale transato in uscita su tutti i conti
    SUM(CASE WHEN tp_trans.segno = "-" THEN trans.importo ELSE 0 END) AS imp_tot_uscita,
    -- 5. Importo totale transato in entrata su tutti i conti
    SUM(CASE WHEN tp_trans.segno = "+" THEN trans.importo ELSE 0 END) AS imp_tot_entrata
FROM conto
LEFT JOIN transazioni trans
	ON conto.id_conto = trans.id_conto
LEFT JOIN tipo_transazione tp_trans
	ON trans.id_tipo_trans = tp_trans.id_tipo_transazione
GROUP BY 1
ORDER BY 1;

-- Visualizzazione di controllo
SELECT * FROM info_transazioni_tmp;

/*  ===================================================================================
	INDICATORI SUI CONTI
    ===================================================================================*/
CREATE TEMPORARY TABLE info_conti_tmp AS
SELECT
	id_cliente,
    -- 6. Numero totale di conti posseduti
	COUNT(id_conto) AS tot_conti,
    -- 7. Numero di conti posseduti per tipologia
	SUM(CASE WHEN id_tipo_conto = 0 THEN 1 ELSE 0 END) AS conto_base,
	SUM(CASE WHEN id_tipo_conto = 1 THEN 1 ELSE 0 END) AS conto_business,
	SUM(CASE WHEN id_tipo_conto = 2 THEN 1 ELSE 0 END) AS conto_privati,
	SUM(CASE WHEN id_tipo_conto = 3 THEN 1 ELSE 0 END) AS conto_famiglie
FROM conto
GROUP BY 1
ORDER BY 1;

-- Visualizzazione di controllo
SELECT * FROM info_conti_tmp;

/*  ===================================================================================
	INDICATORI SULLE TRANSAZIONI PER TIPOLOGIA DI CONTO
    ===================================================================================*/
CREATE TEMPORARY TABLE info_trans_conto_tmp AS
SELECT
	conto.id_cliente,
    -- 8. Numero di transazioni in uscita per tipologia di conto
    SUM(CASE WHEN tp_trans.segno = "-" AND conto.id_tipo_conto = 0 THEN 1 ELSE 0 END) AS n_trans_uscita_conto_base,
    SUM(CASE WHEN tp_trans.segno = "-" AND conto.id_tipo_conto = 1 THEN 1 ELSE 0 END) AS n_trans_uscita_conto_business,
    SUM(CASE WHEN tp_trans.segno = "-" AND conto.id_tipo_conto = 2 THEN 1 ELSE 0 END) AS n_trans_uscita_conto_privati,
    SUM(CASE WHEN tp_trans.segno = "-" AND conto.id_tipo_conto = 3 THEN 1 ELSE 0 END) AS n_trans_uscita_conto_famiglie,
    -- 9. Numero di transazioni in entrata per tipologia di conto
    SUM(CASE WHEN tp_trans.segno = "+" AND conto.id_tipo_conto = 0 THEN 1 ELSE 0 END) AS n_trans_entrata_conto_base,
    SUM(CASE WHEN tp_trans.segno = "+" AND conto.id_tipo_conto = 1 THEN 1 ELSE 0 END) AS n_trans_entrata_conto_business,
    SUM(CASE WHEN tp_trans.segno = "+" AND conto.id_tipo_conto = 2 THEN 1 ELSE 0 END) AS n_trans_entrata_conto_privati,
    SUM(CASE WHEN tp_trans.segno = "+" AND conto.id_tipo_conto = 3 THEN 1 ELSE 0 END) AS n_trans_entrata_conto_famiglie,
    -- 10. Importo totale transato in uscita per tipologia di conto
    SUM(CASE WHEN tp_trans.segno = "-" AND conto.id_tipo_conto = 0 THEN trans.importo ELSE 0 END) AS imp_tot_uscita_conto_base,
    SUM(CASE WHEN tp_trans.segno = "-" AND conto.id_tipo_conto = 1 THEN trans.importo ELSE 0 END) AS imp_tot_uscita_conto_business,
    SUM(CASE WHEN tp_trans.segno = "-" AND conto.id_tipo_conto = 2 THEN trans.importo ELSE 0 END) AS imp_tot_uscita_conto_privati,
    SUM(CASE WHEN tp_trans.segno = "-" AND conto.id_tipo_conto = 3 THEN trans.importo ELSE 0 END) AS imp_tot_uscita_conto_famiglie,
    -- 11. Importo totale transato in entrata per tipologia di conto
    SUM(CASE WHEN tp_trans.segno = "+" AND conto.id_tipo_conto = 0 THEN trans.importo ELSE 0 END) AS imp_tot_entrata_conto_base,
    SUM(CASE WHEN tp_trans.segno = "+" AND conto.id_tipo_conto = 1 THEN trans.importo ELSE 0 END) AS imp_tot_entrata_conto_business,
    SUM(CASE WHEN tp_trans.segno = "+" AND conto.id_tipo_conto = 2 THEN trans.importo ELSE 0 END) AS imp_tot_entrata_conto_privati,
    SUM(CASE WHEN tp_trans.segno = "+" AND conto.id_tipo_conto = 3 THEN trans.importo ELSE 0 END) AS imp_tot_entrata_conto_famiglie
FROM conto
LEFT JOIN transazioni trans
	ON conto.id_conto = trans.id_conto
LEFT JOIN tipo_transazione tp_trans
	ON trans.id_tipo_trans = tp_trans.id_tipo_transazione
GROUP BY 1
ORDER BY 1;

-- Visualizzazione di controllo
SELECT * FROM info_trans_conto_tmp;

/*  ===================================================================================
	TABELLA FINALE DENORMALIZZATA
    
    NOTA: i valori NULL e 0 nella tabella finale sono distinti intenzionalmente.
    NULL = assenza di informazione; 0 = informazione disponibile con assenza di valore
    ===================================================================================*/
-- Eliminazione preventiva della tabella finale per garantire la corretta riesecuzione dello script
DROP TABLE IF EXISTS tab_denorm_ml;

-- Costruzione della tabella finale (tabella fisica)
CREATE TABLE tab_denorm_ml AS
SELECT
	*
FROM info_base_tmp base
LEFT JOIN info_transazioni_tmp trans
	USING(id_cliente)
LEFT JOIN info_conti_tmp conti
	USING(id_cliente)
LEFT JOIN info_trans_conto_tmp trans_conto
	USING(id_cliente);

-- Visualizzazione di controllo
SELECT * FROM tab_denorm_ml;
