// ABOUTME: GIS-specific prompt builder for adding context to user commands
// ABOUTME: Constructs system prompts with optional spatial context

import { StoredGeoFeature } from "../models/geo-feature.js";

export class GisPromptBuilder {
  private static systemContext = `You are a GIS (Geographic Information Systems) processing assistant.

    You help users with geospatial data analysis, manipulation, and transformation tasks.

    The user is viewing a map interface. When you use tools that return GeoFeature objects,
    those features will automatically appear on the map. The user may reference "the map"
    when asking questions or giving commands about the displayed geographic data.

    If a user asks for a feature to be added to the map you only need to geolocate it. That is
    enough to get it mapped.

    You have access to additional skills that can be activated using the activate_skill tool.
    Available skills:
    - database: Tools for managing geographic features stored in the conversation (e.g., removing features from the map)

    When you need functionality that isn't available in your current tools, check if activating
    a skill would provide the needed capability.
    `;

  static buildPromptWithMapContext(
    conversationId: string,
    userCommand: string,
    currentFeatures: StoredGeoFeature[]
  ): string {
    let mapContext = "";

    if (currentFeatures.length > 0) {
      mapContext = "\n\nCurrent map features:\n";
      for (const feature of currentFeatures) {
        const label = feature.properties?.label || "Unlabeled";
        const coords = feature.geometry.coordinates;
        mapContext += `- ${feature.feature_type}: "${label}" at (${coords[1]}, ${coords[0]})\n`;
      }
    } else {
      mapContext = "\n\nThe map currently has no features.";
    }

    return `${this.systemContext}${mapContext}

Conversation ID: ${conversationId}

User request: ${userCommand}

Attempt to complete the user's request. If you lack the tools to do so, let the user know.`;
  }
}
