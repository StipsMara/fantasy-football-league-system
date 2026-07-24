-- Fantasy Football League — Database Schema
-- PostgreSQL DDL reconstructed from the project's ERA model (see docs/era_diagram.png).
-- NOTE: this is a schema reconstruction based on the documented entity/attribute list —
-- replace with the actual DataGrip DDL export for a byte-exact match with the original database.

CREATE TABLE korisnik (
    id_korisnika        SERIAL PRIMARY KEY,
    e_mail              VARCHAR(100) NOT NULL UNIQUE,
    lozinka             VARCHAR(255) NOT NULL,
    ime                 VARCHAR(50) NOT NULL,
    prezime             VARCHAR(50) NOT NULL,
    datum_registracije  DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE liga (
    id_lige         SERIAL PRIMARY KEY,
    naziv_lige      VARCHAR(100) NOT NULL,
    sezona          VARCHAR(20) NOT NULL,
    datum_kreiranja DATE NOT NULL DEFAULT CURRENT_DATE,
    id_korisnika    INTEGER REFERENCES korisnik(id_korisnika)
);

CREATE TABLE kolo (
    id_kolo         SERIAL PRIMARY KEY,
    broj_kola       INTEGER NOT NULL,
    datum_pocetka   DATE NOT NULL,
    datum_zavrsetka DATE NOT NULL,
    id_lige         INTEGER NOT NULL REFERENCES liga(id_lige)
);

CREATE TABLE nog_klub (
    id_kluba    SERIAL PRIMARY KEY,
    naziv_kluba VARCHAR(100) NOT NULL,
    drzava      VARCHAR(50) NOT NULL
);

CREATE TABLE pozicija (
    id_pozicije    SERIAL PRIMARY KEY,
    naziv_pozicije VARCHAR(30) NOT NULL
);

CREATE TABLE igrac (
    id_igraca   SERIAL PRIMARY KEY,
    id_kluba    INTEGER NOT NULL REFERENCES nog_klub(id_kluba),
    id_pozicije INTEGER NOT NULL REFERENCES pozicija(id_pozicije),
    ime         VARCHAR(50) NOT NULL,
    prezime     VARCHAR(50) NOT NULL,
    broj_dresa  INTEGER NOT NULL
);

CREATE TABLE tim_od_korisnika (
    id_tima         SERIAL PRIMARY KEY,
    id_korisnika    INTEGER NOT NULL REFERENCES korisnik(id_korisnika),
    id_lige         INTEGER NOT NULL REFERENCES liga(id_lige),
    naziv_tima      VARCHAR(100) NOT NULL,
    pozicija_u_ligi INTEGER,
    ukupni_poeni    INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE izbor_igraca (
    id_izbora         SERIAL PRIMARY KEY,
    id_tima           INTEGER NOT NULL REFERENCES tim_od_korisnika(id_tima),
    id_igraca         INTEGER NOT NULL REFERENCES igrac(id_igraca),
    pozicija_u_postavi VARCHAR(30),
    cijena            NUMERIC(10, 2)
);

CREATE TABLE pojedinost_kola (
    id_pojedinosti  SERIAL PRIMARY KEY,
    id_kola         INTEGER NOT NULL REFERENCES kolo(id_kolo),
    id_izbora       INTEGER NOT NULL REFERENCES izbor_igraca(id_izbora),
    minute_odigrane INTEGER NOT NULL DEFAULT 0,
    golovi          INTEGER NOT NULL DEFAULT 0,
    asistencije     INTEGER NOT NULL DEFAULT 0,
    poeni           INTEGER
);

CREATE TABLE promjene (
    id_zapisa      SERIAL PRIMARY KEY,
    korisnik       VARCHAR(100),
    operacija      VARCHAR(50),
    datum_vrijeme  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    opis_operacije TEXT,
    id_izbora      INTEGER REFERENCES izbor_igraca(id_izbora)
);

-- Trigger: automatically calculates a player's fantasy points from goals, assists
-- and minutes played, before the row is inserted or updated.
CREATE OR REPLACE FUNCTION fn_izracun_poena()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.minute_odigrane >= 60 THEN
        NEW.poeni := (NEW.golovi * 5) + (NEW.asistencije * 3) + 2;
    ELSE
        NEW.poeni := (NEW.golovi * 5) + (NEW.asistencije * 3);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_izracun_poena
BEFORE INSERT OR UPDATE ON pojedinost_kola
FOR EACH ROW
EXECUTE FUNCTION fn_izracun_poena();

-- Trigger: prevents a team from having more than 11 players in its lineup.
CREATE OR REPLACE FUNCTION fn_provjera_broja_igraca()
RETURNS TRIGGER AS $$
DECLARE
    broj_igraca INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO broj_igraca
    FROM izbor_igraca
    WHERE id_tima = NEW.id_tima;

    IF broj_igraca >= 11 THEN
        RAISE EXCEPTION 'A team can have a maximum of 11 players!';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_provjera_broja_igraca
BEFORE INSERT ON izbor_igraca
FOR EACH ROW
EXECUTE FUNCTION fn_provjera_broja_igraca();
