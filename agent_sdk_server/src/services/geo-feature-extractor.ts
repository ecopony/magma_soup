// ABOUTME: Extracts geographic features from tool results
// ABOUTME: Converts geocoding and other geo tool outputs into GeoFeature objects

import { randomUUID } from "crypto";

export interface GeoFeature {
  id: string;
  type: "marker";
  lat: number;
  lon: number;
  label: string;
}

export class GeoFeatureExtractor {
  extractFeatures(
    toolName: string,
    result: string,
    toolArguments: Record<string, any>
  ): GeoFeature[] {
    // Handle both MCP-prefixed and plain tool names
    const baseName = toolName.replace(/^mcp__[^_]+__/, "");

    switch (baseName) {
      case "geocode_address":
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
        geocodeResult.display_name || toolArguments.address || "Unknown";

      return [
        {
          id: randomUUID(),
          type: "marker",
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
