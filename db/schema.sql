-- =============================================================
-- Vinyl Collection — PostgreSQL Schema
-- =============================================================

-- ---------------------
-- Enums
-- ---------------------

-- Goldmine/Discogs standard grading (used separately for disc and sleeve)
CREATE TYPE record_grade AS ENUM (
    'M',    -- Mint
    'NM',   -- Near Mint
    'VG+',  -- Very Good Plus
    'VG',   -- Very Good
    'G+',   -- Good Plus
    'G',    -- Good
    'F',    -- Fair
    'P'     -- Poor
);

-- 33 implies 33⅓ RPM
CREATE TYPE record_speed AS ENUM ('33', '45', '78');

CREATE TYPE record_format AS ENUM (
    'LP',
    'EP',
    'Single',
    '7"',
    '10"',
    '12"'
);

CREATE TYPE record_owner AS ENUM ('me', 'dad', 'shared');

CREATE TYPE photo_type AS ENUM (
    'sleeve_front',
    'sleeve_back',
    'sleeve_inner',  -- gatefold inner spread
    'disc_front',    -- label side — requires disc_number
    'disc_back'      -- play side — requires disc_number
);

-- ---------------------
-- Records
-- ---------------------

CREATE TABLE records (
    id                UUID            PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Core fields
    title             TEXT            NOT NULL,
    artist            TEXT            NOT NULL,
    year              SMALLINT        CHECK (year BETWEEN 1900 AND 2100),
    duration          TEXT,                           -- e.g. "42:30"
    label             TEXT,
    format            record_format,
    speed             record_speed,
    genre             TEXT,
    notes             TEXT,
    owner             record_owner    NOT NULL DEFAULT 'shared',
    wishlist          BOOLEAN         NOT NULL DEFAULT FALSE,

    -- Graded separately: the disc and its sleeve can be in different condition
    disc_condition    record_grade,
    sleeve_condition  record_grade,

    created_at        TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- ---------------------
-- Photos
-- ---------------------

CREATE TABLE photos (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    record_id   UUID        NOT NULL REFERENCES records(id) ON DELETE CASCADE,
    photo_type  photo_type  NOT NULL,

    -- Only set for disc_front / disc_back (disc 1, 2, 3 …)
    disc_number SMALLINT    CHECK (
        (photo_type IN ('disc_front', 'disc_back') AND disc_number IS NOT NULL AND disc_number >= 1)
        OR
        (photo_type NOT IN ('disc_front', 'disc_back') AND disc_number IS NULL)
    ),

    mime_type   TEXT        NOT NULL,
    file_size   INTEGER     NOT NULL CHECK (file_size > 0),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- One photo per slot per record
    UNIQUE (record_id, photo_type, disc_number)
);

CREATE INDEX idx_photos_record_id ON photos (record_id);

-- ---------------------
-- Indexes on records
-- ---------------------

CREATE INDEX idx_records_artist          ON records (artist);
CREATE INDEX idx_records_title           ON records (title);
CREATE INDEX idx_records_year            ON records (year);
CREATE INDEX idx_records_genre           ON records (genre);
CREATE INDEX idx_records_owner           ON records (owner);
CREATE INDEX idx_records_disc_condition  ON records (disc_condition);
CREATE INDEX idx_records_format          ON records (format);
CREATE INDEX idx_records_wishlist        ON records (created_at) WHERE wishlist = TRUE;

-- ---------------------
-- Full-text search
-- ---------------------

ALTER TABLE records
    ADD COLUMN search_vector TSVECTOR GENERATED ALWAYS AS (
        setweight(to_tsvector('english', coalesce(title,  '')), 'A') ||
        setweight(to_tsvector('english', coalesce(artist, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(label,  '')), 'B') ||
        setweight(to_tsvector('english', coalesce(genre,  '')), 'C') ||
        setweight(to_tsvector('english', coalesce(notes,  '')), 'D')
    ) STORED;

CREATE INDEX idx_records_fts ON records USING GIN (search_vector);

-- ---------------------
-- Auto-update updated_at
-- ---------------------

CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_records_updated_at
    BEFORE UPDATE ON records
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

-- ---------------------
-- Auth
-- ---------------------

CREATE TABLE auth (
    id          SMALLINT    PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    token       TEXT        NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
