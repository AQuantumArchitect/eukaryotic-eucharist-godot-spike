class_name ShopLogic
extends RefCounted
## Pure ports of index.html's organState()/buildRoutes()/primaryBuild()/buildCategoryOf()
## (index.html:1373-1399, :329-334) — UI decision logic over fields K.getYukiOfferings() already
## returns (graph_kernel.mjs:7280-7365), not simulation logic, so porting it here doesn't
## compromise "the kernel is the only source of truth." doBuy()'s own routing rule
## (index.html:1334-1336) is the other half: a "print_" route id goes to start_manufacturing,
## everything else goes to buy_offering — both already exist as KernelBridge wrappers.

static func org_state(o: Dictionary) -> String:
	if o.get("maxed", false):
		return "maxed"
	if o.get("kind") == "organelle":
		if o.get("genuineLock", false):
			return "lock"
		if o.get("graftBuyable", false) or o.get("rnaBuyable", false) or o.get("hasRNA", false) or o.get("expressable", false):
			return "ready"
		return "unaff"
	if not o.get("locked", false):
		return "ready"
	var reasons: Array = o.get("reasons", [])
	var only_money := reasons.size() > 0
	for r in reasons:
		if not String(r).begins_with("needs "):
			only_money = false
			break
	return "unaff" if only_money else "lock"

## Acquisition routes in index.html's own priority order: print (hold RNA + a ribosome) ->
## express (rack) -> bare graft -> graft+RNA. Each carries an `enabled` flag; primary_build picks
## the first enabled one — what a single tap/click fires.
static func build_routes(o: Dictionary, has_ribosome: bool, owned_count: int) -> Array:
	var organelle := String(o.get("organelle", ""))
	var routes := []
	if o.get("hasRNA", false) and has_ribosome:
		routes.append({"id": "print_" + String(o.get("id", "")), "label": "Print +1" if owned_count > 0 else "Print", "enabled": true})
	if o.get("expressable", false):
		routes.append({"id": "express_" + organelle, "label": "Express", "enabled": true})
	routes.append({"id": "buy_graft_" + organelle, "label": "Graft", "enabled": o.get("graftBuyable", false)})
	if not o.get("hasRNA", false):
		routes.append({"id": "buy_rna_" + organelle, "label": "Graft +RNA", "enabled": o.get("rnaBuyable", false)})
	return routes

static func primary_build(o: Dictionary, has_ribosome: bool, owned_count: int):
	if o.get("kind") != "organelle" or o.get("maxed", false) or o.get("genuineLock", false):
		return null
	for r in build_routes(o, has_ribosome, owned_count):
		if r.get("enabled", false):
			return r
	return null

## Simplified port of buildCategoryOf (index.html:329-334) — offerings already carry funcCategory
## directly (graph_kernel.mjs:7351), so this needs none of the client-side ORGAN_CATEGORY lookup
## the original did; the archive/eucharist special-casing here covers the common cases, not every
## edge case (recognizable grouping, not an exhaustive port).
static func category_of(o: Dictionary) -> String:
	if o.get("kind") == "sacrament" or o.get("kind") == "eucharist":
		return "eucharist"
	if o.get("tier3", false):
		return "archive"
	var fc = o.get("funcCategory")
	if fc != null:
		return String(fc)
	return "structure"
