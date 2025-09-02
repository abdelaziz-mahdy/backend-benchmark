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
import 'package:serverpod/serverpod.dart' as _i1;

abstract class Note implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  Note._({
    this.id,
    required this.title,
    required this.content,
  });

  factory Note({
    int? id,
    required String title,
    required String content,
  }) = _NoteImpl;

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
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [Note]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  Note copyWith({
    int? id,
    String? title,
    String? content,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'content': content,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'content': content,
    };
  }

  static NoteInclude include() {
    return NoteInclude._();
  }

  static NoteIncludeList includeList({
    _i1.WhereExpressionBuilder<NoteTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<NoteTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<NoteTable>? orderByList,
    NoteInclude? include,
  }) {
    return NoteIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Note.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(Note.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _NoteImpl extends Note {
  _NoteImpl({
    int? id,
    required String title,
    required String content,
  }) : super._(
          id: id,
          title: title,
          content: content,
        );

  /// Returns a shallow copy of this [Note]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  Note copyWith({
    Object? id = _Undefined,
    String? title,
    String? content,
  }) {
    return Note(
      id: id is int? ? id : this.id,
      title: title ?? this.title,
      content: content ?? this.content,
    );
  }
}

class NoteTable extends _i1.Table<int?> {
  NoteTable({super.tableRelation}) : super(tableName: 'note') {
    title = _i1.ColumnString(
      'title',
      this,
    );
    content = _i1.ColumnString(
      'content',
      this,
    );
  }

  late final _i1.ColumnString title;

  late final _i1.ColumnString content;

  @override
  List<_i1.Column> get columns => [
        id,
        title,
        content,
      ];
}

class NoteInclude extends _i1.IncludeObject {
  NoteInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => Note.t;
}

class NoteIncludeList extends _i1.IncludeList {
  NoteIncludeList._({
    _i1.WhereExpressionBuilder<NoteTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Note.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => Note.t;
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
    _i1.Session session, {
    _i1.WhereExpressionBuilder<NoteTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<NoteTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<NoteTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<Note>(
      where: where?.call(Note.t),
      orderBy: orderBy?.call(Note.t),
      orderByList: orderByList?.call(Note.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
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
    _i1.Session session, {
    _i1.WhereExpressionBuilder<NoteTable>? where,
    int? offset,
    _i1.OrderByBuilder<NoteTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<NoteTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findFirstRow<Note>(
      where: where?.call(Note.t),
      orderBy: orderBy?.call(Note.t),
      orderByList: orderByList?.call(Note.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Finds a single [Note] by its [id] or null if no such row exists.
  Future<Note?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.findById<Note>(
      id,
      transaction: transaction,
    );
  }

  /// Inserts all [Note]s in the list and returns the inserted rows.
  ///
  /// The returned [Note]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<Note>> insert(
    _i1.Session session,
    List<Note> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<Note>(
      rows,
      transaction: transaction,
    );
  }

  /// Inserts a single [Note] and returns the inserted row.
  ///
  /// The returned [Note] will have its `id` field set.
  Future<Note> insertRow(
    _i1.Session session,
    Note row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<Note>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [Note]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<Note>> update(
    _i1.Session session,
    List<Note> rows, {
    _i1.ColumnSelections<NoteTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<Note>(
      rows,
      columns: columns?.call(Note.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Note]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Note> updateRow(
    _i1.Session session,
    Note row, {
    _i1.ColumnSelections<NoteTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<Note>(
      row,
      columns: columns?.call(Note.t),
      transaction: transaction,
    );
  }

  /// Deletes all [Note]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<Note>> delete(
    _i1.Session session,
    List<Note> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<Note>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [Note].
  Future<Note> deleteRow(
    _i1.Session session,
    Note row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Note>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<Note>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<NoteTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<Note>(
      where: where(Note.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<NoteTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<Note>(
      where: where?.call(Note.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
