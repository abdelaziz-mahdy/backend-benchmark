/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _is;

abstract class Note implements _is.TableRow<int?>, _is.ProtocolSerialization {
  Note._({this.id, required this.title, required this.content});

  factory Note({int? id, required String title, required String content}) =
      _NoteImpl;

  factory Note.fromJson(Map<String, dynamic> jsonSerialization) {
    return Note(
      id: jsonSerialization['id'] as int?,
      title: jsonSerialization['title'] as String,
      content: jsonSerialization['content'] as String,
    );
  }

  static final t = NoteTable();

  static const db = NoteRepository._();

  @override
  int? id;

  String title;

  String content;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [Note]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  Note copyWith({int? id, String? title, String? content});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Note',
      if (id != null) 'id': id,
      'title': title,
      'content': content,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Note',
      if (id != null) 'id': id,
      'title': title,
      'content': content,
    };
  }

  static NoteInclude include() {
    return NoteInclude._();
  }

  static NoteIncludeList includeList({
    _is.WhereExpressionBuilder<NoteTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<NoteTable>? orderBy,
    _is.OrderByListBuilder<NoteTable>? orderByList,
    NoteInclude? include,
  }) {
    return NoteIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Note.t),
      orderByList: orderByList?.call(Note.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _NoteImpl extends Note {
  _NoteImpl({int? id, required String title, required String content})
    : super._(id: id, title: title, content: content);

  /// Returns a shallow copy of this [Note]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  Note copyWith({Object? id = _Undefined, String? title, String? content}) {
    return Note(
      id: id is int? ? id : this.id,
      title: title ?? this.title,
      content: content ?? this.content,
    );
  }
}

class NoteUpdateTable extends _is.UpdateTable<NoteTable> {
  NoteUpdateTable(super.table);

  _is.ColumnValue<String, String> title(String value) =>
      _is.ColumnValue(table.title, value);

  _is.ColumnValue<String, String> content(String value) =>
      _is.ColumnValue(table.content, value);
}

class NoteTable extends _is.Table<int?> {
  NoteTable({super.tableRelation}) : super(tableName: 'note') {
    updateTable = NoteUpdateTable(this);
    title = _is.ColumnString('title', this);
    content = _is.ColumnString('content', this);
  }

  late final NoteUpdateTable updateTable;

  late final _is.ColumnString title;

  late final _is.ColumnString content;

  @override
  List<_is.Column> get columns => [id, title, content];
}

class NoteInclude extends _is.IncludeObject {
  NoteInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => Note.t;
}

class NoteIncludeList extends _is.IncludeList {
  NoteIncludeList._({
    _is.WhereExpressionBuilder<NoteTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Note.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => Note.t;
}

class NoteRepository {
  const NoteRepository._();

  /// Returns a list of [Note]s matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// ```dart
  /// var persons = await Persons.db.find(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// );
  /// ```
  Future<List<Note>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<NoteTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<NoteTable>? orderBy,
    _is.OrderByListBuilder<NoteTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<Note>(
      where: where?.call(Note.t),
      orderBy: orderBy?.call(Note.t),
      orderByList: orderByList?.call(Note.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [Note] matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// [offset] defines how many items to skip, after which the next one will be picked.
  ///
  /// ```dart
  /// var youngestPerson = await Persons.db.findFirstRow(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.age,
  /// );
  /// ```
  Future<Note?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<NoteTable>? where,
    int? offset,
    _is.OrderByBuilder<NoteTable>? orderBy,
    _is.OrderByListBuilder<NoteTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<Note>(
      where: where?.call(Note.t),
      orderBy: orderBy?.call(Note.t),
      orderByList: orderByList?.call(Note.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [Note] by its [id] or null if no such row exists.
  Future<Note?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<Note>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [Note]s in the list and returns the inserted rows.
  ///
  /// The returned [Note]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  ///
  /// If [noReturn] is set to `true`, the inserted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Note>> insert(
    _is.DatabaseSession session,
    List<Note> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<Note>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [Note] and returns the inserted row.
  ///
  /// The returned [Note] will have its `id` field set.
  Future<Note> insertRow(
    _is.DatabaseSession session,
    Note row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<Note>(row, transaction: transaction);
  }

  /// Upserts all [Note]s in the list and returns the resulting rows.
  ///
  /// If a row conflicts on the given [conflictColumns], the existing row is
  /// updated with the new values. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies to rows matching the
  /// given expression. Conflicting rows that don't match are skipped and not
  /// returned, so the resulting list may be shorter than [rows].
  ///
  /// The returned [Note]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Note>> upsert(
    _is.DatabaseSession session,
    List<Note> rows, {
    required _is.ColumnSelections<NoteTable> conflictColumns,
    _is.ColumnSelections<NoteTable>? updateColumns,
    _is.WhereExpressionBuilder<NoteTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<Note>(
      rows,
      conflictColumns: conflictColumns(Note.t),
      updateColumns: updateColumns?.call(Note.t),
      updateWhere: updateWhere?.call(Note.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [Note] and returns the resulting row.
  ///
  /// If the row conflicts on the given [conflictColumns], the existing row is
  /// updated. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies when the existing
  /// row matches the expression. Returns `null` if no row was affected — for
  /// example when [updateWhere] does not match the conflicting row.
  ///
  /// The returned [Note] will have its `id` field set.
  Future<Note?> upsertRow(
    _is.DatabaseSession session,
    Note row, {
    required _is.ColumnSelections<NoteTable> conflictColumns,
    _is.ColumnSelections<NoteTable>? updateColumns,
    _is.WhereExpressionBuilder<NoteTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<Note>(
      row,
      conflictColumns: conflictColumns(Note.t),
      updateColumns: updateColumns?.call(Note.t),
      updateWhere: updateWhere?.call(Note.t),
      transaction: transaction,
    );
  }

  /// Updates all [Note]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Note>> update(
    _is.DatabaseSession session,
    List<Note> rows, {
    _is.ColumnSelections<NoteTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<Note>(
      rows,
      columns: columns?.call(Note.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [Note]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Note> updateRow(
    _is.DatabaseSession session,
    Note row, {
    _is.ColumnSelections<NoteTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<Note>(
      row,
      columns: columns?.call(Note.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Note] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Note?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<NoteUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<Note>(
      id,
      columnValues: columnValues(Note.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Note]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Note>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<NoteUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<NoteTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<NoteTable>? orderBy,
    _is.OrderByListBuilder<NoteTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<Note>(
      columnValues: columnValues(Note.t.updateTable),
      where: where(Note.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Note.t),
      orderByList: orderByList?.call(Note.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [Note]s in the list and returns the deleted rows.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Note>> delete(
    _is.DatabaseSession session,
    List<Note> rows, {
    _is.OrderByBuilder<NoteTable>? orderBy,
    _is.OrderByListBuilder<NoteTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<Note>(
      rows,
      orderBy: orderBy?.call(Note.t),
      orderByList: orderByList?.call(Note.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [Note].
  Future<Note> deleteRow(
    _is.DatabaseSession session,
    Note row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Note>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Note>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<NoteTable> where,
    _is.OrderByBuilder<NoteTable>? orderBy,
    _is.OrderByListBuilder<NoteTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<Note>(
      where: where(Note.t),
      orderBy: orderBy?.call(Note.t),
      orderByList: orderByList?.call(Note.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<NoteTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<Note>(
      where: where?.call(Note.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [Note] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<NoteTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<Note>(
      where: where(Note.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
