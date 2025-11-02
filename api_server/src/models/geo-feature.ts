// ABOUTME: Database model for geographic features
// ABOUTME: Stores spatial data using PostGIS geometry types

import { getPool } from '../config/database.js';
import type { GeoFeature } from '../types/index.js';

export interface StoredGeoFeature {
  id: string;
  message_id: string;
  feature_type: string;
  geometry: any;
  properties: Record<string, any>;
  created_at: Date;
}

export async function createGeoFeature(
  messageId: string,
  feature: GeoFeature
): Promise<StoredGeoFeature> {
  const pool = getPool();

  // Convert lat/lon to PostGIS Point geometry
  const result = await pool.query(
    `INSERT INTO geo_features (message_id, feature_type, geometry, properties)
     VALUES ($1, $2, ST_SetSRID(ST_MakePoint($3, $4), 4326), $5)
     RETURNING id, message_id, feature_type,
               ST_AsGeoJSON(geometry)::json as geometry,
               properties, created_at`,
    [messageId, feature.type, feature.lon, feature.lat, JSON.stringify({ label: feature.label })]
  );

  return result.rows[0];
}

export async function getMessageGeoFeatures(
  messageId: string
): Promise<StoredGeoFeature[]> {
  const pool = getPool();
  const result = await pool.query(
    `SELECT id, message_id, feature_type,
            ST_AsGeoJSON(geometry)::json as geometry,
            properties, created_at
     FROM geo_features
     WHERE message_id = $1`,
    [messageId]
  );
  return result.rows;
}
