import 'dart:convert';

import '../../domain/domain.dart';
import '../expenses/category_icons.dart';

/// Builds a self-contained offline HTML report for a full backup package.
String buildBackupHtmlReport({
  required Map<String, dynamic> backupJson,
  required List<Group> groups,
  required List<Expense> expenses,
  required DateTime exportedAt,
  String locale = 'en',
  List<ExpenseTag> expenseTags = const [],
}) {
  final embed = const JsonEncoder().convert(backupJson);
  final tagsByGroup = <String, List<ExpenseTag>>{};
  for (final t in expenseTags) {
    tagsByGroup.putIfAbsent(t.groupId, () => []).add(t);
  }
  final groupRows = StringBuffer();
  for (final g in groups) {
    final groupExpenses = expenses.where((e) => e.groupId == g.id).toList();
    final groupTags = tagsByGroup[g.id] ?? const <ExpenseTag>[];
    final total = groupExpenses.fold<int>(
      0,
      (s, e) => s + e.effectiveBaseAmountCents,
    );
    groupRows.writeln('<section class="group" data-group="${_esc(g.id)}">');
    groupRows.writeln(
      '<h2>${_esc(g.name)} <span class="meta">${_esc(g.currencyCode)} · ${groupExpenses.length}</span></h2>',
    );
    groupRows.writeln(
      '<p class="total">Total (base): ${_money(total, g.currencyCode)}</p>',
    );
    groupRows.writeln(
      '<table><thead><tr>'
      '<th>Date</th><th>Title</th><th>Amount</th><th>Tag</th>'
      '</tr></thead><tbody>',
    );
    for (final e in groupExpenses) {
      final tagLabel = exportDisplayTagLabel(e.tag, groupTags);
      groupRows.writeln(
        '<tr>'
        '<td>${_esc(e.date.toIso8601String().split('T').first)}</td>'
        '<td>${_esc(e.title)}</td>'
        '<td>${_money(e.amountCents, e.currencyCode)}</td>'
        '<td>${_esc(tagLabel)}</td>'
        '</tr>',
      );
    }
    groupRows.writeln('</tbody></table></section>');
  }

  return '''<!DOCTYPE html>
<html lang="${_esc(locale)}">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>Hisab backup</title>
<style>
body{font-family:system-ui,sans-serif;margin:1.5rem;color:#1a1a1a;background:#fafafa;line-height:1.45}
h1{font-size:1.6rem;margin:0 0 .25rem}
.sub{color:#555;margin-bottom:1.25rem}
input{width:min(420px,100%);padding:.5rem .75rem;margin-bottom:1rem;border:1px solid #ccc;border-radius:6px}
.group{background:#fff;border:1px solid #e5e5e5;border-radius:8px;padding:1rem;margin-bottom:1rem}
.group h2{font-size:1.15rem;margin:0 0 .35rem}
.meta,.total{color:#666;font-size:.9rem}
table{width:100%;border-collapse:collapse;font-size:.92rem}
th,td{text-align:left;padding:.35rem .4rem;border-bottom:1px solid #eee}
th{color:#444;font-weight:600}
.hidden{display:none}
</style>
</head>
<body>
<h1>Hisab backup</h1>
<p class="sub">Exported ${_esc(exportedAt.toIso8601String())} · ${groups.length} groups · ${expenses.length} expenses · offline</p>
<input id="q" type="search" placeholder="Filter by title or group…" autocomplete="off"/>
<div id="groups">
$groupRows
</div>
<script type="application/json" id="backup-data">$embed</script>
<script>
(function(){
  var q=document.getElementById('q');
  var sections=document.querySelectorAll('.group');
  q.addEventListener('input',function(){
    var term=(q.value||'').toLowerCase();
    sections.forEach(function(sec){
      var text=sec.textContent.toLowerCase();
      sec.classList.toggle('hidden', term && text.indexOf(term)===-1);
    });
  });
})();
</script>
</body>
</html>
''';
}

String _esc(String s) {
  return const HtmlEscape().convert(s);
}

String _money(int cents, String currency) {
  final v = (cents / 100).toStringAsFixed(2);
  return _esc('$v $currency');
}
