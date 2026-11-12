-- PKM-4: esquema para guardar precios diarios de cartas Pokémon TCG (fuente: TCGdex, mercado Cardmarket, EUR).
-- Se ejecuta automáticamente SOLO cuando el contenedor de Postgres crea la base por primera vez
-- (volumen vacío), porque docker-compose.yml monta ./sql en /docker-entrypoint-initdb.d.

BEGIN;

-- Expansiones / sets de TCGdex (p. ej. 'swsh3').
CREATE TABLE sets (
    id           text    PRIMARY KEY,               -- id de TCGdex
    name         text    NOT NULL,
    release_date date,
    card_count   integer CHECK (card_count >= 0)
);

-- Cartas individuales (p. ej. 'swsh3-136').
CREATE TABLE cards (
    id        text PRIMARY KEY,                     -- id de TCGdex
    set_id    text NOT NULL REFERENCES sets (id),
    name      text NOT NULL,
    local_id  text NOT NULL,                        -- número dentro del set; text porque existen ids como 'TG01' o 'SV001'
    rarity    text,
    image_url text
);

-- Postgres no indexa automáticamente las FK: este índice acelera "todas las cartas de un set" y los JOIN.
CREATE INDEX cards_set_id_idx ON cards (set_id);

-- Una fila = el precio de una variante de una carta, en una fuente, en un día.
CREATE TABLE price_snapshots (
    id            bigserial   PRIMARY KEY,
    card_id       text        NOT NULL REFERENCES cards (id),
    variant       text        NOT NULL,             -- normal, holo, reverse...
    source        text        NOT NULL DEFAULT 'cardmarket',
    snapshot_date date        NOT NULL,
    avg           numeric(10,2),                    -- precios en EUR; NULL = TCGdex no lo da
    low           numeric(10,2),
    trend         numeric(10,2),
    avg1          numeric(10,2),
    avg7          numeric(10,2),
    avg30         numeric(10,2),
    created_at    timestamptz NOT NULL DEFAULT now(),

    -- Como mucho un snapshot por carta + variante + fuente + día.
    CONSTRAINT price_snapshots_card_variant_source_date_key
        UNIQUE (card_id, variant, source, snapshot_date)
);

-- Histórico de una carta: WHERE card_id = ? AND variant = ? ORDER BY / rango sobre snapshot_date.
CREATE INDEX price_snapshots_card_variant_date_idx
    ON price_snapshots (card_id, variant, snapshot_date);

COMMIT;
