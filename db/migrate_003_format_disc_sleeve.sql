-- Migration 003: new format enum, disc_count, outer_sleeve_only

-- Replace the record_format enum with new values
-- (PostgreSQL doesn't allow removing enum values, so we rename/recreate)

ALTER TYPE record_format RENAME TO record_format_old;

CREATE TYPE record_format AS ENUM ('12" LP', '10" LP', '12" single', '7" single', 'Other');

ALTER TABLE records
  ALTER COLUMN format TYPE record_format
  USING CASE format::text
    WHEN 'LP'     THEN '12" LP'::record_format
    WHEN 'EP'     THEN 'Other'::record_format
    WHEN 'Single' THEN '12" single'::record_format
    WHEN '7"'     THEN '7" single'::record_format
    WHEN '10"'    THEN '10" LP'::record_format
    WHEN '12"'    THEN '12" LP'::record_format
    ELSE NULL
  END;

DROP TYPE record_format_old;

-- Number of discs (1–4, default 1)
ALTER TABLE records ADD COLUMN disc_count SMALLINT NOT NULL DEFAULT 1;

-- Whether the record has no separate inner sleeve (e.g. most singles)
ALTER TABLE records ADD COLUMN outer_sleeve_only BOOLEAN NOT NULL DEFAULT false;
