class_name CedarDeskLayout
extends RefCounted
## Shared, testable layout and visibility rules for the Cedar Desk.

const UPPER_WORKSPACE_RATIO := 58.0
const LOWER_WORKSPACE_RATIO := 42.0
const ACTION_BOX_RATIO := 62.0
const CLAY_DOCKET_RATIO := 22.0
const ARCHIVE_STACK_RATIO := 16.0

static func evidence_visible(current_phase: String, map_is_open: bool) -> bool:
	return current_phase != "character_creation" and not map_is_open
