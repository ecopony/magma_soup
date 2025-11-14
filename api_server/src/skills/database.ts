// ABOUTME: Database skill for managing geographic features
// ABOUTME: Provides tools for feature removal with search and disambiguation

import { getPool } from '../config/database.js';
import type { Skill } from '../services/skill-registry.js';

interface RemoveFeatureInput {
  conversation_id: string;
  query: string;
}

async function handleRemoveFeature(input: RemoveFeatureInput): Promise<string> {
  if (!input.conversation_id) {
    return JSON.stringify({
      success: false,
      error: 'conversation_id is required'
    });
  }

  if (!input.query) {
    return JSON.stringify({
      success: false,
      error: 'query parameter is required',
      received_params: Object.keys(input)
    });
  }

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

export const databaseSkill: Skill = {
  name: 'database',
  documentation: 'Tools for managing geographic features stored in the conversation database.',

  tools: [{
    name: 'database__remove_feature',
    description: 'Remove a geographic feature from the map by searching for it by label. Searches the current conversation for features matching the query string. Returns success if one match is found, or asks for disambiguation if multiple matches exist.',
    input_schema: {
      type: 'object',
      properties: {
        conversation_id: {
          type: 'string',
          description: 'The conversation ID - look for "Conversation ID:" in the system context',
        },
        query: {
          type: 'string',
          description: 'The name or label of the feature to remove (e.g., "Seattle", "Portland"). Will match partial labels.',
        },
      },
      required: ['conversation_id', 'query']
    },
    handler: handleRemoveFeature
  }]
};
