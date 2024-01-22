/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports
// ignore_for_file: use_super_parameters
// ignore_for_file: type_literal_in_constant_pattern

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

abstract class Note extends _i1.TableRow {
  Note._({
    int? id,
    required this.title,
    required this.content,
  }) : super(id);

  factory Note({
    int? id,
    required String title,
    required String content,
  }) = _NoteImpl;

  factory Note.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return Note(
      id: serializationManager.deserialize<int?>(jsonSerialization['id']),
      title:
          serializationManager.deserialize<String>(jsonSerialization['title']),
      content: serializationManager
          .deserialize<String>(jsonSerialization['content']),
    );
  }

  static final t = NoteTable();

  static const db = NoteRepository._();

  String title;

  String content;

  @override
  _i1.Table get table => t;

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
  @Deprecated('Will be removed in 2.0.0')
  Map<String, dynamic> toJsonForDatabase() {
    return {
      'id': id,
      'title': title,
      'content': content,
    };
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
    };
  }

  @override
  void setColumn(
    String columnName,
    value,
  ) {
    switch (columnName) {
      case 'id':
        id = value;
        return;
      case 'title':
        title = value;
        return;
      case 'content':
        content = value;
        return;
      default:
        throw UnimplementedError();
    }
  }

  @Deprecated('Will be removed in 2.0.0. Use: db.find instead.')
  static Future<List<Note>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<NoteTable>? where,
    int? limit,
    int? offset,
    _i1.Column? orderBy,
    List<_i1.Order>? orderByList,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<Note>(
      where: where != null ? where(Note.t) : null,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  @Deprecated('Will be removed in 2.0.0. Use: db.findRow instead.')
  static Future<Note?> findSingleRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<NoteTable>? where,
    int? offset,
    _i1.Column? orderBy,
    bool orderDescending = false,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findSingleRow<Note>(
      where: where != null ? where(Note.t) : null,
      offset: offset,
      orderBy: orderBy,
      orderDescending: orderDescending,
      useCache: useCache,
      transaction: transaction,
    );
  }

  @Deprecated('Will be removed in 2.0.0. Use: db.findById instead.')
  static Future<Note?> findById(
    _i1.Session session,
    int id,
  ) async {
    return session.db.findById<Note>(id);
  }

  @Deprecated('Will be removed in 2.0.0. Use: db.deleteWhere instead.')
  static Future<int> delete(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<NoteTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<Note>(
      where: where(Note.t),
      transaction: transaction,
    );
  }

  @Deprecated('Will be removed in 2.0.0. Use: db.deleteRow instead.')
  static Future<bool> deleteRow(
    _i1.Session session,
    Note row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow(
      row,
      transaction: transaction,
    );
  }

  @Deprecated('Will be removed in 2.0.0. Use: db.update instead.')
  static Future<bool> update(
    _i1.Session session,
    Note row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.update(
      row,
      transaction: transaction,
    );
  }

  @Deprecated(
      'Will be removed in 2.0.0. Use: db.insert instead. Important note: In db.insert, the object you pass in is no longer modified, instead a new copy with the added row is returned which contains the inserted id.')
  static Future<void> insert(
    _i1.Session session,
    Note row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert(
      row,
      transaction: transaction,
    );
  }

  @Deprecated('Will be removed in 2.0.0. Use: db.count instead.')
  static Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<NoteTable>? where,
    int? limit,
    bool useCache = true,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<Note>(
      where: where != null ? where(Note.t) : null,
      limit: limit,
      useCache: useCache,
      transaction: transaction,
    );
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

class NoteTable extends _i1.Table {
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

@Deprecated('Use NoteTable.t instead.')
NoteTable tNote = NoteTable();

class NoteInclude extends _i1.IncludeObject {
  NoteInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table get table => Note.t;
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
  _i1.Table get table => Note.t;
}

class NoteRepository {
  const NoteRepository._();

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
    return session.dbNext.find<Note>(
      where: where?.call(Note.t),
      orderBy: orderBy?.call(Note.t),
      orderByList: orderByList?.call(Note.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
    );
  }

  Future<Note?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<NoteTable>? where,
    int? offset,
    _i1.OrderByBuilder<NoteTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<NoteTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.dbNext.findFirstRow<Note>(
      where: where?.call(Note.t),
      orderBy: orderBy?.call(Note.t),
      orderByList: orderByList?.call(Note.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  Future<Note?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.dbNext.findById<Note>(
      id,
      transaction: transaction,
    );
  }

  Future<List<Note>> insert(
    _i1.Session session,
    List<Note> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.dbNext.insert<Note>(
      rows,
      transaction: transaction,
    );
  }

  Future<Note> insertRow(
    _i1.Session session,
    Note row, {
    _i1.Transaction? transaction,
  }) async {
    return session.dbNext.insertRow<Note>(
      row,
      transaction: transaction,
    );
  }

  Future<List<Note>> update(
    _i1.Session session,
    List<Note> rows, {
    _i1.ColumnSelections<NoteTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.dbNext.update<Note>(
      rows,
      columns: columns?.call(Note.t),
      transaction: transaction,
    );
  }

  Future<Note> updateRow(
    _i1.Session session,
    Note row, {
    _i1.ColumnSelections<NoteTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.dbNext.updateRow<Note>(
      row,
      columns: columns?.call(Note.t),
      transaction: transaction,
    );
  }

  Future<List<int>> delete(
    _i1.Session session,
    List<Note> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.dbNext.delete<Note>(
      rows,
      transaction: transaction,
    );
  }

  Future<int> deleteRow(
    _i1.Session session,
    Note row, {
    _i1.Transaction? transaction,
  }) async {
    return session.dbNext.deleteRow<Note>(
      row,
      transaction: transaction,
    );
  }

  Future<List<int>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<NoteTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.dbNext.deleteWhere<Note>(
      where: where(Note.t),
      transaction: transaction,
    );
  }

  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<NoteTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.dbNext.count<Note>(
      where: where?.call(Note.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
