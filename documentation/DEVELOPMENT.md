# Development Guide

## Project Structure

- `lib/models/` - Data models for panel elements and protocol messages
- `lib/services/` - Services for communication and file parsing
- `lib/screens/` - UI screens for the application
- `lib/widgets/` - Reusable UI components like faders and meters
- `lib/utils/` - Utility functions and helpers

## Development Workflow

1. Parse panel files to extract control elements
2. Build UI representations of these elements
3. Implement protocol communication to control devices
4. Link UI actions to protocol commands

## Implementation Notes

### Panel Parsing
Panel files are XML documents that define control interfaces. The parser needs to:
- Extract control element properties
- Identify relationships between controls
- Map controls to their parameters

### Protocol Implementation
The London Direct Inject protocol uses messages with this structure:
- Message start: 0x02
- Message body: [format details]
- Checksum: XOR of all bytes
- Message end: 0x03