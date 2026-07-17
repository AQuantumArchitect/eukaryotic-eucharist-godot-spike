extends Label
## Scans render.events (getRenderProjection().events, graph_kernel.mjs:7788 — the same
## world.events.slice() array index.html's checkDeathEvent() scans) for one-shot notices each
## frame — no pub/sub, just an array read, matching the original's own approach. Shows the newest
## event's `type` for SHOW_SECONDS (index.html's toast() uses 1.6s, index.html:1234), then clears.

const SHOW_SECONDS := 1.6

var _timer := 0.0

func apply(events: Array, delta: float) -> void:
	if not events.is_empty():
		var last: Dictionary = events[events.size() - 1]
		text = String(last.get("type", "?"))
		_timer = SHOW_SECONDS
		return
	if _timer > 0.0:
		_timer -= delta
		if _timer <= 0.0:
			text = ""
