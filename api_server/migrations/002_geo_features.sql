-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- Geographic features table
CREATE TABLE geo_features (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  feature_type TEXT NOT NULL CHECK (feature_type IN ('marker', 'line', 'polygon')),
  geometry GEOMETRY(Geometry, 4326),
  properties JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_geo_features_message ON geo_features(message_id);
CREATE INDEX idx_geo_features_geometry ON geo_features USING GIST(geometry);
