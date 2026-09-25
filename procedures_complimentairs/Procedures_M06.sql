-- =====================================================================

-- Procedures_M06.sql

SET SERVEROUTPUT ON;

-- =====================================================================

-- P07 - Homogeneisation des valeurs manquantes

-- =====================================================================

CREATE OR REPLACE PROCEDURE P07_HOMOGENEISER_MISSINGVALUE (

    NOMTAB            IN VARCHAR2,

    ListeDesColonnes  IN VARCHAR2

)

IS

    v_table VARCHAR2(128);

    v_col   VARCHAR2(128);

    v_sql   VARCHAR2(32767);

    v_n     PLS_INTEGER;

BEGIN

    v_table := DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER(TRIM(NOMTAB)));

    v_n := REGEXP_COUNT(ListeDesColonnes, ',') + 1;

    FOR i IN 1..v_n LOOP

        v_col := DBMS_ASSERT.SIMPLE_SQL_NAME(

                    UPPER(TRIM(REGEXP_SUBSTR(ListeDesColonnes, '[^,]+', 1, i)))

                 );

        v_sql :=

            'UPDATE ' || v_table ||

            ' SET ' || v_col || ' = ''<?MISSINGVALUE>'' ' ||

            'WHERE ' || v_col || ' IS NULL ' ||

            '   OR UPPER(TRIM(' || v_col || ')) IN ' ||

            '      (''-'',''!'',''?'',''NULL'',''INEXISTANT'',''MISSINGVALUE'',''='')';

        EXECUTE IMMEDIATE v_sql;

    END LOOP;

    COMMIT;

END;

/

SHOW ERRORS;

-- =====================================================================

-- P08 - Detecter les valeurs repetees

-- Cree/recree la vue P08_LESVALEURSREPETEES

-- =====================================================================

-- Table de travail utilisée par P08/P09.
-- Elle remplace la vue créée dynamiquement dans l'ancienne version.
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE P08_LESVALEURSREPETEES PURGE';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN
            RAISE;
        END IF;
END;
/

CREATE TABLE P08_LESVALEURSREPETEES (
    VALEUR VARCHAR2(4000),
    NOMBRE NUMBER
);

CREATE OR REPLACE PROCEDURE P08_YATILDESVALEURSREPETEES (
    NOMTAB  IN VARCHAR2,
    COLONNE IN VARCHAR2
)
IS
    v_table VARCHAR2(128);
    v_col   VARCHAR2(128);
    v_norm  VARCHAR2(1000);
    v_sql   VARCHAR2(32767);
BEGIN
    v_table := DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER(TRIM(NOMTAB)));
    v_col   := DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER(TRIM(COLONNE)));

    v_norm :=
        'RTRIM(LTRIM(REGEXP_REPLACE(UPPER(' || v_col ||
        '), ''( ){2,}'', '' '')))';

    DELETE FROM P08_LESVALEURSREPETEES;

    v_sql :=
        'INSERT INTO P08_LESVALEURSREPETEES(VALEUR, NOMBRE) ' ||
        'SELECT ' || v_norm || ', COUNT(*) ' ||
        'FROM ' || v_table || ' ' ||
        'WHERE ' || v_col || ' IS NOT NULL ' ||
        '  AND INSTR(' || v_col || ', ''<?MISSINGVALUE>'') = 0 ' ||
        'GROUP BY ' || v_norm || ' ' ||
        'HAVING COUNT(*) > 1';

    EXECUTE IMMEDIATE v_sql;
    COMMIT;
END;
/
SHOW ERRORS;

-- =====================================================================

-- P09 - Signaler les valeurs en double avec <?D!ANOMALY>

-- P08 doit etre appelee juste avant pour la meme colonne.

-- =====================================================================

CREATE OR REPLACE PROCEDURE P09_SIGNALERLESVALEURSENDOUBLE (

    NOMTAB   IN VARCHAR2,

    COLONNE  IN VARCHAR2

)

IS

    v_table VARCHAR2(128);

    v_col   VARCHAR2(128);

    v_norm  VARCHAR2(1000);

    v_sql   VARCHAR2(32767);

BEGIN

    v_table := DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER(TRIM(NOMTAB)));

    v_col   := DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER(TRIM(COLONNE)));

    v_norm :=

        'RTRIM(LTRIM(REGEXP_REPLACE(UPPER(' || v_col ||

        '), ''( ){2,}'', '' '')))';

    v_sql :=

        'UPDATE ' || v_table ||

        ' SET ' || v_col || ' = ' || v_col || ' || '' <?D!ANOMALY>'' ' ||

        'WHERE ' || v_col || ' IS NOT NULL ' ||

        '  AND INSTR(' || v_col || ', ''<?D!ANOMALY>'') = 0 ' ||

        '  AND ' || v_norm || ' IN (SELECT VALEUR FROM P08_LESVALEURSREPETEES)';

    EXECUTE IMMEDIATE v_sql;

    COMMIT;

END;

/

SHOW ERRORS;

-- =====================================================================

-- P12 - Ajouter SMART_NEWKEY

-- =====================================================================

CREATE OR REPLACE PROCEDURE P12_AJOUTENEWKEY (

    NOMTAB IN VARCHAR2

)

IS

    v_table  VARCHAR2(128);

    v_exists NUMBER;

BEGIN

    v_table := DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER(TRIM(NOMTAB)));

    SELECT COUNT(*)

    INTO v_exists

    FROM USER_TAB_COLUMNS

    WHERE TABLE_NAME = v_table

      AND COLUMN_NAME = 'SMART_NEWKEY';

    IF v_exists = 0 THEN

        EXECUTE IMMEDIATE

            'ALTER TABLE ' || v_table || ' ADD SMART_NEWKEY NUMBER';

    END IF;

    -- ROWNUM est numerique. Ne jamais utiliser ROWID ici.

    EXECUTE IMMEDIATE

        'UPDATE ' || v_table || ' SET SMART_NEWKEY = ROWNUM';

    COMMIT;

END;

/

SHOW ERRORS;

-- =====================================================================

-- P11 - Verification des contraintes

--

-- Principe utilise par le MFB06 automatique :

--   - les noms recus sont les colonnes "originales" (COLxx_...)

--   - le marquage est ecrit dans la colonne correspondante COLxx_..._2

--   - 1 colonne  -> <?!1ANOMALY>

--   - 2 colonnes -> <?!2ANOMALY>

--   - 3 colonnes -> <?!3ANOMALY>

--

-- Les NULL / valeurs manquantes ne sont pas marques ici :

-- P07 les transforme ensuite en <?MISSINGVALUE>.

-- =====================================================================

CREATE OR REPLACE PROCEDURE P11_VERIFCONSTRAINTS (

    NOMTAB            IN VARCHAR2,

    LISTEDESCOLONNES  IN VARCHAR2,

    LISTECONTRAINTES  IN VARCHAR2

)

IS

    v_table       VARCHAR2(128);

    v_codes       VARCHAR2(4000);

    v_ncols       PLS_INTEGER;

    v_base1       VARCHAR2(128);

    v_base2       VARCHAR2(128);

    v_base3       VARCHAR2(128);

    v_col1        VARCHAR2(128);

    v_col2        VARCHAR2(128);

    v_col3        VARCHAR2(128);

    v_cond        VARCHAR2(32767);

    v_nomissing   VARCHAR2(4000);

    FUNCTION HAS_CODE(p_code VARCHAR2) RETURN BOOLEAN IS

    BEGIN

        RETURN INSTR('-' || v_codes || '-', '-' || UPPER(p_code) || '-') > 0;

    END;

    FUNCTION TARGET_COL(p_base VARCHAR2) RETURN VARCHAR2 IS

    BEGIN

        RETURN DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER(TRIM(p_base)) || '_2');

    END;

    FUNCTION NOT_MISSING(p_col VARCHAR2) RETURN VARCHAR2 IS

    BEGIN

        RETURN

            p_col || ' IS NOT NULL AND ' ||

            'UPPER(TRIM(' || p_col || ')) NOT IN ' ||

            '(''-'',''!'',''?'',''NULL'',''INEXISTANT'',''MISSINGVALUE'',''='') ' ||

            'AND INSTR(' || p_col || ', ''<?MISSINGVALUE>'') = 0';

    END;

    PROCEDURE LOG_SQL(p_sql VARCHAR2) IS

    BEGIN

        BEGIN

            EXECUTE IMMEDIATE

                'INSERT INTO META50_DR_ANOMALYSELECTUPDATE ' ||

                '(SELECT_UPDATE_OPERATIONS) VALUES (:1)'

            USING SUBSTR(p_sql, 1, 2000);

        EXCEPTION

            WHEN OTHERS THEN

                NULL;

        END;

    END;

    PROCEDURE MARK_ONE (

        p_col       VARCHAR2,

        p_condition VARCHAR2,

        p_marker    VARCHAR2

    )

    IS

        v_sql VARCHAR2(32767);

    BEGIN

        v_sql :=

            'UPDATE ' || v_table ||

            ' SET ' || p_col || ' = ' || p_col || ' || '' ' || p_marker || ''' ' ||

            'WHERE (' || p_condition || ') ' ||

            '  AND ' || p_col || ' IS NOT NULL ' ||

            '  AND INSTR(' || p_col || ', ''' || p_marker || ''') = 0';

        LOG_SQL(v_sql);

        EXECUTE IMMEDIATE v_sql;

    END;

BEGIN

    v_table := DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER(TRIM(NOMTAB)));

    v_codes := UPPER(REPLACE(TRIM(LISTECONTRAINTES), ' ', ''));

    v_ncols := REGEXP_COUNT(LISTEDESCOLONNES, ',') + 1;

    v_base1 := DBMS_ASSERT.SIMPLE_SQL_NAME(

                   UPPER(TRIM(REGEXP_SUBSTR(LISTEDESCOLONNES, '[^,]+', 1, 1)))

               );

    v_col1 := TARGET_COL(v_base1);

    IF v_ncols >= 2 THEN

        v_base2 := DBMS_ASSERT.SIMPLE_SQL_NAME(

                       UPPER(TRIM(REGEXP_SUBSTR(LISTEDESCOLONNES, '[^,]+', 1, 2)))

                   );

        v_col2 := TARGET_COL(v_base2);

    END IF;

    IF v_ncols >= 3 THEN

        v_base3 := DBMS_ASSERT.SIMPLE_SQL_NAME(

                       UPPER(TRIM(REGEXP_SUBSTR(LISTEDESCOLONNES, '[^,]+', 1, 3)))

                   );

        v_col3 := TARGET_COL(v_base3);

    END IF;

    -- ================================================================

    -- CONTRAINTES INTRACOLONNE

    -- ================================================================

    IF v_ncols = 1 THEN

        v_nomissing := NOT_MISSING(v_col1);

        -- NS0001 : espaces superflus / debut / fin

        IF HAS_CODE('NS0001') THEN

            v_cond :=

                v_nomissing ||

                ' AND ' || v_col1 ||

                ' <> TRIM(REGEXP_REPLACE(' || v_col1 || ', ''( ){2,}'', '' ''))';

            MARK_ONE(v_col1, v_cond, '<?!1ANOMALY>');

        END IF;

        -- NS3001 : civilite

        IF HAS_CODE('NS3001') THEN

            v_cond :=

                v_nomissing ||

                ' AND ' || v_col1 ||

                ' NOT IN (''Madame'',''Mademoiselle'',''Monsieur'')';

            MARK_ONE(v_col1, v_cond, '<?!1ANOMALY>');

        END IF;

        -- NS2510 : alphabetique + espace + tiret + apostrophe

        IF HAS_CODE('NS2510') THEN

            v_cond :=

                v_nomissing ||

                ' AND NOT REGEXP_LIKE(' || v_col1 ||

                ', ''^[[:alpha:]'' -]+$'')';

            MARK_ONE(v_col1, v_cond, '<?!1ANOMALY>');

        END IF;

        -- NS2515 : alphabetique + espace + tiret

        IF HAS_CODE('NS2515') THEN

            v_cond :=

                v_nomissing ||

                ' AND NOT REGEXP_LIKE(' || v_col1 ||

                ', ''^[[:alpha:] -]+$'')';

            MARK_ONE(v_col1, v_cond, '<?!1ANOMALY>');

        END IF;

        -- NS2500 : prenom alphabetique avec tiret/apostrophe/espace

        IF HAS_CODE('NS2500') THEN

            v_cond :=

                v_nomissing ||

                ' AND NOT REGEXP_LIKE(' || v_col1 ||

                ', ''^[[:alpha:]'' -]+$'')';

            MARK_ONE(v_col1, v_cond, '<?!1ANOMALY>');

        END IF;

        -- NS2600 : majuscules

        IF HAS_CODE('NS2600') THEN

            v_cond :=

                v_nomissing ||

                ' AND ' || v_col1 || ' <> UPPER(' || v_col1 || ')';

            MARK_ONE(v_col1, v_cond, '<?!1ANOMALY>');

        END IF;

        -- NS2605 : INITCAP

        IF HAS_CODE('NS2605') THEN

            v_cond :=

                v_nomissing ||

                ' AND ' || v_col1 || ' <> INITCAP(' || v_col1 || ')';

            MARK_ONE(v_col1, v_cond, '<?!1ANOMALY>');

        END IF;

        -- NS2700 : repetition d'une meme lettre au moins 3 fois

        IF HAS_CODE('NS2700') THEN

            v_cond :=

                v_nomissing ||

                ' AND REGEXP_LIKE(UPPER(' || v_col1 || '), ' ||

                '''A{3,}|B{3,}|C{3,}|D{3,}|E{3,}|F{3,}|G{3,}|H{3,}|I{3,}|J{3,}|K{3,}|L{3,}|M{3,}|N{3,}|O{3,}|P{3,}|Q{3,}|R{3,}|S{3,}|T{3,}|U{3,}|V{3,}|W{3,}|X{3,}|Y{3,}|Z{3,}'')';

            MARK_ONE(v_col1, v_cond, '<?!1ANOMALY>');

        END IF;

        -- NS3900 : categorie 1..9

        IF HAS_CODE('NS3900') THEN

            v_cond :=

                v_nomissing ||

                ' AND NOT REGEXP_LIKE(' || v_col1 || ', ''^[1-9]$'')';

            MARK_ONE(v_col1, v_cond, '<?!1ANOMALY>');

        END IF;

        -- NS4000 : numero de voie, eventuellement BIS/TER

        IF HAS_CODE('NS4000') THEN

            v_cond :=

                v_nomissing ||

                ' AND NOT REGEXP_LIKE(UPPER(' || v_col1 ||

                '), ''^[0-9]+([[:space:]]+(BIS|TER))?$'')';

            MARK_ONE(v_col1, v_cond, '<?!1ANOMALY>');

        END IF;

        -- NS4010 : type de voie

        IF HAS_CODE('NS4010') THEN

            v_cond :=

                v_nomissing ||

                ' AND NOT REGEXP_LIKE(UPPER(' || v_col1 ||

                '), ''^(BOULEVARD|AVENUE|RUE|PLACE|IMPASSE|QUAI|SQUARE|PONT)[[:space:]].+$'')';

            MARK_ONE(v_col1, v_cond, '<?!1ANOMALY>');

        END IF;

        -- NS4050 : code postal 5 chiffres

        IF HAS_CODE('NS4050') THEN

            v_cond :=

                v_nomissing ||

                ' AND NOT REGEXP_LIKE(' || v_col1 || ', ''^[0-9]{5}$'')';

            MARK_ONE(v_col1, v_cond, '<?!1ANOMALY>');

        END IF;

        -- NS5000 : email

        IF HAS_CODE('NS5000') THEN

            v_cond :=

                v_nomissing ||

                ' AND NOT REGEXP_LIKE(' || v_col1 ||

                ', ''^[A-Za-z]+[A-Za-z0-9.]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$'')';

            MARK_ONE(v_col1, v_cond, '<?!1ANOMALY>');

        END IF;

        -- NS5100 : telephone francais au format international

        IF HAS_CODE('NS5100') THEN

            v_cond :=

                v_nomissing ||

                ' AND NOT REGEXP_LIKE(' || v_col1 ||

                ', ''^(([\+]|[0]{2})([3]{2}))[1-9]\([0-9]{8})$'')';

            MARK_ONE(v_col1, v_cond, '<?!1ANOMALY>');

        END IF;

        -- ND0001 / ND0002 : date texte YYYY-MM-DD

        IF HAS_CODE('ND0001') OR HAS_CODE('ND0002') THEN

            v_cond :=

                v_nomissing ||

                ' AND NOT REGEXP_LIKE(' || v_col1 ||

                ', ''^[0-9]{4}-(0[1-9]|1[0-2])-([0-2][0-9]|3[0-1])$'')';

            MARK_ONE(v_col1, v_cond, '<?!1ANOMALY>');

        END IF;

        -- NS3102 : genre F/M

        IF HAS_CODE('NS3102') THEN

            v_cond :=

                v_nomissing ||

                ' AND NOT REGEXP_LIKE(UPPER(' || v_col1 || '), ''^[FM]$'')';

            MARK_ONE(v_col1, v_cond, '<?!1ANOMALY>');

        END IF;

        -- NS3500 : groupe sanguin

        IF HAS_CODE('NS3500') THEN

            v_cond :=

                v_nomissing ||

                ' AND NOT REGEXP_LIKE(UPPER(' || v_col1 ||

                '), ''^(A|B|AB|O)[+-]$'')';

            MARK_ONE(v_col1, v_cond, '<?!1ANOMALY>');

        END IF;

    -- ================================================================

    -- CONTRAINTES INTERCOLONNES A 2 COLONNES

    -- ================================================================

    ELSIF v_ncols = 2 THEN

        IF HAS_CODE('NS9200') THEN

            -- Source MFB06 :

            -- (Madame + 2/4/6) OU (Monsieur + 1/3/5)

            v_cond :=

                NOT_MISSING(v_col1) || ' AND ' || NOT_MISSING(v_col2) ||

                ' AND NOT ((' || v_col1 || ' = ''Madame'' AND ' ||

                    v_col2 || ' IN (''2'',''4'',''6'')) OR (' ||

                    v_col1 || ' = ''Monsieur'' AND ' ||

                    v_col2 || ' IN (''1'',''3'',''5'')))';

            MARK_ONE(v_col1, v_cond, '<?!2ANOMALY>');

            MARK_ONE(v_col2, v_cond, '<?!2ANOMALY>');

        END IF;

        IF HAS_CODE('NS9201') THEN

            -- Date naissance < date premier contact

            v_cond :=

                NOT_MISSING(v_col1) || ' AND ' || NOT_MISSING(v_col2) ||

                ' AND REGEXP_LIKE(' || v_col1 ||

                ', ''^[0-9]{4}-[0-9]{2}-[0-9]{2}$'')' ||

                ' AND REGEXP_LIKE(' || v_col2 ||

                ', ''^[0-9]{4}-[0-9]{2}-[0-9]{2}$'')' ||

                ' AND TO_DATE(' || v_col1 || ', ''YYYY-MM-DD'') >= ' ||

                    'TO_DATE(' || v_col2 || ', ''YYYY-MM-DD'')';

            MARK_ONE(v_col1, v_cond, '<?!2ANOMALY>');

            MARK_ONE(v_col2, v_cond, '<?!2ANOMALY>');

        END IF;

    -- ================================================================

    -- CONTRAINTE INTERCOLONNES A 3 COLONNES

    -- ================================================================

    ELSIF v_ncols = 3 THEN

        IF HAS_CODE('NS9300') THEN

            -- Regle visible dans MFB06 :

            -- interdit Mademoiselle + AFRICAINE + PARIS

            v_cond :=

                NOT_MISSING(v_col1) || ' AND ' ||

                NOT_MISSING(v_col2) || ' AND ' ||

                NOT_MISSING(v_col3) ||

                ' AND ' || v_col1 || ' = ''Mademoiselle''' ||

                ' AND UPPER(' || v_col2 || ') = ''AFRICAINE''' ||

                ' AND UPPER(' || v_col3 || ') = ''PARIS''';

            MARK_ONE(v_col1, v_cond, '<?!3ANOMALY>');

            MARK_ONE(v_col2, v_cond, '<?!3ANOMALY>');

            MARK_ONE(v_col3, v_cond, '<?!3ANOMALY>');

        END IF;

    END IF;

    COMMIT;

END;

/

SHOW ERRORS;

-- =====================================================================

-- P13 - Diagnostic global par colonne

-- COMPORTEMENT INFERE a partir du schema META51_DR_GOLBALDIAGNOSTICS.

-- =====================================================================

CREATE OR REPLACE PROCEDURE P13_GLOBALDIAGNOSTICS (
    NOMTAB           IN VARCHAR2,
    ListeDesColonnes IN VARCHAR2
)
IS
    v_table       VARCHAR2(128);
    v_col         VARCHAR2(128);
    v_n           PLS_INTEGER;

    n_total       NUMBER;
    n_invalid     NUMBER;
    n_valid       NUMBER;
    n_missing     NUMBER;
    n_existing    NUMBER;
    n_a1          NUMBER;
    n_a2          NUMBER;
    n_a3          NUMBER;
    n_ad          NUMBER;
    n_distinct    NUMBER;

    n_upper       NUMBER;
    n_lower       NUMBER;
    n_initcap     NUMBER;
    lg_min        NUMBER;
    lg_max        NUMBER;
    lg_avg        NUMBER;

    r_invalid     NUMBER;
    r_valid       NUMBER;
    r_missing     NUMBER;
    r_existing    NUMBER;
    r_anomaly     NUMBER;
BEGIN
    v_table := DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER(TRIM(NOMTAB)));
    v_n := REGEXP_COUNT(ListeDesColonnes, ',') + 1;

    DELETE FROM META51_DR_GOLBALDIAGNOSTICS
    WHERE NOMTAB = v_table;

    FOR i IN 1..v_n LOOP
        v_col := DBMS_ASSERT.SIMPLE_SQL_NAME(
            UPPER(TRIM(REGEXP_SUBSTR(ListeDesColonnes, '[^,]+', 1, i)))
        );

        EXECUTE IMMEDIATE
            'SELECT COUNT(*) FROM ' || v_table
        INTO n_total;

        EXECUTE IMMEDIATE
            'SELECT COUNT(*) FROM ' || v_table ||
            ' WHERE INSTR(NVL(' || v_col || ', ''''), ''<?MISSINGVALUE>'') > 0'
        INTO n_missing;

        EXECUTE IMMEDIATE
            'SELECT COUNT(*) FROM ' || v_table ||
            ' WHERE INSTR(NVL(' || v_col || ', ''''), ''<?!1ANOMALY>'') > 0'
        INTO n_a1;

        EXECUTE IMMEDIATE
            'SELECT COUNT(*) FROM ' || v_table ||
            ' WHERE INSTR(NVL(' || v_col || ', ''''), ''<?!2ANOMALY>'') > 0'
        INTO n_a2;

        EXECUTE IMMEDIATE
            'SELECT COUNT(*) FROM ' || v_table ||
            ' WHERE INSTR(NVL(' || v_col || ', ''''), ''<?!3ANOMALY>'') > 0'
        INTO n_a3;

        EXECUTE IMMEDIATE
            'SELECT COUNT(*) FROM ' || v_table ||
            ' WHERE INSTR(NVL(' || v_col || ', ''''), ''<?D!ANOMALY>'') > 0'
        INTO n_ad;

        EXECUTE IMMEDIATE
            'SELECT COUNT(*) FROM ' || v_table ||
            ' WHERE INSTR(NVL(' || v_col || ', ''''), ''<?MISSINGVALUE>'') > 0 ' ||
            '    OR INSTR(NVL(' || v_col || ', ''''), ''<?!1ANOMALY>'') > 0 ' ||
            '    OR INSTR(NVL(' || v_col || ', ''''), ''<?!2ANOMALY>'') > 0 ' ||
            '    OR INSTR(NVL(' || v_col || ', ''''), ''<?!3ANOMALY>'') > 0 ' ||
            '    OR INSTR(NVL(' || v_col || ', ''''), ''<?D!ANOMALY>'') > 0'
        INTO n_invalid;

        n_valid    := n_total - n_invalid;
        n_existing := n_total - n_missing;

        EXECUTE IMMEDIATE
            'SELECT COUNT(DISTINCT ' || v_col || ') FROM ' || v_table
        INTO n_distinct;

        EXECUTE IMMEDIATE
            'SELECT ' ||
            'NVL(SUM(CASE WHEN ' || v_col || ' IS NOT NULL AND ' ||
                v_col || ' = UPPER(' || v_col || ') THEN 1 ELSE 0 END),0), ' ||
            'NVL(SUM(CASE WHEN ' || v_col || ' IS NOT NULL AND ' ||
                v_col || ' = LOWER(' || v_col || ') THEN 1 ELSE 0 END),0), ' ||
            'NVL(SUM(CASE WHEN ' || v_col || ' IS NOT NULL AND ' ||
                v_col || ' = INITCAP(' || v_col || ') THEN 1 ELSE 0 END),0), ' ||
            'NVL(MIN(LENGTH(' || v_col || ')),0), ' ||
            'NVL(MAX(LENGTH(' || v_col || ')),0), ' ||
            'NVL(AVG(LENGTH(' || v_col || ')),0) ' ||
            'FROM ' || v_table
        INTO n_upper, n_lower, n_initcap, lg_min, lg_max, lg_avg;

        IF n_total = 0 THEN
            r_invalid  := 0;
            r_valid    := 0;
            r_missing  := 0;
            r_existing := 0;
            r_anomaly  := 0;
        ELSE
            r_invalid  := ROUND(100 * n_invalid  / n_total, 2);
            r_valid    := ROUND(100 * n_valid    / n_total, 2);
            r_missing  := ROUND(100 * n_missing  / n_total, 2);
            r_existing := ROUND(100 * n_existing / n_total, 2);
            r_anomaly  := ROUND(100 * n_invalid  / n_total, 2);
        END IF;

        -- INSERT STATIQUE :
        -- on évite complètement EXECUTE IMMEDIATE ... USING ici.
        INSERT INTO META51_DR_GOLBALDIAGNOSTICS (
            DIAGNOSTICDATE,
            USERNAME,
            NOMTAB,
            COLNAME,
            NBRVALUES,
            NBRINVALIDVALUES,
            NBRVALIDVALUES,
            NBRMISSINGVALUES,
            NBREXISTINGVALUES,
            NBRANOMALIES1,
            NBRANOMALIES2,
            NBRANOMALIES3,
            NBRANOMALIESD,
            DISTINCTVALUES,
            INVALIDValuesRate,
            VALIDValuesRate,
            MissingValuesRate,
            ExistingValuesRate,
            AnomaliesRate,
            LISTOFCONSTRAINTS,
            NBRUPPER,
            NBRLOWER,
            NBRINITCAP,
            LGMIN,
            LGMAX,
            LGAVG
        )
        VALUES (
            SYSDATE,
            USER,
            v_table,
            v_col,
            n_total,
            n_invalid,
            n_valid,
            n_missing,
            n_existing,
            n_a1,
            n_a2,
            n_a3,
            n_ad,
            n_distinct,
            r_invalid,
            r_valid,
            r_missing,
            r_existing,
            r_anomaly,
            NULL,
            n_upper,
            n_lower,
            n_initcap,
            lg_min,
            lg_max,
            lg_avg
        );
    END LOOP;

    COMMIT;
END;
/
SHOW ERRORS;


-- =====================================================================

-- P14 - Scoring ligne par ligne

--

-- Le score est un NOMBRE DE CELLULES contenant le type d'anomalie.

-- SCORE_TOTALANOMALIES compte chaque cellule invalide une seule fois.

-- =====================================================================

CREATE OR REPLACE PROCEDURE P14_SCORINGDATA (

    NOMTAB            IN VARCHAR2,

    TYPEANOMALIE      IN VARCHAR2,

    ListeDesColonnes  IN VARCHAR2

)

IS

    v_table       VARCHAR2(128);

    v_type        VARCHAR2(50);

    v_score_col   VARCHAR2(128);

    v_col         VARCHAR2(128);

    v_n           PLS_INTEGER;

    v_exists      NUMBER;

    v_expr        VARCHAR2(32767) := '0';

    v_condition   VARCHAR2(32767);

BEGIN

    v_table := DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER(TRIM(NOMTAB)));

    v_type  := UPPER(TRIM(TYPEANOMALIE));

    CASE v_type

        WHEN 'MISSINGVAL'     THEN v_score_col := 'SCORE_MISSINGVAL';

        WHEN '1ANOMALY'       THEN v_score_col := 'SCORE_1ANOMALY';

        WHEN '2ANOMALY'       THEN v_score_col := 'SCORE_2ANOMALY';

        WHEN '3ANOMALY'       THEN v_score_col := 'SCORE_3ANOMALY';

        WHEN 'DANOMALY'       THEN v_score_col := 'SCORE_DANOMALY';

        WHEN 'TOTALANOMALIES' THEN v_score_col := 'SCORE_TOTALANOMALIES';

        ELSE

            RAISE_APPLICATION_ERROR(

                -20001,

                'TYPEANOMALIE inconnu : ' || TYPEANOMALIE

            );

    END CASE;

    SELECT COUNT(*)

    INTO v_exists

    FROM USER_TAB_COLUMNS

    WHERE TABLE_NAME = v_table

      AND COLUMN_NAME = v_score_col;

    IF v_exists = 0 THEN

        EXECUTE IMMEDIATE

            'ALTER TABLE ' || v_table ||

            ' ADD ' || v_score_col || ' NUMBER DEFAULT 0';

    END IF;

    v_n := REGEXP_COUNT(ListeDesColonnes, ',') + 1;

    FOR i IN 1..v_n LOOP

        v_col := DBMS_ASSERT.SIMPLE_SQL_NAME(

                    UPPER(TRIM(REGEXP_SUBSTR(ListeDesColonnes, '[^,]+', 1, i)))

                 );

        -- La cle technique n'est pas une cellule metier a scorer.

        IF v_col <> 'SMART_NEWKEY_2' AND v_col <> 'SMART_NEWKEY' THEN

            CASE v_type

                WHEN 'MISSINGVAL' THEN

                    v_condition :=

                        'INSTR(NVL(' || v_col || ', ''''), ''<?MISSINGVALUE>'') > 0';

                WHEN '1ANOMALY' THEN

                    v_condition :=

                        'INSTR(NVL(' || v_col || ', ''''), ''<?!1ANOMALY>'') > 0';

                WHEN '2ANOMALY' THEN

                    v_condition :=

                        'INSTR(NVL(' || v_col || ', ''''), ''<?!2ANOMALY>'') > 0';

                WHEN '3ANOMALY' THEN

                    v_condition :=

                        'INSTR(NVL(' || v_col || ', ''''), ''<?!3ANOMALY>'') > 0';

                WHEN 'DANOMALY' THEN

                    v_condition :=

                        'INSTR(NVL(' || v_col || ', ''''), ''<?D!ANOMALY>'') > 0';

                WHEN 'TOTALANOMALIES' THEN

                    v_condition :=

                        '(INSTR(NVL(' || v_col || ', ''''), ''<?MISSINGVALUE>'') > 0 OR ' ||

                        ' INSTR(NVL(' || v_col || ', ''''), ''<?!1ANOMALY>'') > 0 OR ' ||

                        ' INSTR(NVL(' || v_col || ', ''''), ''<?!2ANOMALY>'') > 0 OR ' ||

                        ' INSTR(NVL(' || v_col || ', ''''), ''<?!3ANOMALY>'') > 0 OR ' ||

                        ' INSTR(NVL(' || v_col || ', ''''), ''<?D!ANOMALY>'') > 0)';

            END CASE;

            v_expr :=

                v_expr ||

                ' + CASE WHEN ' || v_condition ||

                ' THEN 1 ELSE 0 END';

        END IF;

    END LOOP;

    EXECUTE IMMEDIATE

        'UPDATE ' || v_table ||

        ' SET ' || v_score_col || ' = ' || v_expr;

    COMMIT;

END;

/

SHOW ERRORS;

-- =====================================================================

-- SMARTDATA

-- COMPORTEMENT INFERE.

--

-- Le MFB06 indique que SMARTDATA doit remplir SMARTDATA_SQLORDERS avec

-- des ordres SQL a executer. Cette version genere les ordres principaux

-- du workflow automatique deja visible dans MFB06.

-- =====================================================================

CREATE OR REPLACE PROCEDURE SMARTDATA (
    NOMTAB IN VARCHAR2
)
IS
    v_table VARCHAR2(128);

    PROCEDURE ADD_ORDER(p_query VARCHAR2) IS
    BEGIN
        INSERT INTO SMARTDATA_SQLORDERS (NumSmart, Query)
        VALUES (id_smart.NEXTVAL, SUBSTR(p_query, 1, 2000));
    END;
BEGIN
    v_table := DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER(TRIM(NOMTAB)));

    IF v_table <> 'CLIENTS' THEN
        RAISE_APPLICATION_ERROR(
            -20020,
            'SMARTDATA reconstruit ici uniquement le workflow CLIENTS de MFB06.'
        );
    END IF;

    ADD_ORDER('EXEC P11_VERIFCONSTRAINTS(''VISU_ANOMALIES_CLIENTS'',''COL01_CODCLI'',''NS0001'');');
    ADD_ORDER('EXEC P11_VERIFCONSTRAINTS(''VISU_ANOMALIES_CLIENTS'',''COL02_CIVCLI'',''NS0001-NS3001'');');
    ADD_ORDER('EXEC P11_VERIFCONSTRAINTS(''VISU_ANOMALIES_CLIENTS'',''COL03_NOMCLI'',''NS0001-NS2510-NS2600-NS2700'');');
    ADD_ORDER('EXEC P11_VERIFCONSTRAINTS(''VISU_ANOMALIES_CLIENTS'',''COL04_PRENCLI'',''NS0001-NS2500-NS2605-NS2700'');');
    ADD_ORDER('EXEC P11_VERIFCONSTRAINTS(''VISU_ANOMALIES_CLIENTS'',''COL05_CATCLI'',''NS0001-NS3900'');');
    ADD_ORDER('EXEC P11_VERIFCONSTRAINTS(''VISU_ANOMALIES_CLIENTS'',''COL06_ADNCLI'',''NS0001-NS4000'');');
    ADD_ORDER('EXEC P11_VERIFCONSTRAINTS(''VISU_ANOMALIES_CLIENTS'',''COL07_ADRCLI'',''NS0001-NS2600-NS2700-NS4010'');');
    ADD_ORDER('EXEC P11_VERIFCONSTRAINTS(''VISU_ANOMALIES_CLIENTS'',''COL08_CPCLI'',''NS0001-NS4050'');');
    ADD_ORDER('EXEC P11_VERIFCONSTRAINTS(''VISU_ANOMALIES_CLIENTS'',''COL09_VILCLI'',''NS0001-NS2510-NS2600-NS2700'');');
    ADD_ORDER('EXEC P11_VERIFCONSTRAINTS(''VISU_ANOMALIES_CLIENTS'',''COL10_PAYSCLI'',''NS0001-NS2515-NS2600-NS2700'');');
    ADD_ORDER('EXEC P11_VERIFCONSTRAINTS(''VISU_ANOMALIES_CLIENTS'',''COL11_MAILCLI'',''NS0001-NS5000'');');
    ADD_ORDER('EXEC P11_VERIFCONSTRAINTS(''VISU_ANOMALIES_CLIENTS'',''COL12_TELCLI'',''NS0001-NS5100'');');
    ADD_ORDER('EXEC P11_VERIFCONSTRAINTS(''VISU_ANOMALIES_CLIENTS'',''COL13_DATNAISCLI'',''NS0001-ND0001'');');
    ADD_ORDER('EXEC P11_VERIFCONSTRAINTS(''VISU_ANOMALIES_CLIENTS'',''COL14_DPREMCONTACTCLI'',''NS0001-ND0002'');');
    ADD_ORDER('EXEC P11_VERIFCONSTRAINTS(''VISU_ANOMALIES_CLIENTS'',''COL15_OBSCLI'',''NS0001'');');
    ADD_ORDER('EXEC P11_VERIFCONSTRAINTS(''VISU_ANOMALIES_CLIENTS'',''COL16_REMCLI'',''NS0001'');');
    ADD_ORDER('EXEC P11_VERIFCONSTRAINTS(''VISU_ANOMALIES_CLIENTS'',''COL17_GENRECLI'',''NS0001-NS3102'');');
    ADD_ORDER('EXEC P11_VERIFCONSTRAINTS(''VISU_ANOMALIES_CLIENTS'',''COL18_GSCLI'',''NS0001-NS3500'');');
    ADD_ORDER('EXEC P11_VERIFCONSTRAINTS(''VISU_ANOMALIES_CLIENTS'',''COL19_KEYWORDSCLI'',''NS0001-NS2600'');');

    ADD_ORDER('EXEC P08_YATILDESVALEURSREPETEES(''VISU_ANOMALIES_CLIENTS'',''COL01_CODCLI_2'');');
    ADD_ORDER('EXEC P09_SIGNALERLESVALEURSENDOUBLE(''VISU_ANOMALIES_CLIENTS'',''COL01_CODCLI_2'');');
    ADD_ORDER('EXEC P08_YATILDESVALEURSREPETEES(''VISU_ANOMALIES_CLIENTS'',''COL11_MAILCLI_2'');');
    ADD_ORDER('EXEC P09_SIGNALERLESVALEURSENDOUBLE(''VISU_ANOMALIES_CLIENTS'',''COL11_MAILCLI_2'');');

    ADD_ORDER('EXEC P11_VERIFCONSTRAINTS(''VISU_ANOMALIES_CLIENTS'',''COL02_CIVCLI,COL05_CATCLI'',''NS9200'');');
    ADD_ORDER('EXEC P11_VERIFCONSTRAINTS(''VISU_ANOMALIES_CLIENTS'',''COL13_DATNAISCLI,COL14_DPREMCONTACTCLI'',''NS9201'');');
    ADD_ORDER('EXEC P11_VERIFCONSTRAINTS(''VISU_ANOMALIES_CLIENTS'',''COL02_CIVCLI,COL03_NOMCLI,COL09_VILCLI'',''NS9300'');');

    ADD_ORDER('EXEC P07_HOMOGENEISER_MISSINGVALUE(''VISU_ANOMALIES_CLIENTS'',''COL01_CODCLI_2,COL02_CIVCLI_2,COL03_NOMCLI_2,COL04_PRENCLI_2,COL05_CATCLI_2,COL06_ADNCLI_2,COL07_ADRCLI_2,COL08_CPCLI_2,COL09_VILCLI_2,COL10_PAYSCLI_2,COL11_MAILCLI_2,COL12_TELCLI_2,COL13_DATNAISCLI_2,COL14_DPREMCONTACTCLI_2,COL15_OBSCLI_2,COL16_REMCLI_2,COL17_GENRECLI_2,COL18_GSCLI_2,COL19_KEYWORDSCLI_2'');');

    COMMIT;
END;
/
SHOW ERRORS;

-- =====================================================================

-- ELIMINEDOUBSIMIL

-- PLACEHOLDER DE COMPATIBILITE - COMPORTEMENT ORIGINAL NON FOURNI.

--

-- MFB06 montre seulement l'appel et un exemple de sortie, puis effectue

-- ensuite une correction MANUELLE des lignes a supprimer.

-- Pour ne pas inventer une suppression automatique dangereuse, cette

-- version NE SUPPRIME AUCUNE LIGNE.

-- =====================================================================

CREATE OR REPLACE PROCEDURE ELIMINEDOUBSIMIL (

    NOMTAB              IN VARCHAR2,

    COLONNES_COMPARAISON IN VARCHAR2,

    COLONNES_AFFICHAGE   IN VARCHAR2,

    SEUIL1               IN NUMBER,

    SEUIL2               IN NUMBER

)

IS

BEGIN

    DBMS_OUTPUT.PUT_LINE(

        'ELIMINEDOUBSIMIL : comportement original non fourni.'

    );

    DBMS_OUTPUT.PUT_LINE(

        'Aucune suppression automatique effectuee. MFB06 realise ensuite une correction manuelle.'

    );

    DBMS_OUTPUT.PUT_LINE(

        'Table=' || NOMTAB ||

        ' ; comparaison=' || COLONNES_COMPARAISON ||

        ' ; seuils=' || SEUIL1 || '/' || SEUIL2

    );

END;

/

SHOW ERRORS;

-- =====================================================================

-- VERIFICATION DES OBJETS

-- =====================================================================

SELECT object_name, object_type, status

FROM user_objects

WHERE object_name IN (

    'P07_HOMOGENEISER_MISSINGVALUE',

    'P08_YATILDESVALEURSREPETEES',

    'P09_SIGNALERLESVALEURSENDOUBLE',

    'P11_VERIFCONSTRAINTS',

    'P12_AJOUTENEWKEY',

    'P13_GLOBALDIAGNOSTICS',

    'P14_SCORINGDATA',

    'SMARTDATA',

    'ELIMINEDOUBSIMIL'

)

ORDER BY object_name;

-- =====================================================================

-- TEST CONTROLE DE P12

-- A executer seulement si CLIENTS existe.

-- =====================================================================

BEGIN

    EXECUTE IMMEDIATE 'DROP TABLE CLIENTS_TEST_FOR_MFB06 PURGE';

EXCEPTION

    WHEN OTHERS THEN

        IF SQLCODE != -942 THEN

            RAISE;

        END IF;

END;

/

CREATE TABLE CLIENTS_TEST_FOR_MFB06 AS

SELECT * FROM CLIENTS WHERE ROWNUM <= 5;

EXEC P12_AJOUTENEWKEY('CLIENTS_TEST_FOR_MFB06');

SELECT SMART_NEWKEY, CODCLI

FROM CLIENTS_TEST_FOR_MFB06

ORDER BY SMART_NEWKEY;

DROP TABLE CLIENTS_TEST_FOR_MFB06 PURGE;

-- =====================================================================

-- APRES EXECUTION DE MFB06 :

-- calcul du QUALI-SCORE global sur les 19 colonnes metier.

--

-- Formule du TP :

-- (nombre total de cellules - nombre de cellules invalides)

-- / nombre total de cellules * 100

-- =====================================================================

-- SELECT

--     COUNT(*) * 19 AS NOMBRE_TOTAL_CELLULES,

--     SUM(SCORE_TOTALANOMALIES) AS NOMBRE_CELLULES_INVALIDES,

--     ROUND(

--         100 * (COUNT(*) * 19 - SUM(SCORE_TOTALANOMALIES))

--         / NULLIF(COUNT(*) * 19, 0),

--         2

--     ) AS QUALI_SCORE

-- FROM VISU_ANOMALIES_CLIENTS;


PROMPT ============================================================
PROMPT VERIFICATION FINALE DES 9 PROCEDURES
PROMPT ============================================================

SELECT object_name, status
FROM user_objects
WHERE object_name IN (
    'P07_HOMOGENEISER_MISSINGVALUE',
    'P08_YATILDESVALEURSREPETEES',
    'P09_SIGNALERLESVALEURSENDOUBLE',
    'P11_VERIFCONSTRAINTS',
    'P12_AJOUTENEWKEY',
    'P13_GLOBALDIAGNOSTICS',
    'P14_SCORINGDATA',
    'SMARTDATA',
    'ELIMINEDOUBSIMIL'
)
ORDER BY object_name;
