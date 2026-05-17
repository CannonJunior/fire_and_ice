import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';

// ── Palette (matches settings_panel.dart) ─────────────────────────────────────

const _kBg2    = Color(0xFF111120);
const _kBorder = Color(0xFF1E2A3A);
const _kAccent = Color(0xFF00AAFF);
const _kText   = Color(0xFFCCDDEE);
const _kDim    = Color(0xFF556677);
const _kGreen  = Color(0xFF00CC66);
const _kRed    = Color(0xFFCC3333);
const _kAmber  = Color(0xFFFFAA00);

// ── Public widget ─────────────────────────────────────────────────────────────

/// Fetches /test_results.json (written by tests/test_cockpit_ui.py) and
/// displays a pass/fail list inside the Settings panel TEST STATUS section.
class TestStatusWidget extends StatefulWidget {
  const TestStatusWidget({super.key});

  @override
  State<TestStatusWidget> createState() => _TestStatusWidgetState();
}

class _TestStatusWidgetState extends State<TestStatusWidget> {
  _Results? _results;
  bool      _loading = false;
  String?   _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final text = await html.HttpRequest.getString('/test_results.json');
      final data = jsonDecode(text) as Map<String, dynamic>;
      setState(() {
        _results = _Results.fromJson(data);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'No results found.\nRun: python3 tests/test_cockpit_ui.py';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // ── Header row: summary + refresh ──────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        child: Row(children: [
          _summary(),
          const Spacer(),
          GestureDetector(
            onTap: _loading ? null : _fetch,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color:  const Color(0xFF0A1020),
                border: Border.all(color: _loading ? _kDim : _kAccent),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(_loading ? '…' : '↺ Refresh',
                  style: TextStyle(
                    color: _loading ? _kDim : _kAccent,
                    fontSize: 9, fontWeight: FontWeight.bold,
                  )),
            ),
          ),
        ]),
      ),
      // ── How to run ─────────────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        child: Text('Run: python3 tests/test_cockpit_ui.py',
            style: const TextStyle(color: _kDim, fontSize: 8,
                fontFamily: 'monospace')),
      ),
      // ── Error or test list ─────────────────────────────────────────────────
      if (_error != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Text(_error!,
              style: const TextStyle(color: _kAmber, fontSize: 9)),
        )
      else if (_results != null)
        ..._results!.tests.map(_testRow),
    ]);
  }

  Widget _summary() {
    if (_loading) {
      return const SizedBox(
        width: 14, height: 14,
        child: CircularProgressIndicator(strokeWidth: 1.5,
            color: _kAccent),
      );
    }
    if (_results == null) return const SizedBox.shrink();
    final r = _results!;
    final allPass = r.passed == r.total;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('${r.passed}/${r.total}',
          style: TextStyle(
            color: allPass ? _kGreen : _kRed,
            fontSize: 13, fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          )),
      const SizedBox(width: 6),
      Text(r.timestamp,
          style: const TextStyle(color: _kDim, fontSize: 8)),
    ]);
  }

  Widget _testRow(_TestResult t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(children: [
        Text(t.passed ? '✓' : '✗',
            style: TextStyle(
              color: t.passed ? _kGreen : _kRed,
              fontSize: 10, fontWeight: FontWeight.bold,
            )),
        const SizedBox(width: 6),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.name,
                style: TextStyle(
                  color: t.passed ? _kText : _kRed,
                  fontSize: 9,
                )),
            if (!t.passed && t.detail.isNotEmpty)
              Text(t.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _kAmber, fontSize: 8)),
          ],
        )),
      ]),
    );
  }
}

// ── Data models ───────────────────────────────────────────────────────────────

class _Results {
  final String         timestamp;
  final int            passed;
  final int            total;
  final List<_TestResult> tests;

  _Results({required this.timestamp, required this.passed,
      required this.total, required this.tests});

  factory _Results.fromJson(Map<String, dynamic> j) => _Results(
    timestamp: j['timestamp'] as String? ?? '',
    passed:    j['passed']    as int?    ?? 0,
    total:     j['total']     as int?    ?? 0,
    tests:     (j['tests'] as List<dynamic>? ?? [])
        .map((e) => _TestResult.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class _TestResult {
  final String name;
  final bool   passed;
  final String detail;

  _TestResult({required this.name, required this.passed, required this.detail});

  factory _TestResult.fromJson(Map<String, dynamic> j) => _TestResult(
    name:   j['name']   as String? ?? '',
    passed: j['passed'] as bool?   ?? false,
    detail: j['detail'] as String? ?? '',
  );
}
