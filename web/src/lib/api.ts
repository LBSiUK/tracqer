import {
  encryptData,
  decryptData,
  Envelope,
  exportKey,
  importKey,
} from "./crypto";
import type {
  VinylRecord,
  RecordFilters,
  RecordsResponse,
  RecordInput,
  RecordPatch,
  Photo,
  PhotoType,
} from "./types";

export class VinylAPI {
  private baseUrl: string;
  private key: CryptoKey;
  public token: string;

  constructor(baseUrl: string, key: CryptoKey, token: string) {
    // Strip trailing slash
    this.baseUrl = baseUrl.replace(/\/$/, "");
    this.key = key;
    this.token = token;
  }

  private async request<T>(
    method: string,
    path: string,
    body?: unknown
  ): Promise<T> {
    const url = `${this.baseUrl}${path}`;
    const headers: Record<string, string> = {
      Authorization: `Bearer ${this.token}`,
    };
    let fetchBody: BodyInit | undefined;

    if (body !== undefined) {
      const envelope = await encryptData(this.key, body);
      headers["Content-Type"] = "application/json";
      fetchBody = JSON.stringify(envelope);
    }

    const response = await fetch(url, {
      method,
      headers,
      body: fetchBody,
    });

    if (response.status === 204) {
      return undefined as T;
    }

    if (!response.ok) {
      const text = await response.text().catch(() => response.statusText);
      throw new Error(`API error ${response.status}: ${text}`);
    }

    const envelope = (await response.json()) as Envelope;
    const decrypted = await decryptData(this.key, envelope);
    return decrypted as T;
  }

  photoUrl(
    recordId: string,
    photoType: PhotoType,
    discNumber?: number,
    size: "original" | "240" | "320" | "640" | "1280" = "640"
  ): string {
    const isDiscType =
      photoType === "disc_front" || photoType === "disc_back";
    let path: string;
    if (isDiscType && discNumber !== undefined) {
      path = `/api/v1/records/${recordId}/photos/${photoType}/${discNumber}`;
    } else {
      path = `/api/v1/records/${recordId}/photos/${photoType}`;
    }
    return `${this.baseUrl}${path}?token=${this.token}&size=${size}`;
  }

  // Records

  async listRecords(filters: RecordFilters = {}): Promise<RecordsResponse> {
    const params = new URLSearchParams();
    if (filters.search) params.set("search", filters.search);
    if (filters.artist) params.set("artist", filters.artist);
    if (filters.genre) params.set("genre", filters.genre);
    if (filters.owner) params.set("owner", filters.owner);
    if (filters.format) params.set("format", filters.format);
    if (filters.disc_condition)
      params.set("disc_condition", filters.disc_condition);
    if (filters.sleeve_condition)
      params.set("sleeve_condition", filters.sleeve_condition);
    if (filters.wishlist !== undefined)
      params.set("wishlist", String(filters.wishlist));
    if (filters.page !== undefined) params.set("page", String(filters.page));
    if (filters.limit !== undefined) params.set("limit", String(filters.limit));
    if (filters.sort) params.set("sort", filters.sort);
    if (filters.order) params.set("order", filters.order);

    const query = params.toString();
    const path = `/api/v1/records${query ? `?${query}` : ""}`;
    return this.request<RecordsResponse>("GET", path);
  }

  async getRecord(id: string): Promise<VinylRecord> {
    return this.request<VinylRecord>("GET", `/api/v1/records/${id}`);
  }

  async createRecord(
    metadata: RecordInput,
    photos: Partial<Record<string, File>>
  ): Promise<VinylRecord> {
    const envelope = await encryptData(this.key, metadata);
    const formData = new FormData();
    formData.append("metadata", JSON.stringify(envelope));

    for (const [fieldName, file] of Object.entries(photos)) {
      if (file) {
        formData.append(fieldName, file);
      }
    }

    const response = await fetch(`${this.baseUrl}/api/v1/records/upload`, {
      method: "POST",
      headers: { Authorization: `Bearer ${this.token}` },
      body: formData,
    });

    if (!response.ok) {
      const text = await response.text().catch(() => response.statusText);
      throw new Error(`API error ${response.status}: ${text}`);
    }

    const responseEnvelope = (await response.json()) as Envelope;
    const decrypted = await decryptData(this.key, responseEnvelope);
    return decrypted as VinylRecord;
  }

  async updateRecord(id: string, patch: RecordPatch): Promise<VinylRecord> {
    return this.request<VinylRecord>("PATCH", `/api/v1/records/${id}`, patch);
  }

  async deleteRecord(id: string): Promise<void> {
    return this.request<void>("DELETE", `/api/v1/records/${id}`);
  }

  // Photos

  async getPhotos(recordId: string): Promise<{ photos: Photo[] }> {
    return this.request<{ photos: Photo[] }>(
      "GET",
      `/api/v1/records/${recordId}/photos`
    );
  }

  async uploadPhoto(
    recordId: string,
    photoType: PhotoType,
    file: File,
    discNumber?: number
  ): Promise<void> {
    const isDiscType =
      photoType === "disc_front" || photoType === "disc_back";
    let path: string;
    if (isDiscType && discNumber !== undefined) {
      path = `/api/v1/records/${recordId}/photos/${photoType}/${discNumber}`;
    } else {
      path = `/api/v1/records/${recordId}/photos/${photoType}`;
    }

    const formData = new FormData();
    formData.append("file", file);

    const response = await fetch(`${this.baseUrl}${path}`, {
      method: "POST",
      headers: { Authorization: `Bearer ${this.token}` },
      body: formData,
    });

    if (!response.ok) {
      const text = await response.text().catch(() => response.statusText);
      throw new Error(`API error ${response.status}: ${text}`);
    }
  }

  async deletePhoto(
    recordId: string,
    photoType: PhotoType,
    discNumber?: number
  ): Promise<void> {
    const isDiscType =
      photoType === "disc_front" || photoType === "disc_back";
    let path: string;
    if (isDiscType && discNumber !== undefined) {
      path = `/api/v1/records/${recordId}/photos/${photoType}/${discNumber}`;
    } else {
      path = `/api/v1/records/${recordId}/photos/${photoType}`;
    }
    return this.request<void>("DELETE", path);
  }

  // Static helpers for login flow

  static async ping(baseUrl: string): Promise<boolean> {
    try {
      const url = baseUrl.replace(/\/$/, "");
      const response = await fetch(`${url}/ping`);
      return response.ok;
    } catch {
      return false;
    }
  }

  static async verify(
    baseUrl: string,
    key: CryptoKey,
    token: string
  ): Promise<boolean> {
    try {
      const url = baseUrl.replace(/\/$/, "");
      const envelope = await encryptData(key, {});
      const response = await fetch(`${url}/api/v1/auth/verify`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify(envelope),
      });

      if (!response.ok) return false;

      const responseEnvelope = (await response.json()) as Envelope;
      const result = (await decryptData(key, responseEnvelope)) as {
        valid: boolean;
      };
      return result.valid === true;
    } catch {
      return false;
    }
  }

  // Serialization for localStorage

  async serialize(): Promise<{
    baseUrl: string;
    keyB64: string;
    token: string;
  }> {
    const keyB64 = await exportKey(this.key);
    return { baseUrl: this.baseUrl, keyB64, token: this.token };
  }

  static async deserialize(data: {
    baseUrl: string;
    keyB64: string;
    token: string;
  }): Promise<VinylAPI> {
    const key = await importKey(data.keyB64);
    return new VinylAPI(data.baseUrl, key, data.token);
  }
}
