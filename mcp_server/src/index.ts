import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { SSEServerTransport } from "@modelcontextprotocol/sdk/server/sse.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  ListToolsRequestSchema,
  CallToolRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import express from "express";
import cors from "cors";
import * as turf from "@turf/turf";
import "dotenv/config";

const app = express();
app.use(cors());
app.use(express.json());

// Create MCP server
const server = new Server(
  {
    name: "geospatial-server",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Tool: Calculate distance between two points
server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "calculate_distance",
      description:
        "Calculate the distance between two geographic points in kilometers",
      inputSchema: {
        type: "object",
        properties: {
          point1: {
            type: "object",
            properties: {
              lat: { type: "number", description: "Latitude of first point" },
              lon: { type: "number", description: "Longitude of first point" },
            },
            required: ["lat", "lon"],
          },
          point2: {
            type: "object",
            properties: {
              lat: { type: "number", description: "Latitude of second point" },
              lon: { type: "number", description: "Longitude of second point" },
            },
            required: ["lat", "lon"],
          },
        },
        required: ["point1", "point2"],
      },
    },
    {
      name: "geocode_address",
      description:
        "Convert an address to coordinates using Google Maps Geocoding API",
      inputSchema: {
        type: "object",
        properties: {
          address: {
            type: "string",
            description: "The address to geocode",
          },
        },
        required: ["address"],
      },
    },
    {
      name: "find_points_in_radius",
      description: "Find points within a given radius of a center point",
      inputSchema: {
        type: "object",
        properties: {
          center: {
            type: "object",
            properties: {
              lat: { type: "number" },
              lon: { type: "number" },
            },
            required: ["lat", "lon"],
          },
          radius: {
            type: "number",
            description: "Radius in kilometers",
          },
          points: {
            type: "array",
            items: {
              type: "object",
              properties: {
                name: { type: "string" },
                lat: { type: "number" },
                lon: { type: "number" },
              },
              required: ["lat", "lon"],
            },
          },
        },
        required: ["center", "radius", "points"],
      },
    },
    {
      name: "calculate_area",
      description: "Calculate the area of a polygon in square kilometers",
      inputSchema: {
        type: "object",
        properties: {
          coordinates: {
            type: "array",
            description:
              "Array of [lon, lat] coordinate pairs forming the polygon",
            items: {
              type: "array",
              items: { type: "number" },
              minItems: 2,
              maxItems: 2,
            },
          },
        },
        required: ["coordinates"],
      },
    },
  ],
}));

// Tool execution handler
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;
  console.log(`[MCP] Tool called: ${name}`, JSON.stringify(args, null, 2));

  switch (name) {
    case "calculate_distance": {
      const { point1, point2 } = args as any;
      const from = turf.point([point1.lon, point1.lat]);
      const to = turf.point([point2.lon, point2.lat]);
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

    case "geocode_address": {
      const { address } = args as any;
      const apiKey = process.env.GOOGLE_MAPS_API_KEY;

      if (!apiKey) {
        return {
          content: [
            {
              type: "text",
              text: "Error: GOOGLE_MAPS_API_KEY not set in environment",
            },
          ],
        };
      }

      const response = await fetch(
        `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(
          address
        )}&key=${apiKey}`
      );
      const data = await response.json();

      if (data.status !== "OK" || data.results.length === 0) {
        return {
          content: [
            {
              type: "text",
              text: `No results found for address: ${address} (${data.status})`,
            },
          ],
        };
      }

      const result = data.results[0];
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(
              {
                address: result.formatted_address,
                lat: result.geometry.location.lat,
                lon: result.geometry.location.lng,
              },
              null,
              2
            ),
          },
        ],
      };
    }

    case "find_points_in_radius": {
      const { center, radius, points } = args as any;
      const centerPoint = turf.point([center.lon, center.lat]);
      const radiusInKm = radius;

      const pointsInRadius = points.filter((p: any) => {
        const point = turf.point([p.lon, p.lat]);
        const dist = turf.distance(centerPoint, point, { units: "kilometers" });
        return dist <= radiusInKm;
      });

      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(
              {
                count: pointsInRadius.length,
                points: pointsInRadius.map((p: any) => ({
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

    case "calculate_area": {
      const { coordinates } = args as any;
      // Close the polygon if not already closed
      const coords = [...coordinates];
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

    default:
      throw new Error(`Unknown tool: ${name}`);
  }
});

// SSE endpoint
app.get("/sse", async (req, res) => {
  const transport = new SSEServerTransport("/messages", res);
  await server.connect(transport);
});

// Messages endpoint for SSE
app.post("/messages", async (req, res) => {
  // The SSE transport handles this
  res.status(200).end();
});

// Standard HTTP/POST endpoint for direct tool calls
app.post("/tools/list", async (_req, res) => {
  try {
    const result = {
      tools: [
        {
          name: "calculate_distance",
          description:
            "Calculate the distance between two geographic points in kilometers",
          inputSchema: {
            type: "object",
            properties: {
              point1: {
                type: "object",
                properties: {
                  lat: {
                    type: "number",
                    description: "Latitude of first point",
                  },
                  lon: {
                    type: "number",
                    description: "Longitude of first point",
                  },
                },
                required: ["lat", "lon"],
              },
              point2: {
                type: "object",
                properties: {
                  lat: {
                    type: "number",
                    description: "Latitude of second point",
                  },
                  lon: {
                    type: "number",
                    description: "Longitude of second point",
                  },
                },
                required: ["lat", "lon"],
              },
            },
            required: ["point1", "point2"],
          },
        },
        {
          name: "geocode_address",
          description:
            "Convert an address to coordinates using Nominatim (OpenStreetMap)",
          inputSchema: {
            type: "object",
            properties: {
              address: {
                type: "string",
                description: "The address to geocode",
              },
            },
            required: ["address"],
          },
        },
        {
          name: "find_points_in_radius",
          description: "Find points within a given radius of a center point",
          inputSchema: {
            type: "object",
            properties: {
              center: {
                type: "object",
                properties: {
                  lat: { type: "number" },
                  lon: { type: "number" },
                },
                required: ["lat", "lon"],
              },
              radius: { type: "number", description: "Radius in kilometers" },
              points: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    name: { type: "string" },
                    lat: { type: "number" },
                    lon: { type: "number" },
                  },
                  required: ["lat", "lon"],
                },
              },
            },
            required: ["center", "radius", "points"],
          },
        },
        {
          name: "calculate_area",
          description: "Calculate the area of a polygon in square kilometers",
          inputSchema: {
            type: "object",
            properties: {
              coordinates: {
                type: "array",
                description:
                  "Array of [lon, lat] coordinate pairs forming the polygon",
                items: {
                  type: "array",
                  items: { type: "number" },
                  minItems: 2,
                  maxItems: 2,
                },
              },
            },
            required: ["coordinates"],
          },
        },
      ],
    };
    res.json(result);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

app.post("/tools/call", async (req, res) => {
  try {
    const { name, arguments: args } = req.body;
    console.log(`[HTTP] Tool called: ${name}`, JSON.stringify(args, null, 2));

    let result;
    switch (name) {
      case "calculate_distance": {
        const { point1, point2 } = args as any;
        const from = turf.point([point1.lon, point1.lat]);
        const to = turf.point([point2.lon, point2.lat]);
        const distance = turf.distance(from, to, { units: "kilometers" });
        result = {
          content: [
            { type: "text", text: `Distance: ${distance.toFixed(2)} km` },
          ],
        };
        break;
      }

      case "geocode_address": {
        const { address } = args as any;
        const apiKey = process.env.GOOGLE_MAPS_API_KEY;

        if (!apiKey) {
          result = {
            content: [
              {
                type: "text",
                text: "Error: GOOGLE_MAPS_API_KEY not set in environment",
              },
            ],
          };
          break;
        }

        const response = await fetch(
          `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(
            address
          )}&key=${apiKey}`
        );
        const data = await response.json();

        if (data.status !== "OK" || data.results.length === 0) {
          result = {
            content: [
              {
                type: "text",
                text: `No results found for address: ${address} (${data.status})`,
              },
            ],
          };
        } else {
          const location = data.results[0];
          result = {
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
        }
        break;
      }

      case "find_points_in_radius": {
        const { center, radius, points } = args as any;
        const centerPoint = turf.point([center.lon, center.lat]);
        const pointsInRadius = points.filter((p: any) => {
          const point = turf.point([p.lon, p.lat]);
          const dist = turf.distance(centerPoint, point, {
            units: "kilometers",
          });
          return dist <= radius;
        });

        result = {
          content: [
            {
              type: "text",
              text: JSON.stringify(
                {
                  count: pointsInRadius.length,
                  points: pointsInRadius.map((p: any) => ({
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
        break;
      }

      case "calculate_area": {
        const { coordinates } = args as any;
        const coords = [...coordinates];
        if (
          coords[0][0] !== coords[coords.length - 1][0] ||
          coords[0][1] !== coords[coords.length - 1][1]
        ) {
          coords.push(coords[0]);
        }
        const polygon = turf.polygon([coords]);
        const area = turf.area(polygon) / 1_000_000;
        result = {
          content: [{ type: "text", text: `Area: ${area.toFixed(2)} km²` }],
        };
        break;
      }

      default:
        return res.status(400).json({ error: `Unknown tool: ${name}` });
    }

    res.json(result);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Health check
app.get("/health", (req, res) => {
  res.json({ status: "ok", server: "geospatial-mcp" });
});

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`Geospatial MCP Server running on http://localhost:${PORT}`);
  console.log(`\nEndpoints:`);
  console.log(`  SSE: http://localhost:${PORT}/sse`);
  console.log(`  HTTP Tools List: POST http://localhost:${PORT}/tools/list`);
  console.log(`  HTTP Tools Call: POST http://localhost:${PORT}/tools/call`);
  console.log(`  Health: http://localhost:${PORT}/health`);
});
