// ABOUTME: Local tool for removing geographic features from the map
// ABOUTME: Performs search on feature labels and handles disambiguation

import Anthropic from "@anthropic-ai/sdk";
import { getPool } from "../config/database.js";

interface RemoveFeatureInput {
  conversation_id: string;
  query: string;
}

export const removeFeatureTool: Anthropic.Tool = {
  name: "remove_map_feature",
  description:
    "Remove a map feature by searching for it by label. IMPORTANT: Use the conversation_id from the system prompt. Returns success message or disambiguation prompt.",
  input_schema: {
    type: "object",
    properties: {
      conversation_id: {
        type: "string",
        description: "REQUIRED: The conversation ID from the system prompt",
      },
      query: {
        type: "string",
        description: 'Search query for the feature label (e.g., "Portland")',
      },
    },
    required: ["conversation_id", "query"],
  },
};

export async function handleRemoveFeature(
  input: RemoveFeatureInput
): Promise<string> {
  const pool = getPool();
  const result = await pool.query(
    `SELECT gf.id, gf.feature_type,
            ST_AsGeoJSON(gf.geometry)::json as geometry,
            gf.properties
     FROM geo_features gf
     JOIN messages m ON gf.message_id = m.id
     WHERE m.conversation_id = $1
       AND gf.properties->>'label' ILIKE $2
     ORDER BY gf.created_at`,
    [input.conversation_id, `%${input.query}%`]
  );

  const matches = result.rows;

  if (matches.length === 0) {
    return JSON.stringify({
      success: false,
      message: `No features found matching "${input.query}"`,
    });
  }

  if (matches.length === 1) {
    const feature = matches[0];
    await pool.query("DELETE FROM geo_features WHERE id = $1", [feature.id]);

    const label = feature.properties?.label || "Unlabeled";
    return JSON.stringify({
      success: true,
      removed_feature_id: feature.id,
      message: `Removed feature: ${label}`,
    });
  }

  const featureList = matches
    .map((f: any, i: number) => {
      const label = f.properties?.label || "Unlabeled";
      const coords = f.geometry.coordinates;
      return `${i + 1}. ${label} (${f.feature_type} at ${coords[1]}, ${
        coords[0]
      })`;
    })
    .join("\n");

  return JSON.stringify({
    success: false,
    disambiguation_required: true,
    message: `Multiple features found matching "${input.query}":\n${featureList}\n\nPlease be more specific about which one to remove.`,
  });
}
