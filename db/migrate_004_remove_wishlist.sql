-- Migration 004: remove wishlist column
ALTER TABLE records DROP COLUMN IF EXISTS wishlist;
