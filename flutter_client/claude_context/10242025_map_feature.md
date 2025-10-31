### Planning the mapping architecture

Now I want to plan for adding mapping capabilities. I don't want anything developed yet, I just want to talk requirements and options.

Our starting use case was to make the app capable of answering the questions: How far is it from Portland, OR to Seattle, WA? This question results in an answer that can be mapped: a map can be displayed with points on the two cities and a line between them. If we added routing capabilites, it could highlight a route on roads. If we added many capabilities, then there could be many different things that could be mapped: areas, results of analysis, etc. The app needs to figure out if there actually is anything to map and then go fetch and/or generate the data needed to add the visualization to our map. We need to figure all of this out. We can start with our simple use case of mapping the distance between two cities, but we need to be thinking about how we would extend this.

Would we need to store geospatial data on the client? Converations could result in more and more data being layered on.

Think about this problem and give me your thoughts.

#### Resulting plan

Mapping Architecture for Magma Soup

Problem Statement

The application needs to visualize geospatial data generated during conversations. Starting use case: "How far is it from Portland, OR to Seattle, WA?" should produce a map showing both cities and the distance between them.

Requirements:

- Determine when conversation results are mappable
- Generate or fetch geodata needed for visualization
- Render geodata on the map
- Manage accumulating layers as conversations progress
- Support extensibility for routing, areas, spatial analysis, etc.

Architecture Overview

Core Principle: Separation of Concerns

Main LLM: Answers user questions, uses geospatial tools when needed
Map Decision LLM: Separate call at end of turn, determines map visualization changes
MCP Server: Provides geospatial tools and geodata generation
Client: Renders map, manages local state, persists to SQLite

Data Flow

1. User asks question
2. Main LLM processes query

- Uses MCP tools (geocode_address, calculate_distance, etc.)
- Returns natural language response to user

3. [End of Turn Trigger]
4. Map Decision System executes:

- Input: Conversation summary, current map state, tools called this turn
- Independent LLM call determines: what should change on map?
- Output: Structured instructions (add/remove/update features)

5. Client applies map changes:

- Updates map layers
- Persists to SQLite
- Renders updated visualization

Component Details

1. MCP Server (magma_soup_mcp)

Existing Tools:

- geocode_address - Address → coordinates via Nominatim
- calculate_distance - Distance between two points
- find_points_in_radius - Spatial filtering
- calculate_area - Polygon area calculation

Proposed Additions:

- generate_geojson - Convert semantic descriptions to GeoJSON
  - Input: "line between Portland and Seattle with points at each city"
  - Output: GeoJSON FeatureCollection
- generate_route - Road routing between points (requires routing service)
- Additional analysis tools as needed (buffer, intersection, etc.)

Data Format: GeoJSON (standard for web mapping)

2. Map Decision System

Purpose: Separate LLM call that determines visualization changes

Input:
{
"conversation_summary": "User asked distance Portland to Seattle. Geocoded both cities, calculated 173 miles.",
"current_map_state": {
"features": [...existing GeoJSON features...],
"layers": [...layer metadata...]
},
"turn_data": {
"tools_called": [
{"tool": "geocode_address", "args": {"address": "Portland, OR"}, "result": {...}},
{"tool": "geocode_address", "args": {"address": "Seattle, WA"}, "result": {...}},
{"tool": "calculate_distance", "result": "173 miles"}
],
"llm_response": "The distance from Portland to Seattle is approximately 173 miles."
}
}

Output:
{
"actions": [
{
"action": "add_feature",
"layer_id": "cities",
"feature": {
"type": "Feature",
"geometry": {"type": "Point", "coordinates": [-122.6765, 45.5231]},
"properties": {"name": "Portland, OR", "type": "city"}
}
},
{
"action": "add_feature",
"layer_id": "cities",
"feature": {
"type": "Feature",
"geometry": {"type": "Point", "coordinates": [-122.3321, 47.6062]},
"properties": {"name": "Seattle, WA", "type": "city"}
}
},
{
"action": "add_feature",
"layer_id": "measurements",
"feature": {
"type": "Feature",
"geometry": {
"type": "LineString",
"coordinates": [[-122.6765, 45.5231], [-122.3321, 47.6062]]
},
"properties": {"distance": "173 miles", "label": "Portland to Seattle"}
}
}
]
}

Prompt Strategy:

- System prompt: "You are a map visualization expert. Given conversation context and tool outputs, determine what should be displayed on the map."
- Include rules: "Add new features for geographic queries. Remove or update conflicting visualizations. Group related features into logical layers."

3. SQLite Persistence

Purpose: Store conversation state and geodata together

Proposed Schema:

-- Conversation turns
CREATE TABLE turns (
id INTEGER PRIMARY KEY AUTOINCREMENT,
timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
user_message TEXT NOT NULL,
llm_response TEXT NOT NULL,
tools_called TEXT, -- JSON array of tool calls
conversation_summary TEXT
);

-- Map features (GeoJSON)
CREATE TABLE features (
id INTEGER PRIMARY KEY AUTOINCREMENT,
turn_id INTEGER REFERENCES turns(id),
layer_id TEXT NOT NULL, -- logical grouping (e.g., 'cities', 'routes', 'measurements')
feature_data TEXT NOT NULL, -- Complete GeoJSON Feature as JSON
created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
active BOOLEAN DEFAULT 1 -- Can be toggled off without deletion
);

-- Layer metadata
CREATE TABLE layers (
id TEXT PRIMARY KEY, -- e.g., 'cities', 'routes'
name TEXT NOT NULL,
description TEXT,
visible BOOLEAN DEFAULT 1,
style_config TEXT -- JSON for rendering hints
);

CREATE INDEX idx_features_layer ON features(layer_id);
CREATE INDEX idx_features_turn ON features(turn_id);

Package: sqflite for Flutter

Session Scope: Initial implementation clears on app restart. Future: persist across sessions.

4. Client Map State Manager (Flutter)

Responsibilities:

- Maintain current map state (features, layers)
- Apply map decision actions
- Provide API for map widget
- Handle SQLite persistence

Key Classes:

class MapStateManager {
final Database \_db;
final Map<String, List<Feature>> \_layerFeatures = {};

    Future<void> applyMapDecision(MapDecision decision);
    Future<List<Feature>> getFeaturesForLayer(String layerId);
    Future<void> toggleLayer(String layerId, bool visible);
    Future<void> clearAllFeatures();
    Future<void> loadStateFromDb();

}

class Feature {
final String id;
final String layerId;
final int? turnId;
final Map<String, dynamic> geoJson; // Complete GeoJSON Feature
bool active;
}

class MapDecision {
final List<MapAction> actions;
}

class MapAction {
final String action; // 'add_feature', 'remove_feature', 'update_feature'
final String layerId;
final Map<String, dynamic>? feature;
final String? featureId;
}

5. Map Widget Updates

Current: Basic FlutterMap with OSM tiles

Needed:

- GeoJSON layer rendering (flutter_map supports via MarkerLayer, PolylineLayer, PolygonLayer)
- Layer toggle UI
- Feature styling based on layer configuration
- Interactive features (click for properties)

Extension Paths

Routing

- Add generate_route tool to MCP server
- Integrate routing service (OSRM, Valhalla, or GraphHopper)
- Return LineString with route geometry + turn-by-turn data
- Map decision LLM handles route display vs. straight-line distance

Spatial Analysis

- Buffer zones: "Show 5-mile radius around Portland"
- Intersections: "Which cities are within this polygon?"
- Area calculations: "What's the area of this watershed?"
- Tools return analysis results as GeoJSON

Multiple Queries

- "Show me Portland to Seattle" → features added
- "Now show me San Francisco to LA" → new features added to existing map
- "Clear the Seattle route" → specific features removed
- Layers group related features for toggle/management

Advanced Visualization

- Choropleth maps (color-coded regions)
- Heatmaps (density visualization)
- 3D terrain (elevation data)
- Custom styling per feature type

Open Questions

1. GeoJSON Generation: Should MCP server have explicit generate_geojson tool, or should Map Decision LLM construct GeoJSON from tool results?
2. Layer Strategy:


    - Auto-assign layers by feature type (points → "cities", lines → "routes")?
    - Let Map Decision LLM decide layer assignment?
    - User-defined layers?

3. Conflict Resolution: When user asks contradictory questions, should old visualizations:


    - Remain visible (accumulate)?
    - Be replaced?
    - Be dimmed but kept?

4. Map Decision Trigger: Currently "end of turn" - but should it also run:


    - On explicit user request ("update the map")?
    - Only when tools were called?
    - Every turn regardless?

5. Styling: Who decides feature appearance?


    - Client has default styles per layer?
    - Map Decision LLM includes styling hints?
    - User preferences override?

Implementation Phases

Phase 1: Basic Point-to-Point (Portland → Seattle)

- Set up SQLite schema
- Implement Map Decision LLM call
- Add MapStateManager
- Render points and lines on map
- Persist to SQLite

Phase 2: Layer Management

- Layer toggle UI
- Multiple simultaneous features
- Clear/reset functionality

Phase 3: Routing

- Add routing tool to MCP server
- Map Decision handles route display
- Turn-by-turn visualization

Phase 4: Advanced Features

- Polygons and areas
- Spatial analysis results
- Complex styling
- Cross-session persistence

Technology Stack

- Client: Flutter (Dart) with flutter_map, sqflite
- MCP Server: TypeScript/Node.js, Express, Turf.js
- LLM: Anthropic Claude (main + map decision)
- Data Format: GeoJSON (RFC 7946)
- Map Tiles: OpenStreetMap
- Persistence: SQLite (sqflite package)

### Adding a placeholder

I want to add a new feature to the results pane. Eventually, it will be where results get mapped when they are mappable. For now, I just want to add a basic map using flutter_map to that pane. It can go at the top of the right pane and stick there, while the results and logging can go underneath it and scroll.
