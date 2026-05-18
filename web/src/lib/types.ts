export type Grade = "M" | "NM" | "VG+" | "VG" | "G+" | "G" | "F" | "P";
export type Format = '12" LP' | '10" LP' | '12" single' | '7" single' | 'Other';
export type Speed = "33" | "45" | "78";
export type Owner = "me" | "dad" | "shared";
export type PhotoType =
  | "sleeve_front"
  | "sleeve_back"
  | "sleeve_inner"
  | "inner_sleeve_front"
  | "inner_sleeve_back"
  | "disc_front"
  | "disc_back";

export interface Photo {
  id: string;
  photo_type: PhotoType;
  disc_number: number | null;
  mime_type: string;
  file_size: number;
  url: string;
  created_at: string;
}

export interface VinylRecord {
  id: string;
  title: string;
  artist: string;
  year: number | null;
  duration: string | null;
  label: string | null;
  format: Format | null;
  speed: Speed | null;
  genre: string | null;
  notes: string | null;
  owner: Owner;
  disc_count: number;
  outer_sleeve_only: boolean;
  disc_condition: Grade | null;
  sleeve_condition: Grade | null;
  photos: Photo[];
  created_at: string;
  updated_at: string;
}

export interface RecordFilters {
  search?: string;
  artist?: string;
  genre?: string;
  owner?: Owner;
  format?: Format;
  disc_condition?: Grade;
  sleeve_condition?: Grade;
  wishlist?: boolean;
  page?: number;
  limit?: number;
  sort?: string;
  order?: "asc" | "desc";
}

export interface RecordsResponse {
  records: VinylRecord[];
  total: number;
  page: number;
  limit: number;
}

export type RecordInput = Omit<
  VinylRecord,
  "id" | "photos" | "created_at" | "updated_at"
>;
export type RecordPatch = Partial<RecordInput>;
