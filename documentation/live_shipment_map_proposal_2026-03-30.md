# Live Shipment Map Proposal

Date: 2026-03-30

## Purpose

This document proposes the `Live Shipment Map` feature as the next high-impact enhancement for the Halal Traceability System.

The goal is to upgrade the product from a traceability record system into a more professional, platform-like system by visualizing real shipment routes on a map.

This document is intended for discussion before implementation.

## Recommendation

If only one "premium" feature is added next, `Live Shipment Map` should be prioritized first.

Reason:

- the system already stores real `latitude` and `longitude` values in logistics checkpoints
- consumer traceability already loads real checkpoint history
- the main gap is presentation, not missing core business data
- the feature is highly visible in demos, presentations, and supervisor review
- it creates a strong foundation for later features such as `Risk Score` and `Smart Alerts`

## Why This Feature First

Compared with other enhancement ideas, `Live Shipment Map` has the best balance of:

- strong visual impact
- low backend disruption
- direct reuse of existing data
- immediate improvement for multiple roles

It improves the system for:

- `Consumer`: can see the actual journey instead of only reading a timeline
- `Admin`: can inspect route progress more like a real monitoring platform
- `Logistics`: can later view assigned shipment movement more clearly

## Current System Readiness

The current project already has the required foundation:

- logistics checkpoint submission stores `latitude` and `longitude`
- public consumer batch detail already returns checkpoint coordinates
- authenticated batch detail already includes checkpoint history
- consumer UI already renders a checkpoint-based timeline

This means the feature is not a new business workflow. It is mainly a data visualization upgrade built on top of existing traceability data.

## Current Limitation

At present, the system records real GPS-related shipment events, but the user interface still presents supply chain movement mainly as a timeline list.

This creates a gap between:

- what the backend already knows
- what the user can visually understand

As a result, the system feels functional but not yet "platform-grade" in presentation.

## Proposed MVP Scope

The first version should stay small and focused.

### Core Deliverable

Display shipment checkpoints as a route map inside batch detail screens.

### MVP Capabilities

- show a map card inside batch detail
- draw route polyline from checkpoint coordinates
- show start, intermediate, and latest checkpoint markers
- show checkpoint details when a marker is tapped
- keep the existing timeline below the map
- gracefully handle batches with missing coordinates

### Out of Scope for MVP

The following should not be included in the first implementation:

- live auto-refresh
- push notifications
- route heatmaps
- geofencing
- ETA prediction
- multi-batch map dashboard
- risk scoring logic

## Proposed Rollout Order

The feature should be delivered in three phases.

### Phase 1: Consumer

Add the map to the consumer batch detail screen first.

Why:

- the consumer detail flow already fetches public batch checkpoint data
- this is the shortest implementation path
- it creates the strongest presentation effect with the least code risk

### Phase 2: Admin

Reuse the same map component in admin batch detail.

Why:

- admin already has a batch detail screen
- admin already fetches authenticated batch detail with checkpoints
- this expands the feature from presentation value into operational value

### Phase 3: Logistics

Add route-map detail for assigned shipments.

Why:

- logistics currently uses a summary route list
- this phase may require either reuse of existing batch detail or a dedicated route detail endpoint
- it is better done after the shared map component is stable

## UI/UX Proposal

### Consumer Screen

Current consumer detail structure:

- `Product Details`
- `Supply Chain`

Proposed update:

- keep `Product Details`
- keep `Supply Chain`
- add a route map at the top of the `Supply Chain` tab
- keep the timeline below the map

This is important because:

- the map gives visual proof
- the timeline still provides readable event explanation

### Admin Screen

Current admin batch detail already includes:

- header information
- product information
- transit timeline

Proposed update:

- add a `Transit Route` section above the timeline
- reuse the same route map component used by consumer

## Technical Design

### Frontend Package Choice

Recommended:

- `flutter_map`
- `latlong2`

Reason:

- lower setup cost than `google_maps_flutter`
- no immediate API key dependency for the first version
- faster for local demo and FYP presentation work
- easier to integrate into the current project structure

### Frontend File Structure

Recommended new files:

- `frontend/halal_traceability_app/lib/models/checkpoint_map_point.dart`
- `frontend/halal_traceability_app/lib/services/batch_route_mapper.dart`
- `frontend/halal_traceability_app/lib/widgets/route_map_card.dart`

Suggested responsibilities:

`checkpoint_map_point.dart`

- define a clean UI model for a map-ready checkpoint
- include lat/lng, label, time, action type, actor, temperature, notes

`batch_route_mapper.dart`

- transform raw API checkpoint payloads into map points
- filter out checkpoints without coordinates
- ensure correct order by timestamp
- prepare data for polyline and map bounds

`route_map_card.dart`

- render markers and route line
- show empty state when coordinates are unavailable
- display lightweight checkpoint detail popups

## Backend Impact

### Phase 1 and Phase 2

No backend schema change is required for the MVP.

Existing endpoints are sufficient:

- public batch detail for consumer
- authenticated batch detail for admin

### Notes

The system must tolerate incomplete coordinate history because some earlier checkpoints may not include latitude and longitude.

This is especially relevant for:

- early batch creation events
- legacy or demo data created before map usage

Therefore, the frontend must:

- ignore invalid map points
- still show the timeline even when the map cannot be drawn

## Data Handling Rules

The map layer should only use checkpoints that satisfy all of the following:

- `latitude` is present
- `longitude` is present
- both values are numeric

If valid map points are:

- `0`: show "Map unavailable for this batch yet"
- `1`: show a single location marker without route line
- `2 or more`: show markers and polyline

## Suggested Visual Elements

To keep the first version polished but controlled, the map should show only:

- start marker
- intermediate checkpoint markers
- latest checkpoint marker
- route polyline
- current batch status badge

Marker detail should show:

- location name
- timestamp
- action type
- temperature
- actor name

## Why Timeline Must Stay

The timeline should not be removed.

Reason:

- the map answers "where did it go?"
- the timeline answers "what happened at each step?"

Together they create a more complete traceability story.

## Risks and Constraints

### 1. Incomplete Coordinate Coverage

Some checkpoints may not have coordinates.

Mitigation:

- filter invalid points
- keep map optional
- retain timeline as the fallback source of truth

### 2. GPS Accuracy

Coordinates depend on emulator/device GPS quality.

Mitigation:

- treat the map as route visualization, not precise forensic positioning
- keep textual location names visible

### 3. Scope Creep

It is easy to over-expand the feature into alerts, analytics, and real-time monitoring.

Mitigation:

- keep MVP limited to batch detail route visualization
- defer monitoring features to later phases

## Strategic Value

This feature does more than improve appearance.

It also creates the best foundation for future enhancements:

- `Risk / Health Score`: risk badge can be placed directly on the map card
- `Smart Alerts`: alerts become more meaningful when users can see the route context
- `Admin Analytics`: route visualization supports a more platform-like admin experience

## Final Recommendation

Proceed with `Live Shipment Map` as the next enhancement, but keep the first release small:

1. implement shared route map component
2. ship consumer batch detail integration
3. reuse the same component in admin batch detail
4. evaluate logistics route detail as the next follow-up

This approach gives the strongest visible upgrade with the lowest implementation risk and the best reuse of the system's current architecture.
