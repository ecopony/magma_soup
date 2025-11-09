// ABOUTME: Extracts geographic features from MCP tool results
// ABOUTME: Converts geocoding and other geo tool outputs into GeoFeature objects

import { randomUUID } from 'crypto';
import type { GeoFeature } from '../types/index.js';

export class GeoFeatureExtractor {
  extractFeatures(
    toolName: string,
    result: string,
    toolArguments: Record<string, any>
  ): GeoFeature[] {
    switch (toolName) {
      case 'geocode_address':
        return this.extractGeocodeFeature(result, toolArguments);
      default:
        return [];
    }
  }

  private extractGeocodeFeature(
    result: string,
    toolArguments: Record<string, any>
  ): GeoFeature[] {
    try {
      const geocodeResult = JSON.parse(result);
      const lat = parseFloat(geocodeResult.lat);
      const lon = parseFloat(geocodeResult.lon);
      const label =
        geocodeResult.display_name ||
        toolArguments.address ||
        'Unknown';

      return [
        {
          id: randomUUID(),
          type: 'marker',
          lat,
          lon,
          label,
        },
      ];
    } catch (e) {
      return [];
    }
  }
}
