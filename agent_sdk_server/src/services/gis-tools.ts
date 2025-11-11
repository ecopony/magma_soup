// ABOUTME: GIS tools ported to Agent SDK format
// ABOUTME: Wraps Turf.js and Google Maps API in MCP tool definitions

import { createSdkMcpServer, tool } from "@anthropic-ai/claude-agent-sdk";
import { z } from "zod";
import * as turf from "@turf/turf";
import { getPool } from "../config/database.js";

export const gisTools = createSdkMcpServer({
  name: "gis-tools",
  version: "1.0.0",
  tools: [
    tool(
      "calculate_distance",
      "Calculate the distance between two geographic points in kilometers",
      {
        point1: z.object({
          lat: z.number().describe("Latitude of first point"),
          lon: z.number().describe("Longitude of first point"),
        }).describe("First geographic point"),
        point2: z.object({
          lat: z.number().describe("Latitude of second point"),
          lon: z.number().describe("Longitude of second point"),
        }).describe("Second geographic point"),
      },
      async (args) => {
        const from = turf.point([args.point1.lon, args.point1.lat]);
        const to = turf.point([args.point2.lon, args.point2.lat]);
        const distance = turf.distance(from, to, { units: "kilometers" });

        return {
          content: [
            {
              type: "text",
              text: `Distance: ${distance.toFixed(2)} km`,
            },
          ],
        };
      }
    ),

    tool(
      "geocode_address",
      "Convert an address to coordinates using Google Maps Geocoding API",
      {
        address: z.string().describe("The address to geocode"),
      },
      async (args) => {
        const apiKey = process.env.GOOGLE_MAPS_API_KEY;

        if (!apiKey) {
          return {
            content: [
              {
                type: "text",
                text: "Error: GOOGLE_MAPS_API_KEY not set in environment",
              },
            ],
            isError: true,
          };
        }

        try {
          const response = await fetch(
            `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(
              args.address
            )}&key=${apiKey}`
          );
          const data = await response.json();

          if (data.status !== "OK" || data.results.length === 0) {
            return {
              content: [
                {
                  type: "text",
                  text: `No results found for address: ${args.address} (${data.status})`,
                },
              ],
            };
          }

          const location = data.results[0];
          return {
            content: [
              {
                type: "text",
                text: JSON.stringify(
                  {
                    address: location.formatted_address,
                    lat: location.geometry.location.lat,
                    lon: location.geometry.location.lng,
                  },
                  null,
                  2
                ),
              },
            ],
          };
        } catch (error: any) {
          return {
            content: [
              {
                type: "text",
                text: `Geocoding error: ${error.message}`,
              },
            ],
            isError: true,
          };
        }
      }
    ),

    tool(
      "find_points_in_radius",
      "Find points within a given radius of a center point",
      {
        center: z.object({
          lat: z.number().describe("Latitude"),
          lon: z.number().describe("Longitude"),
        }).describe("Center point"),
        radius: z.number().describe("Radius in kilometers"),
        points: z
          .array(z.object({
            lat: z.number().describe("Latitude"),
            lon: z.number().describe("Longitude"),
            name: z.string().optional().describe("Optional name for the point"),
          }))
          .describe("Array of points to check"),
      },
      async (args) => {
        const centerPoint = turf.point([args.center.lon, args.center.lat]);
        const pointsInRadius = args.points.filter((p) => {
          const point = turf.point([p.lon, p.lat]);
          const dist = turf.distance(centerPoint, point, {
            units: "kilometers",
          });
          return dist <= args.radius;
        });

        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(
                {
                  count: pointsInRadius.length,
                  points: pointsInRadius.map((p) => ({
                    name: p.name || "Unnamed",
                    lat: p.lat,
                    lon: p.lon,
                    distance: turf
                      .distance(centerPoint, turf.point([p.lon, p.lat]), {
                        units: "kilometers",
                      })
                      .toFixed(2),
                  })),
                },
                null,
                2
              ),
            },
          ],
        };
      }
    ),

    tool(
      "calculate_area",
      "Calculate the area of a polygon in square kilometers",
      {
        coordinates: z
          .array(z.tuple([z.number(), z.number()]))
          .describe("Array of [lon, lat] coordinate pairs forming the polygon"),
      },
      async (args) => {
        const coords = [...args.coordinates];
        // Close the polygon if not already closed
        if (
          coords[0][0] !== coords[coords.length - 1][0] ||
          coords[0][1] !== coords[coords.length - 1][1]
        ) {
          coords.push(coords[0]);
        }

        const polygon = turf.polygon([coords]);
        const area = turf.area(polygon) / 1_000_000; // Convert to km²

        return {
          content: [
            {
              type: "text",
              text: `Area: ${area.toFixed(2)} km²`,
            },
          ],
        };
      }
    ),

    tool(
      "remove_map_feature",
      "Remove a map feature by searching for it by label. IMPORTANT: Use the conversation_id from the system prompt. Returns success message or disambiguation prompt.",
      {
        conversation_id: z
          .string()
          .describe("REQUIRED: The conversation ID from the system prompt"),
        query: z
          .string()
          .describe('Search query for the feature label (e.g., "Portland")'),
      },
      async (args) => {
        const pool = getPool();

        try {
          const result = await pool.query(
            `SELECT gf.id, gf.feature_type,
                    ST_AsGeoJSON(gf.geometry)::json as geometry,
                    gf.properties
             FROM geo_features gf
             JOIN messages m ON gf.message_id = m.id
             WHERE m.conversation_id = $1
               AND gf.properties->>'label' ILIKE $2
             ORDER BY gf.created_at`,
            [args.conversation_id, `%${args.query}%`]
          );

          const matches = result.rows;

          if (matches.length === 0) {
            return {
              content: [
                {
                  type: "text",
                  text: JSON.stringify({
                    success: false,
                    message: `No features found matching "${args.query}"`,
                  }),
                },
              ],
            };
          }

          if (matches.length === 1) {
            const feature = matches[0];
            await pool.query("DELETE FROM geo_features WHERE id = $1", [
              feature.id,
            ]);

            const label = feature.properties?.label || "Unlabeled";
            return {
              content: [
                {
                  type: "text",
                  text: JSON.stringify({
                    success: true,
                    removed_feature_id: feature.id,
                    message: `Removed feature: ${label}`,
                  }),
                },
              ],
            };
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

          return {
            content: [
              {
                type: "text",
                text: JSON.stringify({
                  success: false,
                  disambiguation_required: true,
                  message: `Multiple features found matching "${args.query}":\n${featureList}\n\nPlease be more specific about which one to remove.`,
                }),
              },
            ],
          };
        } catch (error: any) {
          return {
            content: [
              {
                type: "text",
                text: JSON.stringify({
                  success: false,
                  error: error.message,
                }),
              },
            ],
            isError: true,
          };
        }
      }
    ),
  ],
});
