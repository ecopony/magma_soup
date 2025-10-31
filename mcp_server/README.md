# Magma Soup MCP - Geospatial MCP Server

A Model Context Protocol (MCP) server providing geospatial tools with both SSE and HTTP transport support. Built with TypeScript, Express, and Turf.js.

## Features

- **Calculate Distance**: Compute distance between two geographic points in kilometers
- **Geocode Address**: Convert addresses to coordinates using Google Maps Geocoding API
- **Find Points in Radius**: Filter points within a specified radius from a center point
- **Calculate Area**: Calculate the area of a polygon in square kilometers

## Transport Support

- **SSE (Server-Sent Events)**: Full MCP protocol support
- **HTTP/POST**: Direct REST API endpoints for tool calls

## Prerequisites

- Node.js 20.x or higher
- Google Maps API key (for geocoding)
- Docker (optional, for containerized deployment)

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd magma_soup_mcp
```

2. Install dependencies:
```bash
npm install
```

3. Set up environment variables:
```bash
cp .env.example .env
# Edit .env and add your Google Maps API key
```

Required environment variables:
- `GOOGLE_MAPS_API_KEY`: Your Google Maps Geocoding API key
- `PORT`: Server port (default: 3000)

## Usage

### Development Mode

```bash
npm run dev
```

### Production Mode

```bash
npm run build
npm start
```

### Docker

```bash
# Build and run with Docker Compose
docker compose up -d

# Or build manually
docker build -t magma-soup-mcp .
docker run -p 3000:3000 -e GOOGLE_MAPS_API_KEY=your_key magma-soup-mcp
```

## API Endpoints

### Health Check
```bash
GET /health
```

### SSE Transport (MCP Protocol)
```bash
GET /sse
POST /messages
```

### HTTP Tools

**List Available Tools**
```bash
POST /tools/list
```

**Call a Tool**
```bash
POST /tools/call
Content-Type: application/json

{
  "name": "tool_name",
  "arguments": { ... }
}
```

## Tool Examples

### Calculate Distance

Calculate the distance between New York City and Los Angeles:

```bash
curl -X POST http://localhost:3000/tools/call \
  -H "Content-Type: application/json" \
  -d '{
    "name": "calculate_distance",
    "arguments": {
      "point1": {"lat": 40.7128, "lon": -74.0060},
      "point2": {"lat": 34.0522, "lon": -118.2437}
    }
  }'
```

Response:
```json
{
  "content": [
    {"type": "text", "text": "Distance: 3935.75 km"}
  ]
}
```

### Geocode Address

Convert an address to coordinates:

```bash
curl -X POST http://localhost:3000/tools/call \
  -H "Content-Type: application/json" \
  -d '{
    "name": "geocode_address",
    "arguments": {
      "address": "1600 Amphitheatre Parkway, Mountain View, CA"
    }
  }'
```

Response:
```json
{
  "content": [
    {
      "type": "text",
      "text": "{\n  \"address\": \"1600 Amphitheatre Pkwy, Mountain View, CA 94043, USA\",\n  \"lat\": 37.4224764,\n  \"lon\": -122.0842499\n}"
    }
  ]
}
```

### Find Points in Radius

Find points within a specified radius:

```bash
curl -X POST http://localhost:3000/tools/call \
  -H "Content-Type: application/json" \
  -d '{
    "name": "find_points_in_radius",
    "arguments": {
      "center": {"lat": 40.7128, "lon": -74.0060},
      "radius": 50,
      "points": [
        {"name": "Point A", "lat": 40.7589, "lon": -73.9851},
        {"name": "Point B", "lat": 41.8781, "lon": -87.6298}
      ]
    }
  }'
```

### Calculate Area

Calculate the area of a polygon:

```bash
curl -X POST http://localhost:3000/tools/call \
  -H "Content-Type: application/json" \
  -d '{
    "name": "calculate_area",
    "arguments": {
      "coordinates": [
        [-74.0, 40.7],
        [-74.0, 40.8],
        [-73.9, 40.8],
        [-73.9, 40.7]
      ]
    }
  }'
```

Response:
```json
{
  "content": [
    {"type": "text", "text": "Area: 123.45 km²"}
  ]
}
```

## Tool Schemas

### calculate_distance

**Input:**
```typescript
{
  point1: { lat: number, lon: number },
  point2: { lat: number, lon: number }
}
```

### geocode_address

**Input:**
```typescript
{
  address: string
}
```

### find_points_in_radius

**Input:**
```typescript
{
  center: { lat: number, lon: number },
  radius: number,  // in kilometers
  points: Array<{
    name?: string,
    lat: number,
    lon: number
  }>
}
```

### calculate_area

**Input:**
```typescript
{
  coordinates: Array<[lon, lat]>  // Array of [longitude, latitude] pairs
}
```

## Development

### Project Structure

```
magma_soup_mcp/
├── src/
│   └── index.ts          # Main server implementation
├── dist/                 # Compiled JavaScript (generated)
├── .env                  # Environment variables (not committed)
├── .env.example          # Environment template
├── package.json          # Dependencies and scripts
├── tsconfig.json         # TypeScript configuration
├── Dockerfile            # Container image definition
└── docker-compose.yml    # Container orchestration
```

### Scripts

- `npm run dev` - Run in development mode with hot reload
- `npm run build` - Compile TypeScript to JavaScript
- `npm start` - Run compiled production server

### Technology Stack

- **Runtime**: Node.js 20
- **Language**: TypeScript
- **Framework**: Express.js
- **MCP SDK**: @modelcontextprotocol/sdk
- **Geospatial**: Turf.js
- **Geocoding**: Google Maps Geocoding API

## License

ISC

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.
