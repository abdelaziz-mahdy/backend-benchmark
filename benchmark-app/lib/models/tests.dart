// Plain names of the kinds of work (test scenarios). No imports, so any
// model file can use it without an import cycle.

/// A kind of work, in plain words.
class TestInfo {
  final String id;

  /// "A typical app".
  final String title;

  /// "Typical app": table headings and tabs.
  final String short;

  /// One line on what the requests do.
  final String what;

  const TestInfo(this.id, this.title, this.short, this.what);

  /// The title inside a sentence: "a typical app", "only reading".
  String get inSentence => title[0].toLowerCase() + title.substring(1);
}

/// Display order: the closest to a real app first.
const kTestOrder = [
  'db_mixed',
  'db_read',
  'db_write',
  'no_db',
  'db_test',
  'no_db_test',
];

TestInfo testInfo(String id) => switch (id) {
  'db_mixed' => const TestInfo(
    'db_mixed',
    'A typical app',
    'Typical app',
    '8 in 10 requests read data and 2 in 10 save new data.',
  ),
  'db_read' => const TestInfo(
    'db_read',
    'Only reading',
    'Only reading',
    'Every request reads data from the database.',
  ),
  'db_write' => const TestInfo(
    'db_write',
    'Only saving',
    'Only saving',
    'Every request saves new data to the database.',
  ),
  'no_db' => const TestInfo(
    'no_db',
    'No database',
    'No database',
    "Every request gets a tiny fixed reply, with no database. This shows "
        "the framework's own speed.",
  ),
  'db_test' => const TestInfo(
    'db_test',
    'Reading and saving',
    'Reading and saving',
    'The old test: requests listed every row or saved a new one.',
  ),
  'no_db_test' => const TestInfo(
    'no_db_test',
    'No database',
    'No database',
    'The old test: the server sent back a small fixed reply.',
  ),
  _ => TestInfo(id, id, id, ''),
};
