// lib/widgets/zone_drawer.dart
//
// Side drawer with:
//   • Accordion hierarchy: Continent → Country → Region → Zone items
//   • Checkbox per zone (checked = fog on, default; unchecked = fog off)
//   • Programmatic expand + scroll when [highlightId] changes (map tap)
//   • Zone items numbered within their parent group

import 'package:flutter/material.dart';
import '../models/zone_model.dart';
import '../services/zone_service.dart';

class ZoneDrawer extends StatefulWidget {
  final ZoneService zoneService;

  /// When set, the drawer scrolls to and highlights this zone.
  final String? highlightId;

  const ZoneDrawer({
    super.key,
    required this.zoneService,
    this.highlightId,
  });

  @override
  State<ZoneDrawer> createState() => ZoneDrawerState();
}

class ZoneDrawerState extends State<ZoneDrawer> {
  final ScrollController _scroll = ScrollController();

  // ExpansionTile controllers keyed by group path.
  final Map<String, ExpansionTileController> _tileControllers = {};

  // GlobalKey per zone item for scroll-to.
  final Map<String, GlobalKey> _zoneKeys = {};

  @override
  void initState() {
    super.initState();
    widget.zoneService.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.zoneService.removeListener(_rebuild);
    _scroll.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  /// Public API for parent: force expand + scroll to a zone id.
  void scrollToZone(String id) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToZone(id));
  }

  @override
  void didUpdateWidget(ZoneDrawer old) {
    super.didUpdateWidget(old);
    if (widget.highlightId != old.highlightId &&
        widget.highlightId != null) {
      // Run after the frame so the list is built with the new highlight.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToZone(widget.highlightId!));
    }
  }

  // ── Scroll / expand logic ──────────────────────────────────────────────────

  Future<void> _scrollToZone(String id) async {
    final zone = widget.zoneService.namedZones
        .where((z) => z.id == id)
        .firstOrNull;
    if (zone == null) return;

    Future<void> expandAndWait(String key) async {
      _tileControllers[key]?.expand();
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    final cKey = zone.continent ?? 'Unknown';
    final ctKey = '$cKey\u0000${zone.country ?? 'Unknown'}';
    final rKey = zone.region != null ? '$ctKey\u0000${zone.region}' : null;

    await expandAndWait(cKey);
    await expandAndWait(ctKey);
    if (rKey != null) await expandAndWait(rKey);

    // Scroll the item into view.
    final ctx = _zoneKeys[id]?.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    }
  }

  ExpansionTileController _controller(String key) =>
      _tileControllers.putIfAbsent(key, ExpansionTileController.new);

  GlobalKey _zoneKey(String id) =>
      _zoneKeys.putIfAbsent(id, GlobalKey.new);

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final zones = widget.zoneService.namedZones;

    // continent → country → region? → zones
    final Map<String, Map<String, Map<String?, List<Zone>>>> grouped = {};
    for (final z in zones) {
      final c = z.continent ?? 'Unknown';
      final ct = z.country ?? 'Unknown';
      grouped.putIfAbsent(c, () => {}).putIfAbsent(ct, () => {});
      grouped[c]![ct]!.putIfAbsent(z.region, () => []).add(z);
    }

    final continents = grouped.keys.toList()..sort();

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.public),
                  const SizedBox(width: 12),
                  Text(
                    'Зоны тумана',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  Text(
                    '${zones.length} зон',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── Zone list ──────────────────────────────────────────────────
            Expanded(
              child: zones.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Зоны появятся по мере\nпросмотра карты',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      itemCount: continents.length,
                      itemBuilder: (_, ci) {
                        final continent = continents[ci];
                        return _ContinentTile(
                          continent: continent,
                          countries: grouped[continent]!,
                          controller: _controller(continent),
                          highlightId: widget.highlightId,
                          childController: _controller,
                          zoneKey: _zoneKey,
                          onToggle: (id, v) =>
                              widget.zoneService.setZoneEnabled(id, v),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ContinentTile extends StatelessWidget {
  const _ContinentTile({
    required this.continent,
    required this.countries,
    required this.controller,
    required this.highlightId,
    required this.childController,
    required this.zoneKey,
    required this.onToggle,
  });

  final String continent;
  final Map<String, Map<String?, List<Zone>>> countries;
  final ExpansionTileController controller;
  final String? highlightId;
  final ExpansionTileController Function(String) childController;
  final GlobalKey Function(String) zoneKey;
  final void Function(String id, bool enabled) onToggle;

  @override
  Widget build(BuildContext context) {
    final sortedCountries = countries.keys.toList()..sort();
    return ExpansionTile(
      controller: controller,
      leading: const Icon(Icons.public, size: 20),
      title: Text(continent,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      children: sortedCountries.map((country) {
        final cKey = '$continent\u0000$country';
        return _CountryTile(
          continent: continent,
          country: country,
          regions: countries[country]!,
          controller: childController(cKey),
          highlightId: highlightId,
          childController: childController,
          zoneKey: zoneKey,
          onToggle: onToggle,
        );
      }).toList(),
    );
  }
}

class _CountryTile extends StatelessWidget {
  const _CountryTile({
    required this.continent,
    required this.country,
    required this.regions,
    required this.controller,
    required this.highlightId,
    required this.childController,
    required this.zoneKey,
    required this.onToggle,
  });

  final String continent;
  final String country;
  final Map<String?, List<Zone>> regions;
  final ExpansionTileController controller;
  final String? highlightId;
  final ExpansionTileController Function(String) childController;
  final GlobalKey Function(String) zoneKey;
  final void Function(String id, bool enabled) onToggle;

  @override
  Widget build(BuildContext context) {
    final sortedRegions = regions.keys.toList()
      ..sort((a, b) {
        if (a == null) return -1;
        if (b == null) return 1;
        return a.compareTo(b);
      });

    final children = <Widget>[];
    int globalIndex = 1;

    for (final region in sortedRegions) {
      final zoneList = regions[region]!..sort((a, b) => a.id.compareTo(b.id));

      if (region == null) {
        // Zones directly under country (no region)
        for (final zone in zoneList) {
          children.add(_ZoneTile(
            zone: zone,
            index: globalIndex++,
            isHighlighted: zone.id == highlightId,
            itemKey: zoneKey(zone.id),
            onToggle: onToggle,
          ));
        }
      } else {
        final rKey = '$continent\u0000$country\u0000$region';
        children.add(_RegionTile(
          region: region,
          zones: zoneList,
          controller: childController(rKey),
          startIndex: globalIndex,
          highlightId: highlightId,
          zoneKey: zoneKey,
          onToggle: onToggle,
        ));
        globalIndex += zoneList.length;
      }
    }

    return ExpansionTile(
      controller: controller,
      leading: const Icon(Icons.flag_outlined, size: 18),
      title: Text(country),
      children: children,
    );
  }
}

class _RegionTile extends StatelessWidget {
  const _RegionTile({
    required this.region,
    required this.zones,
    required this.controller,
    required this.startIndex,
    required this.highlightId,
    required this.zoneKey,
    required this.onToggle,
  });

  final String region;
  final List<Zone> zones;
  final ExpansionTileController controller;
  final int startIndex;
  final String? highlightId;
  final GlobalKey Function(String) zoneKey;
  final void Function(String id, bool enabled) onToggle;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      controller: controller,
      leading: const Icon(Icons.location_city_outlined, size: 16),
      title: Text(region, style: const TextStyle(fontSize: 13)),
      children: [
        for (int i = 0; i < zones.length; i++)
          _ZoneTile(
            zone: zones[i],
            index: startIndex + i,
            isHighlighted: zones[i].id == highlightId,
            itemKey: zoneKey(zones[i].id),
            onToggle: onToggle,
          ),
      ],
    );
  }
}

class _ZoneTile extends StatelessWidget {
  const _ZoneTile({
    required this.zone,
    required this.index,
    required this.isHighlighted,
    required this.itemKey,
    required this.onToggle,
  });

  final Zone zone;
  final int index;
  final bool isHighlighted;
  final GlobalKey itemKey;
  final void Function(String id, bool enabled) onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: itemKey,
      color: isHighlighted ? colorScheme.primaryContainer.withValues(alpha: 0.4) : null,
      child: CheckboxListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 56, right: 12),
        title: Text(
          '$index. ${zone.panelTitle}',
          style: const TextStyle(fontSize: 12),
        ),
        // checked = fog is ON (enabled = true)
        value: zone.enabled,
        onChanged: (v) => onToggle(zone.id, v ?? true),
        controlAffinity: ListTileControlAffinity.trailing,
      ),
    );
  }
}
