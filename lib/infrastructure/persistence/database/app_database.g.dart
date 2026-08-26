// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PracticeSessionsTable extends PracticeSessions
    with TableInfo<$PracticeSessionsTable, PracticeSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PracticeSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _templateJsonMeta = const VerificationMeta(
    'templateJson',
  );
  @override
  late final GeneratedColumn<String> templateJson = GeneratedColumn<String>(
    'template_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _validFrameCountMeta = const VerificationMeta(
    'validFrameCount',
  );
  @override
  late final GeneratedColumn<int> validFrameCount = GeneratedColumn<int>(
    'valid_frame_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalFrameCountMeta = const VerificationMeta(
    'totalFrameCount',
  );
  @override
  late final GeneratedColumn<int> totalFrameCount = GeneratedColumn<int>(
    'total_frame_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qualityFlagsJsonMeta = const VerificationMeta(
    'qualityFlagsJson',
  );
  @override
  late final GeneratedColumn<String> qualityFlagsJson = GeneratedColumn<String>(
    'quality_flags_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryJsonMeta = const VerificationMeta(
    'summaryJson',
  );
  @override
  late final GeneratedColumn<String> summaryJson = GeneratedColumn<String>(
    'summary_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _voiceComparisonJsonMeta =
      const VerificationMeta('voiceComparisonJson');
  @override
  late final GeneratedColumn<String> voiceComparisonJson =
      GeneratedColumn<String>(
        'voice_comparison_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    templateJson,
    startedAt,
    validFrameCount,
    totalFrameCount,
    qualityFlagsJson,
    summaryJson,
    voiceComparisonJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'practice_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PracticeSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('template_json')) {
      context.handle(
        _templateJsonMeta,
        templateJson.isAcceptableOrUnknown(
          data['template_json']!,
          _templateJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_templateJsonMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('valid_frame_count')) {
      context.handle(
        _validFrameCountMeta,
        validFrameCount.isAcceptableOrUnknown(
          data['valid_frame_count']!,
          _validFrameCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_validFrameCountMeta);
    }
    if (data.containsKey('total_frame_count')) {
      context.handle(
        _totalFrameCountMeta,
        totalFrameCount.isAcceptableOrUnknown(
          data['total_frame_count']!,
          _totalFrameCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalFrameCountMeta);
    }
    if (data.containsKey('quality_flags_json')) {
      context.handle(
        _qualityFlagsJsonMeta,
        qualityFlagsJson.isAcceptableOrUnknown(
          data['quality_flags_json']!,
          _qualityFlagsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_qualityFlagsJsonMeta);
    }
    if (data.containsKey('summary_json')) {
      context.handle(
        _summaryJsonMeta,
        summaryJson.isAcceptableOrUnknown(
          data['summary_json']!,
          _summaryJsonMeta,
        ),
      );
    }
    if (data.containsKey('voice_comparison_json')) {
      context.handle(
        _voiceComparisonJsonMeta,
        voiceComparisonJson.isAcceptableOrUnknown(
          data['voice_comparison_json']!,
          _voiceComparisonJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PracticeSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PracticeSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      templateJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_json'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      validFrameCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}valid_frame_count'],
      )!,
      totalFrameCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_frame_count'],
      )!,
      qualityFlagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quality_flags_json'],
      )!,
      summaryJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_json'],
      )!,
      voiceComparisonJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voice_comparison_json'],
      ),
    );
  }

  @override
  $PracticeSessionsTable createAlias(String alias) {
    return $PracticeSessionsTable(attachedDatabase, alias);
  }
}

class PracticeSession extends DataClass implements Insertable<PracticeSession> {
  final String id;
  final String templateJson;
  final DateTime startedAt;
  final int validFrameCount;
  final int totalFrameCount;
  final String qualityFlagsJson;
  final String summaryJson;
  final String? voiceComparisonJson;
  const PracticeSession({
    required this.id,
    required this.templateJson,
    required this.startedAt,
    required this.validFrameCount,
    required this.totalFrameCount,
    required this.qualityFlagsJson,
    required this.summaryJson,
    this.voiceComparisonJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['template_json'] = Variable<String>(templateJson);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['valid_frame_count'] = Variable<int>(validFrameCount);
    map['total_frame_count'] = Variable<int>(totalFrameCount);
    map['quality_flags_json'] = Variable<String>(qualityFlagsJson);
    map['summary_json'] = Variable<String>(summaryJson);
    if (!nullToAbsent || voiceComparisonJson != null) {
      map['voice_comparison_json'] = Variable<String>(voiceComparisonJson);
    }
    return map;
  }

  PracticeSessionsCompanion toCompanion(bool nullToAbsent) {
    return PracticeSessionsCompanion(
      id: Value(id),
      templateJson: Value(templateJson),
      startedAt: Value(startedAt),
      validFrameCount: Value(validFrameCount),
      totalFrameCount: Value(totalFrameCount),
      qualityFlagsJson: Value(qualityFlagsJson),
      summaryJson: Value(summaryJson),
      voiceComparisonJson: voiceComparisonJson == null && nullToAbsent
          ? const Value.absent()
          : Value(voiceComparisonJson),
    );
  }

  factory PracticeSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PracticeSession(
      id: serializer.fromJson<String>(json['id']),
      templateJson: serializer.fromJson<String>(json['templateJson']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      validFrameCount: serializer.fromJson<int>(json['validFrameCount']),
      totalFrameCount: serializer.fromJson<int>(json['totalFrameCount']),
      qualityFlagsJson: serializer.fromJson<String>(json['qualityFlagsJson']),
      summaryJson: serializer.fromJson<String>(json['summaryJson']),
      voiceComparisonJson: serializer.fromJson<String?>(
        json['voiceComparisonJson'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'templateJson': serializer.toJson<String>(templateJson),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'validFrameCount': serializer.toJson<int>(validFrameCount),
      'totalFrameCount': serializer.toJson<int>(totalFrameCount),
      'qualityFlagsJson': serializer.toJson<String>(qualityFlagsJson),
      'summaryJson': serializer.toJson<String>(summaryJson),
      'voiceComparisonJson': serializer.toJson<String?>(voiceComparisonJson),
    };
  }

  PracticeSession copyWith({
    String? id,
    String? templateJson,
    DateTime? startedAt,
    int? validFrameCount,
    int? totalFrameCount,
    String? qualityFlagsJson,
    String? summaryJson,
    Value<String?> voiceComparisonJson = const Value.absent(),
  }) => PracticeSession(
    id: id ?? this.id,
    templateJson: templateJson ?? this.templateJson,
    startedAt: startedAt ?? this.startedAt,
    validFrameCount: validFrameCount ?? this.validFrameCount,
    totalFrameCount: totalFrameCount ?? this.totalFrameCount,
    qualityFlagsJson: qualityFlagsJson ?? this.qualityFlagsJson,
    summaryJson: summaryJson ?? this.summaryJson,
    voiceComparisonJson: voiceComparisonJson.present
        ? voiceComparisonJson.value
        : this.voiceComparisonJson,
  );
  PracticeSession copyWithCompanion(PracticeSessionsCompanion data) {
    return PracticeSession(
      id: data.id.present ? data.id.value : this.id,
      templateJson: data.templateJson.present
          ? data.templateJson.value
          : this.templateJson,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      validFrameCount: data.validFrameCount.present
          ? data.validFrameCount.value
          : this.validFrameCount,
      totalFrameCount: data.totalFrameCount.present
          ? data.totalFrameCount.value
          : this.totalFrameCount,
      qualityFlagsJson: data.qualityFlagsJson.present
          ? data.qualityFlagsJson.value
          : this.qualityFlagsJson,
      summaryJson: data.summaryJson.present
          ? data.summaryJson.value
          : this.summaryJson,
      voiceComparisonJson: data.voiceComparisonJson.present
          ? data.voiceComparisonJson.value
          : this.voiceComparisonJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PracticeSession(')
          ..write('id: $id, ')
          ..write('templateJson: $templateJson, ')
          ..write('startedAt: $startedAt, ')
          ..write('validFrameCount: $validFrameCount, ')
          ..write('totalFrameCount: $totalFrameCount, ')
          ..write('qualityFlagsJson: $qualityFlagsJson, ')
          ..write('summaryJson: $summaryJson, ')
          ..write('voiceComparisonJson: $voiceComparisonJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    templateJson,
    startedAt,
    validFrameCount,
    totalFrameCount,
    qualityFlagsJson,
    summaryJson,
    voiceComparisonJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PracticeSession &&
          other.id == this.id &&
          other.templateJson == this.templateJson &&
          other.startedAt == this.startedAt &&
          other.validFrameCount == this.validFrameCount &&
          other.totalFrameCount == this.totalFrameCount &&
          other.qualityFlagsJson == this.qualityFlagsJson &&
          other.summaryJson == this.summaryJson &&
          other.voiceComparisonJson == this.voiceComparisonJson);
}

class PracticeSessionsCompanion extends UpdateCompanion<PracticeSession> {
  final Value<String> id;
  final Value<String> templateJson;
  final Value<DateTime> startedAt;
  final Value<int> validFrameCount;
  final Value<int> totalFrameCount;
  final Value<String> qualityFlagsJson;
  final Value<String> summaryJson;
  final Value<String?> voiceComparisonJson;
  final Value<int> rowid;
  const PracticeSessionsCompanion({
    this.id = const Value.absent(),
    this.templateJson = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.validFrameCount = const Value.absent(),
    this.totalFrameCount = const Value.absent(),
    this.qualityFlagsJson = const Value.absent(),
    this.summaryJson = const Value.absent(),
    this.voiceComparisonJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PracticeSessionsCompanion.insert({
    required String id,
    required String templateJson,
    required DateTime startedAt,
    required int validFrameCount,
    required int totalFrameCount,
    required String qualityFlagsJson,
    this.summaryJson = const Value.absent(),
    this.voiceComparisonJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       templateJson = Value(templateJson),
       startedAt = Value(startedAt),
       validFrameCount = Value(validFrameCount),
       totalFrameCount = Value(totalFrameCount),
       qualityFlagsJson = Value(qualityFlagsJson);
  static Insertable<PracticeSession> custom({
    Expression<String>? id,
    Expression<String>? templateJson,
    Expression<DateTime>? startedAt,
    Expression<int>? validFrameCount,
    Expression<int>? totalFrameCount,
    Expression<String>? qualityFlagsJson,
    Expression<String>? summaryJson,
    Expression<String>? voiceComparisonJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (templateJson != null) 'template_json': templateJson,
      if (startedAt != null) 'started_at': startedAt,
      if (validFrameCount != null) 'valid_frame_count': validFrameCount,
      if (totalFrameCount != null) 'total_frame_count': totalFrameCount,
      if (qualityFlagsJson != null) 'quality_flags_json': qualityFlagsJson,
      if (summaryJson != null) 'summary_json': summaryJson,
      if (voiceComparisonJson != null)
        'voice_comparison_json': voiceComparisonJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PracticeSessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? templateJson,
    Value<DateTime>? startedAt,
    Value<int>? validFrameCount,
    Value<int>? totalFrameCount,
    Value<String>? qualityFlagsJson,
    Value<String>? summaryJson,
    Value<String?>? voiceComparisonJson,
    Value<int>? rowid,
  }) {
    return PracticeSessionsCompanion(
      id: id ?? this.id,
      templateJson: templateJson ?? this.templateJson,
      startedAt: startedAt ?? this.startedAt,
      validFrameCount: validFrameCount ?? this.validFrameCount,
      totalFrameCount: totalFrameCount ?? this.totalFrameCount,
      qualityFlagsJson: qualityFlagsJson ?? this.qualityFlagsJson,
      summaryJson: summaryJson ?? this.summaryJson,
      voiceComparisonJson: voiceComparisonJson ?? this.voiceComparisonJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (templateJson.present) {
      map['template_json'] = Variable<String>(templateJson.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (validFrameCount.present) {
      map['valid_frame_count'] = Variable<int>(validFrameCount.value);
    }
    if (totalFrameCount.present) {
      map['total_frame_count'] = Variable<int>(totalFrameCount.value);
    }
    if (qualityFlagsJson.present) {
      map['quality_flags_json'] = Variable<String>(qualityFlagsJson.value);
    }
    if (summaryJson.present) {
      map['summary_json'] = Variable<String>(summaryJson.value);
    }
    if (voiceComparisonJson.present) {
      map['voice_comparison_json'] = Variable<String>(
        voiceComparisonJson.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PracticeSessionsCompanion(')
          ..write('id: $id, ')
          ..write('templateJson: $templateJson, ')
          ..write('startedAt: $startedAt, ')
          ..write('validFrameCount: $validFrameCount, ')
          ..write('totalFrameCount: $totalFrameCount, ')
          ..write('qualityFlagsJson: $qualityFlagsJson, ')
          ..write('summaryJson: $summaryJson, ')
          ..write('voiceComparisonJson: $voiceComparisonJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecordingsTable extends Recordings
    with TableInfo<$RecordingsTable, Recording> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecordingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES practice_sessions (id)',
    ),
  );
  static const VerificationMeta _locatorMeta = const VerificationMeta(
    'locator',
  );
  @override
  late final GeneratedColumn<String> locator = GeneratedColumn<String>(
    'locator',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storageKindMeta = const VerificationMeta(
    'storageKind',
  );
  @override
  late final GeneratedColumn<String> storageKind = GeneratedColumn<String>(
    'storage_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentSha256Meta = const VerificationMeta(
    'contentSha256',
  );
  @override
  late final GeneratedColumn<String> contentSha256 = GeneratedColumn<String>(
    'content_sha256',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentByteLengthMeta = const VerificationMeta(
    'contentByteLength',
  );
  @override
  late final GeneratedColumn<int> contentByteLength = GeneratedColumn<int>(
    'content_byte_length',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pendingDeleteMeta = const VerificationMeta(
    'pendingDelete',
  );
  @override
  late final GeneratedColumn<bool> pendingDelete = GeneratedColumn<bool>(
    'pending_delete',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pending_delete" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionId,
    locator,
    storageKind,
    contentSha256,
    contentByteLength,
    pendingDelete,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recordings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Recording> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('locator')) {
      context.handle(
        _locatorMeta,
        locator.isAcceptableOrUnknown(data['locator']!, _locatorMeta),
      );
    } else if (isInserting) {
      context.missing(_locatorMeta);
    }
    if (data.containsKey('storage_kind')) {
      context.handle(
        _storageKindMeta,
        storageKind.isAcceptableOrUnknown(
          data['storage_kind']!,
          _storageKindMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_storageKindMeta);
    }
    if (data.containsKey('content_sha256')) {
      context.handle(
        _contentSha256Meta,
        contentSha256.isAcceptableOrUnknown(
          data['content_sha256']!,
          _contentSha256Meta,
        ),
      );
    }
    if (data.containsKey('content_byte_length')) {
      context.handle(
        _contentByteLengthMeta,
        contentByteLength.isAcceptableOrUnknown(
          data['content_byte_length']!,
          _contentByteLengthMeta,
        ),
      );
    }
    if (data.containsKey('pending_delete')) {
      context.handle(
        _pendingDeleteMeta,
        pendingDelete.isAcceptableOrUnknown(
          data['pending_delete']!,
          _pendingDeleteMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId};
  @override
  Recording map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Recording(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      locator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locator'],
      )!,
      storageKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}storage_kind'],
      )!,
      contentSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_sha256'],
      ),
      contentByteLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}content_byte_length'],
      ),
      pendingDelete: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pending_delete'],
      )!,
    );
  }

  @override
  $RecordingsTable createAlias(String alias) {
    return $RecordingsTable(attachedDatabase, alias);
  }
}

class Recording extends DataClass implements Insertable<Recording> {
  final String sessionId;
  final String locator;
  final String storageKind;
  final String? contentSha256;
  final int? contentByteLength;
  final bool pendingDelete;
  const Recording({
    required this.sessionId,
    required this.locator,
    required this.storageKind,
    this.contentSha256,
    this.contentByteLength,
    required this.pendingDelete,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['locator'] = Variable<String>(locator);
    map['storage_kind'] = Variable<String>(storageKind);
    if (!nullToAbsent || contentSha256 != null) {
      map['content_sha256'] = Variable<String>(contentSha256);
    }
    if (!nullToAbsent || contentByteLength != null) {
      map['content_byte_length'] = Variable<int>(contentByteLength);
    }
    map['pending_delete'] = Variable<bool>(pendingDelete);
    return map;
  }

  RecordingsCompanion toCompanion(bool nullToAbsent) {
    return RecordingsCompanion(
      sessionId: Value(sessionId),
      locator: Value(locator),
      storageKind: Value(storageKind),
      contentSha256: contentSha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(contentSha256),
      contentByteLength: contentByteLength == null && nullToAbsent
          ? const Value.absent()
          : Value(contentByteLength),
      pendingDelete: Value(pendingDelete),
    );
  }

  factory Recording.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Recording(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      locator: serializer.fromJson<String>(json['locator']),
      storageKind: serializer.fromJson<String>(json['storageKind']),
      contentSha256: serializer.fromJson<String?>(json['contentSha256']),
      contentByteLength: serializer.fromJson<int?>(json['contentByteLength']),
      pendingDelete: serializer.fromJson<bool>(json['pendingDelete']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'locator': serializer.toJson<String>(locator),
      'storageKind': serializer.toJson<String>(storageKind),
      'contentSha256': serializer.toJson<String?>(contentSha256),
      'contentByteLength': serializer.toJson<int?>(contentByteLength),
      'pendingDelete': serializer.toJson<bool>(pendingDelete),
    };
  }

  Recording copyWith({
    String? sessionId,
    String? locator,
    String? storageKind,
    Value<String?> contentSha256 = const Value.absent(),
    Value<int?> contentByteLength = const Value.absent(),
    bool? pendingDelete,
  }) => Recording(
    sessionId: sessionId ?? this.sessionId,
    locator: locator ?? this.locator,
    storageKind: storageKind ?? this.storageKind,
    contentSha256: contentSha256.present
        ? contentSha256.value
        : this.contentSha256,
    contentByteLength: contentByteLength.present
        ? contentByteLength.value
        : this.contentByteLength,
    pendingDelete: pendingDelete ?? this.pendingDelete,
  );
  Recording copyWithCompanion(RecordingsCompanion data) {
    return Recording(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      locator: data.locator.present ? data.locator.value : this.locator,
      storageKind: data.storageKind.present
          ? data.storageKind.value
          : this.storageKind,
      contentSha256: data.contentSha256.present
          ? data.contentSha256.value
          : this.contentSha256,
      contentByteLength: data.contentByteLength.present
          ? data.contentByteLength.value
          : this.contentByteLength,
      pendingDelete: data.pendingDelete.present
          ? data.pendingDelete.value
          : this.pendingDelete,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Recording(')
          ..write('sessionId: $sessionId, ')
          ..write('locator: $locator, ')
          ..write('storageKind: $storageKind, ')
          ..write('contentSha256: $contentSha256, ')
          ..write('contentByteLength: $contentByteLength, ')
          ..write('pendingDelete: $pendingDelete')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sessionId,
    locator,
    storageKind,
    contentSha256,
    contentByteLength,
    pendingDelete,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Recording &&
          other.sessionId == this.sessionId &&
          other.locator == this.locator &&
          other.storageKind == this.storageKind &&
          other.contentSha256 == this.contentSha256 &&
          other.contentByteLength == this.contentByteLength &&
          other.pendingDelete == this.pendingDelete);
}

class RecordingsCompanion extends UpdateCompanion<Recording> {
  final Value<String> sessionId;
  final Value<String> locator;
  final Value<String> storageKind;
  final Value<String?> contentSha256;
  final Value<int?> contentByteLength;
  final Value<bool> pendingDelete;
  final Value<int> rowid;
  const RecordingsCompanion({
    this.sessionId = const Value.absent(),
    this.locator = const Value.absent(),
    this.storageKind = const Value.absent(),
    this.contentSha256 = const Value.absent(),
    this.contentByteLength = const Value.absent(),
    this.pendingDelete = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecordingsCompanion.insert({
    required String sessionId,
    required String locator,
    required String storageKind,
    this.contentSha256 = const Value.absent(),
    this.contentByteLength = const Value.absent(),
    this.pendingDelete = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sessionId = Value(sessionId),
       locator = Value(locator),
       storageKind = Value(storageKind);
  static Insertable<Recording> custom({
    Expression<String>? sessionId,
    Expression<String>? locator,
    Expression<String>? storageKind,
    Expression<String>? contentSha256,
    Expression<int>? contentByteLength,
    Expression<bool>? pendingDelete,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (locator != null) 'locator': locator,
      if (storageKind != null) 'storage_kind': storageKind,
      if (contentSha256 != null) 'content_sha256': contentSha256,
      if (contentByteLength != null) 'content_byte_length': contentByteLength,
      if (pendingDelete != null) 'pending_delete': pendingDelete,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecordingsCompanion copyWith({
    Value<String>? sessionId,
    Value<String>? locator,
    Value<String>? storageKind,
    Value<String?>? contentSha256,
    Value<int?>? contentByteLength,
    Value<bool>? pendingDelete,
    Value<int>? rowid,
  }) {
    return RecordingsCompanion(
      sessionId: sessionId ?? this.sessionId,
      locator: locator ?? this.locator,
      storageKind: storageKind ?? this.storageKind,
      contentSha256: contentSha256 ?? this.contentSha256,
      contentByteLength: contentByteLength ?? this.contentByteLength,
      pendingDelete: pendingDelete ?? this.pendingDelete,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (locator.present) {
      map['locator'] = Variable<String>(locator.value);
    }
    if (storageKind.present) {
      map['storage_kind'] = Variable<String>(storageKind.value);
    }
    if (contentSha256.present) {
      map['content_sha256'] = Variable<String>(contentSha256.value);
    }
    if (contentByteLength.present) {
      map['content_byte_length'] = Variable<int>(contentByteLength.value);
    }
    if (pendingDelete.present) {
      map['pending_delete'] = Variable<bool>(pendingDelete.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordingsCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('locator: $locator, ')
          ..write('storageKind: $storageKind, ')
          ..write('contentSha256: $contentSha256, ')
          ..write('contentByteLength: $contentByteLength, ')
          ..write('pendingDelete: $pendingDelete, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AnalysisRunsTable extends AnalysisRuns
    with TableInfo<$AnalysisRunsTable, AnalysisRun> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnalysisRunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES practice_sessions (id)',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _algorithmVersionMeta = const VerificationMeta(
    'algorithmVersion',
  );
  @override
  late final GeneratedColumn<String> algorithmVersion = GeneratedColumn<String>(
    'algorithm_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    createdAt,
    algorithmVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'analysis_runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<AnalysisRun> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('algorithm_version')) {
      context.handle(
        _algorithmVersionMeta,
        algorithmVersion.isAcceptableOrUnknown(
          data['algorithm_version']!,
          _algorithmVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_algorithmVersionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AnalysisRun map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnalysisRun(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      algorithmVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}algorithm_version'],
      )!,
    );
  }

  @override
  $AnalysisRunsTable createAlias(String alias) {
    return $AnalysisRunsTable(attachedDatabase, alias);
  }
}

class AnalysisRun extends DataClass implements Insertable<AnalysisRun> {
  final int id;
  final String sessionId;
  final DateTime createdAt;
  final String algorithmVersion;
  const AnalysisRun({
    required this.id,
    required this.sessionId,
    required this.createdAt,
    required this.algorithmVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['algorithm_version'] = Variable<String>(algorithmVersion);
    return map;
  }

  AnalysisRunsCompanion toCompanion(bool nullToAbsent) {
    return AnalysisRunsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      createdAt: Value(createdAt),
      algorithmVersion: Value(algorithmVersion),
    );
  }

  factory AnalysisRun.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnalysisRun(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      algorithmVersion: serializer.fromJson<String>(json['algorithmVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'algorithmVersion': serializer.toJson<String>(algorithmVersion),
    };
  }

  AnalysisRun copyWith({
    int? id,
    String? sessionId,
    DateTime? createdAt,
    String? algorithmVersion,
  }) => AnalysisRun(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    createdAt: createdAt ?? this.createdAt,
    algorithmVersion: algorithmVersion ?? this.algorithmVersion,
  );
  AnalysisRun copyWithCompanion(AnalysisRunsCompanion data) {
    return AnalysisRun(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      algorithmVersion: data.algorithmVersion.present
          ? data.algorithmVersion.value
          : this.algorithmVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnalysisRun(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('algorithmVersion: $algorithmVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionId, createdAt, algorithmVersion);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnalysisRun &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.createdAt == this.createdAt &&
          other.algorithmVersion == this.algorithmVersion);
}

class AnalysisRunsCompanion extends UpdateCompanion<AnalysisRun> {
  final Value<int> id;
  final Value<String> sessionId;
  final Value<DateTime> createdAt;
  final Value<String> algorithmVersion;
  const AnalysisRunsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.algorithmVersion = const Value.absent(),
  });
  AnalysisRunsCompanion.insert({
    this.id = const Value.absent(),
    required String sessionId,
    required DateTime createdAt,
    required String algorithmVersion,
  }) : sessionId = Value(sessionId),
       createdAt = Value(createdAt),
       algorithmVersion = Value(algorithmVersion);
  static Insertable<AnalysisRun> custom({
    Expression<int>? id,
    Expression<String>? sessionId,
    Expression<DateTime>? createdAt,
    Expression<String>? algorithmVersion,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (createdAt != null) 'created_at': createdAt,
      if (algorithmVersion != null) 'algorithm_version': algorithmVersion,
    });
  }

  AnalysisRunsCompanion copyWith({
    Value<int>? id,
    Value<String>? sessionId,
    Value<DateTime>? createdAt,
    Value<String>? algorithmVersion,
  }) {
    return AnalysisRunsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      createdAt: createdAt ?? this.createdAt,
      algorithmVersion: algorithmVersion ?? this.algorithmVersion,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (algorithmVersion.present) {
      map['algorithm_version'] = Variable<String>(algorithmVersion.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnalysisRunsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('algorithmVersion: $algorithmVersion')
          ..write(')'))
        .toString();
  }
}

class $FeatureSeriesTableTable extends FeatureSeriesTable
    with TableInfo<$FeatureSeriesTableTable, FeatureSeriesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FeatureSeriesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<int> runId = GeneratedColumn<int>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES analysis_runs (id)',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _frameCountMeta = const VerificationMeta(
    'frameCount',
  );
  @override
  late final GeneratedColumn<int> frameCount = GeneratedColumn<int>(
    'frame_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codecVersionMeta = const VerificationMeta(
    'codecVersion',
  );
  @override
  late final GeneratedColumn<int> codecVersion = GeneratedColumn<int>(
    'codec_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<Uint8List> payload = GeneratedColumn<Uint8List>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    runId,
    kind,
    frameCount,
    codecVersion,
    payload,
    sha256,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'feature_series';
  @override
  VerificationContext validateIntegrity(
    Insertable<FeatureSeriesTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('frame_count')) {
      context.handle(
        _frameCountMeta,
        frameCount.isAcceptableOrUnknown(data['frame_count']!, _frameCountMeta),
      );
    } else if (isInserting) {
      context.missing(_frameCountMeta);
    }
    if (data.containsKey('codec_version')) {
      context.handle(
        _codecVersionMeta,
        codecVersion.isAcceptableOrUnknown(
          data['codec_version']!,
          _codecVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_codecVersionMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    } else if (isInserting) {
      context.missing(_sha256Meta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FeatureSeriesTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FeatureSeriesTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}run_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      frameCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}frame_count'],
      )!,
      codecVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}codec_version'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}payload'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      )!,
    );
  }

  @override
  $FeatureSeriesTableTable createAlias(String alias) {
    return $FeatureSeriesTableTable(attachedDatabase, alias);
  }
}

class FeatureSeriesTableData extends DataClass
    implements Insertable<FeatureSeriesTableData> {
  final int id;
  final int runId;
  final String kind;
  final int frameCount;
  final int codecVersion;
  final Uint8List payload;
  final String sha256;
  const FeatureSeriesTableData({
    required this.id,
    required this.runId,
    required this.kind,
    required this.frameCount,
    required this.codecVersion,
    required this.payload,
    required this.sha256,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['run_id'] = Variable<int>(runId);
    map['kind'] = Variable<String>(kind);
    map['frame_count'] = Variable<int>(frameCount);
    map['codec_version'] = Variable<int>(codecVersion);
    map['payload'] = Variable<Uint8List>(payload);
    map['sha256'] = Variable<String>(sha256);
    return map;
  }

  FeatureSeriesTableCompanion toCompanion(bool nullToAbsent) {
    return FeatureSeriesTableCompanion(
      id: Value(id),
      runId: Value(runId),
      kind: Value(kind),
      frameCount: Value(frameCount),
      codecVersion: Value(codecVersion),
      payload: Value(payload),
      sha256: Value(sha256),
    );
  }

  factory FeatureSeriesTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FeatureSeriesTableData(
      id: serializer.fromJson<int>(json['id']),
      runId: serializer.fromJson<int>(json['runId']),
      kind: serializer.fromJson<String>(json['kind']),
      frameCount: serializer.fromJson<int>(json['frameCount']),
      codecVersion: serializer.fromJson<int>(json['codecVersion']),
      payload: serializer.fromJson<Uint8List>(json['payload']),
      sha256: serializer.fromJson<String>(json['sha256']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'runId': serializer.toJson<int>(runId),
      'kind': serializer.toJson<String>(kind),
      'frameCount': serializer.toJson<int>(frameCount),
      'codecVersion': serializer.toJson<int>(codecVersion),
      'payload': serializer.toJson<Uint8List>(payload),
      'sha256': serializer.toJson<String>(sha256),
    };
  }

  FeatureSeriesTableData copyWith({
    int? id,
    int? runId,
    String? kind,
    int? frameCount,
    int? codecVersion,
    Uint8List? payload,
    String? sha256,
  }) => FeatureSeriesTableData(
    id: id ?? this.id,
    runId: runId ?? this.runId,
    kind: kind ?? this.kind,
    frameCount: frameCount ?? this.frameCount,
    codecVersion: codecVersion ?? this.codecVersion,
    payload: payload ?? this.payload,
    sha256: sha256 ?? this.sha256,
  );
  FeatureSeriesTableData copyWithCompanion(FeatureSeriesTableCompanion data) {
    return FeatureSeriesTableData(
      id: data.id.present ? data.id.value : this.id,
      runId: data.runId.present ? data.runId.value : this.runId,
      kind: data.kind.present ? data.kind.value : this.kind,
      frameCount: data.frameCount.present
          ? data.frameCount.value
          : this.frameCount,
      codecVersion: data.codecVersion.present
          ? data.codecVersion.value
          : this.codecVersion,
      payload: data.payload.present ? data.payload.value : this.payload,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FeatureSeriesTableData(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('kind: $kind, ')
          ..write('frameCount: $frameCount, ')
          ..write('codecVersion: $codecVersion, ')
          ..write('payload: $payload, ')
          ..write('sha256: $sha256')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    runId,
    kind,
    frameCount,
    codecVersion,
    $driftBlobEquality.hash(payload),
    sha256,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FeatureSeriesTableData &&
          other.id == this.id &&
          other.runId == this.runId &&
          other.kind == this.kind &&
          other.frameCount == this.frameCount &&
          other.codecVersion == this.codecVersion &&
          $driftBlobEquality.equals(other.payload, this.payload) &&
          other.sha256 == this.sha256);
}

class FeatureSeriesTableCompanion
    extends UpdateCompanion<FeatureSeriesTableData> {
  final Value<int> id;
  final Value<int> runId;
  final Value<String> kind;
  final Value<int> frameCount;
  final Value<int> codecVersion;
  final Value<Uint8List> payload;
  final Value<String> sha256;
  const FeatureSeriesTableCompanion({
    this.id = const Value.absent(),
    this.runId = const Value.absent(),
    this.kind = const Value.absent(),
    this.frameCount = const Value.absent(),
    this.codecVersion = const Value.absent(),
    this.payload = const Value.absent(),
    this.sha256 = const Value.absent(),
  });
  FeatureSeriesTableCompanion.insert({
    this.id = const Value.absent(),
    required int runId,
    required String kind,
    required int frameCount,
    required int codecVersion,
    required Uint8List payload,
    required String sha256,
  }) : runId = Value(runId),
       kind = Value(kind),
       frameCount = Value(frameCount),
       codecVersion = Value(codecVersion),
       payload = Value(payload),
       sha256 = Value(sha256);
  static Insertable<FeatureSeriesTableData> custom({
    Expression<int>? id,
    Expression<int>? runId,
    Expression<String>? kind,
    Expression<int>? frameCount,
    Expression<int>? codecVersion,
    Expression<Uint8List>? payload,
    Expression<String>? sha256,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (runId != null) 'run_id': runId,
      if (kind != null) 'kind': kind,
      if (frameCount != null) 'frame_count': frameCount,
      if (codecVersion != null) 'codec_version': codecVersion,
      if (payload != null) 'payload': payload,
      if (sha256 != null) 'sha256': sha256,
    });
  }

  FeatureSeriesTableCompanion copyWith({
    Value<int>? id,
    Value<int>? runId,
    Value<String>? kind,
    Value<int>? frameCount,
    Value<int>? codecVersion,
    Value<Uint8List>? payload,
    Value<String>? sha256,
  }) {
    return FeatureSeriesTableCompanion(
      id: id ?? this.id,
      runId: runId ?? this.runId,
      kind: kind ?? this.kind,
      frameCount: frameCount ?? this.frameCount,
      codecVersion: codecVersion ?? this.codecVersion,
      payload: payload ?? this.payload,
      sha256: sha256 ?? this.sha256,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<int>(runId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (frameCount.present) {
      map['frame_count'] = Variable<int>(frameCount.value);
    }
    if (codecVersion.present) {
      map['codec_version'] = Variable<int>(codecVersion.value);
    }
    if (payload.present) {
      map['payload'] = Variable<Uint8List>(payload.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FeatureSeriesTableCompanion(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('kind: $kind, ')
          ..write('frameCount: $frameCount, ')
          ..write('codecVersion: $codecVersion, ')
          ..write('payload: $payload, ')
          ..write('sha256: $sha256')
          ..write(')'))
        .toString();
  }
}

class $FeatureSeriesMetadataTable extends FeatureSeriesMetadata
    with TableInfo<$FeatureSeriesMetadataTable, FeatureSeriesMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FeatureSeriesMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<int> runId = GeneratedColumn<int>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES analysis_runs (id)',
    ),
  );
  static const VerificationMeta _frameCountMeta = const VerificationMeta(
    'frameCount',
  );
  @override
  late final GeneratedColumn<int> frameCount = GeneratedColumn<int>(
    'frame_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startSampleIndexMeta = const VerificationMeta(
    'startSampleIndex',
  );
  @override
  late final GeneratedColumn<int> startSampleIndex = GeneratedColumn<int>(
    'start_sample_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _samplePeriodSamplesMeta =
      const VerificationMeta('samplePeriodSamples');
  @override
  late final GeneratedColumn<int> samplePeriodSamples = GeneratedColumn<int>(
    'sample_period_samples',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _algorithmVersionMeta = const VerificationMeta(
    'algorithmVersion',
  );
  @override
  late final GeneratedColumn<String> algorithmVersion = GeneratedColumn<String>(
    'algorithm_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _featureSchemaVersionMeta =
      const VerificationMeta('featureSchemaVersion');
  @override
  late final GeneratedColumn<int> featureSchemaVersion = GeneratedColumn<int>(
    'feature_schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _sourceAudioSha256Meta = const VerificationMeta(
    'sourceAudioSha256',
  );
  @override
  late final GeneratedColumn<String> sourceAudioSha256 =
      GeneratedColumn<String>(
        'source_audio_sha256',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _sourceAudioByteLengthMeta =
      const VerificationMeta('sourceAudioByteLength');
  @override
  late final GeneratedColumn<int> sourceAudioByteLength = GeneratedColumn<int>(
    'source_audio_byte_length',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    runId,
    frameCount,
    startSampleIndex,
    samplePeriodSamples,
    algorithmVersion,
    featureSchemaVersion,
    sourceAudioSha256,
    sourceAudioByteLength,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'feature_series_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<FeatureSeriesMetadataData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    }
    if (data.containsKey('frame_count')) {
      context.handle(
        _frameCountMeta,
        frameCount.isAcceptableOrUnknown(data['frame_count']!, _frameCountMeta),
      );
    } else if (isInserting) {
      context.missing(_frameCountMeta);
    }
    if (data.containsKey('start_sample_index')) {
      context.handle(
        _startSampleIndexMeta,
        startSampleIndex.isAcceptableOrUnknown(
          data['start_sample_index']!,
          _startSampleIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startSampleIndexMeta);
    }
    if (data.containsKey('sample_period_samples')) {
      context.handle(
        _samplePeriodSamplesMeta,
        samplePeriodSamples.isAcceptableOrUnknown(
          data['sample_period_samples']!,
          _samplePeriodSamplesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_samplePeriodSamplesMeta);
    }
    if (data.containsKey('algorithm_version')) {
      context.handle(
        _algorithmVersionMeta,
        algorithmVersion.isAcceptableOrUnknown(
          data['algorithm_version']!,
          _algorithmVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_algorithmVersionMeta);
    }
    if (data.containsKey('feature_schema_version')) {
      context.handle(
        _featureSchemaVersionMeta,
        featureSchemaVersion.isAcceptableOrUnknown(
          data['feature_schema_version']!,
          _featureSchemaVersionMeta,
        ),
      );
    }
    if (data.containsKey('source_audio_sha256')) {
      context.handle(
        _sourceAudioSha256Meta,
        sourceAudioSha256.isAcceptableOrUnknown(
          data['source_audio_sha256']!,
          _sourceAudioSha256Meta,
        ),
      );
    }
    if (data.containsKey('source_audio_byte_length')) {
      context.handle(
        _sourceAudioByteLengthMeta,
        sourceAudioByteLength.isAcceptableOrUnknown(
          data['source_audio_byte_length']!,
          _sourceAudioByteLengthMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {runId};
  @override
  FeatureSeriesMetadataData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FeatureSeriesMetadataData(
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}run_id'],
      )!,
      frameCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}frame_count'],
      )!,
      startSampleIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_sample_index'],
      )!,
      samplePeriodSamples: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sample_period_samples'],
      )!,
      algorithmVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}algorithm_version'],
      )!,
      featureSchemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}feature_schema_version'],
      )!,
      sourceAudioSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_audio_sha256'],
      ),
      sourceAudioByteLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_audio_byte_length'],
      ),
    );
  }

  @override
  $FeatureSeriesMetadataTable createAlias(String alias) {
    return $FeatureSeriesMetadataTable(attachedDatabase, alias);
  }
}

class FeatureSeriesMetadataData extends DataClass
    implements Insertable<FeatureSeriesMetadataData> {
  final int runId;
  final int frameCount;
  final int startSampleIndex;
  final int samplePeriodSamples;
  final String algorithmVersion;
  final int featureSchemaVersion;
  final String? sourceAudioSha256;
  final int? sourceAudioByteLength;
  const FeatureSeriesMetadataData({
    required this.runId,
    required this.frameCount,
    required this.startSampleIndex,
    required this.samplePeriodSamples,
    required this.algorithmVersion,
    required this.featureSchemaVersion,
    this.sourceAudioSha256,
    this.sourceAudioByteLength,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['run_id'] = Variable<int>(runId);
    map['frame_count'] = Variable<int>(frameCount);
    map['start_sample_index'] = Variable<int>(startSampleIndex);
    map['sample_period_samples'] = Variable<int>(samplePeriodSamples);
    map['algorithm_version'] = Variable<String>(algorithmVersion);
    map['feature_schema_version'] = Variable<int>(featureSchemaVersion);
    if (!nullToAbsent || sourceAudioSha256 != null) {
      map['source_audio_sha256'] = Variable<String>(sourceAudioSha256);
    }
    if (!nullToAbsent || sourceAudioByteLength != null) {
      map['source_audio_byte_length'] = Variable<int>(sourceAudioByteLength);
    }
    return map;
  }

  FeatureSeriesMetadataCompanion toCompanion(bool nullToAbsent) {
    return FeatureSeriesMetadataCompanion(
      runId: Value(runId),
      frameCount: Value(frameCount),
      startSampleIndex: Value(startSampleIndex),
      samplePeriodSamples: Value(samplePeriodSamples),
      algorithmVersion: Value(algorithmVersion),
      featureSchemaVersion: Value(featureSchemaVersion),
      sourceAudioSha256: sourceAudioSha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceAudioSha256),
      sourceAudioByteLength: sourceAudioByteLength == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceAudioByteLength),
    );
  }

  factory FeatureSeriesMetadataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FeatureSeriesMetadataData(
      runId: serializer.fromJson<int>(json['runId']),
      frameCount: serializer.fromJson<int>(json['frameCount']),
      startSampleIndex: serializer.fromJson<int>(json['startSampleIndex']),
      samplePeriodSamples: serializer.fromJson<int>(
        json['samplePeriodSamples'],
      ),
      algorithmVersion: serializer.fromJson<String>(json['algorithmVersion']),
      featureSchemaVersion: serializer.fromJson<int>(
        json['featureSchemaVersion'],
      ),
      sourceAudioSha256: serializer.fromJson<String?>(
        json['sourceAudioSha256'],
      ),
      sourceAudioByteLength: serializer.fromJson<int?>(
        json['sourceAudioByteLength'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'runId': serializer.toJson<int>(runId),
      'frameCount': serializer.toJson<int>(frameCount),
      'startSampleIndex': serializer.toJson<int>(startSampleIndex),
      'samplePeriodSamples': serializer.toJson<int>(samplePeriodSamples),
      'algorithmVersion': serializer.toJson<String>(algorithmVersion),
      'featureSchemaVersion': serializer.toJson<int>(featureSchemaVersion),
      'sourceAudioSha256': serializer.toJson<String?>(sourceAudioSha256),
      'sourceAudioByteLength': serializer.toJson<int?>(sourceAudioByteLength),
    };
  }

  FeatureSeriesMetadataData copyWith({
    int? runId,
    int? frameCount,
    int? startSampleIndex,
    int? samplePeriodSamples,
    String? algorithmVersion,
    int? featureSchemaVersion,
    Value<String?> sourceAudioSha256 = const Value.absent(),
    Value<int?> sourceAudioByteLength = const Value.absent(),
  }) => FeatureSeriesMetadataData(
    runId: runId ?? this.runId,
    frameCount: frameCount ?? this.frameCount,
    startSampleIndex: startSampleIndex ?? this.startSampleIndex,
    samplePeriodSamples: samplePeriodSamples ?? this.samplePeriodSamples,
    algorithmVersion: algorithmVersion ?? this.algorithmVersion,
    featureSchemaVersion: featureSchemaVersion ?? this.featureSchemaVersion,
    sourceAudioSha256: sourceAudioSha256.present
        ? sourceAudioSha256.value
        : this.sourceAudioSha256,
    sourceAudioByteLength: sourceAudioByteLength.present
        ? sourceAudioByteLength.value
        : this.sourceAudioByteLength,
  );
  FeatureSeriesMetadataData copyWithCompanion(
    FeatureSeriesMetadataCompanion data,
  ) {
    return FeatureSeriesMetadataData(
      runId: data.runId.present ? data.runId.value : this.runId,
      frameCount: data.frameCount.present
          ? data.frameCount.value
          : this.frameCount,
      startSampleIndex: data.startSampleIndex.present
          ? data.startSampleIndex.value
          : this.startSampleIndex,
      samplePeriodSamples: data.samplePeriodSamples.present
          ? data.samplePeriodSamples.value
          : this.samplePeriodSamples,
      algorithmVersion: data.algorithmVersion.present
          ? data.algorithmVersion.value
          : this.algorithmVersion,
      featureSchemaVersion: data.featureSchemaVersion.present
          ? data.featureSchemaVersion.value
          : this.featureSchemaVersion,
      sourceAudioSha256: data.sourceAudioSha256.present
          ? data.sourceAudioSha256.value
          : this.sourceAudioSha256,
      sourceAudioByteLength: data.sourceAudioByteLength.present
          ? data.sourceAudioByteLength.value
          : this.sourceAudioByteLength,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FeatureSeriesMetadataData(')
          ..write('runId: $runId, ')
          ..write('frameCount: $frameCount, ')
          ..write('startSampleIndex: $startSampleIndex, ')
          ..write('samplePeriodSamples: $samplePeriodSamples, ')
          ..write('algorithmVersion: $algorithmVersion, ')
          ..write('featureSchemaVersion: $featureSchemaVersion, ')
          ..write('sourceAudioSha256: $sourceAudioSha256, ')
          ..write('sourceAudioByteLength: $sourceAudioByteLength')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    runId,
    frameCount,
    startSampleIndex,
    samplePeriodSamples,
    algorithmVersion,
    featureSchemaVersion,
    sourceAudioSha256,
    sourceAudioByteLength,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FeatureSeriesMetadataData &&
          other.runId == this.runId &&
          other.frameCount == this.frameCount &&
          other.startSampleIndex == this.startSampleIndex &&
          other.samplePeriodSamples == this.samplePeriodSamples &&
          other.algorithmVersion == this.algorithmVersion &&
          other.featureSchemaVersion == this.featureSchemaVersion &&
          other.sourceAudioSha256 == this.sourceAudioSha256 &&
          other.sourceAudioByteLength == this.sourceAudioByteLength);
}

class FeatureSeriesMetadataCompanion
    extends UpdateCompanion<FeatureSeriesMetadataData> {
  final Value<int> runId;
  final Value<int> frameCount;
  final Value<int> startSampleIndex;
  final Value<int> samplePeriodSamples;
  final Value<String> algorithmVersion;
  final Value<int> featureSchemaVersion;
  final Value<String?> sourceAudioSha256;
  final Value<int?> sourceAudioByteLength;
  const FeatureSeriesMetadataCompanion({
    this.runId = const Value.absent(),
    this.frameCount = const Value.absent(),
    this.startSampleIndex = const Value.absent(),
    this.samplePeriodSamples = const Value.absent(),
    this.algorithmVersion = const Value.absent(),
    this.featureSchemaVersion = const Value.absent(),
    this.sourceAudioSha256 = const Value.absent(),
    this.sourceAudioByteLength = const Value.absent(),
  });
  FeatureSeriesMetadataCompanion.insert({
    this.runId = const Value.absent(),
    required int frameCount,
    required int startSampleIndex,
    required int samplePeriodSamples,
    required String algorithmVersion,
    this.featureSchemaVersion = const Value.absent(),
    this.sourceAudioSha256 = const Value.absent(),
    this.sourceAudioByteLength = const Value.absent(),
  }) : frameCount = Value(frameCount),
       startSampleIndex = Value(startSampleIndex),
       samplePeriodSamples = Value(samplePeriodSamples),
       algorithmVersion = Value(algorithmVersion);
  static Insertable<FeatureSeriesMetadataData> custom({
    Expression<int>? runId,
    Expression<int>? frameCount,
    Expression<int>? startSampleIndex,
    Expression<int>? samplePeriodSamples,
    Expression<String>? algorithmVersion,
    Expression<int>? featureSchemaVersion,
    Expression<String>? sourceAudioSha256,
    Expression<int>? sourceAudioByteLength,
  }) {
    return RawValuesInsertable({
      if (runId != null) 'run_id': runId,
      if (frameCount != null) 'frame_count': frameCount,
      if (startSampleIndex != null) 'start_sample_index': startSampleIndex,
      if (samplePeriodSamples != null)
        'sample_period_samples': samplePeriodSamples,
      if (algorithmVersion != null) 'algorithm_version': algorithmVersion,
      if (featureSchemaVersion != null)
        'feature_schema_version': featureSchemaVersion,
      if (sourceAudioSha256 != null) 'source_audio_sha256': sourceAudioSha256,
      if (sourceAudioByteLength != null)
        'source_audio_byte_length': sourceAudioByteLength,
    });
  }

  FeatureSeriesMetadataCompanion copyWith({
    Value<int>? runId,
    Value<int>? frameCount,
    Value<int>? startSampleIndex,
    Value<int>? samplePeriodSamples,
    Value<String>? algorithmVersion,
    Value<int>? featureSchemaVersion,
    Value<String?>? sourceAudioSha256,
    Value<int?>? sourceAudioByteLength,
  }) {
    return FeatureSeriesMetadataCompanion(
      runId: runId ?? this.runId,
      frameCount: frameCount ?? this.frameCount,
      startSampleIndex: startSampleIndex ?? this.startSampleIndex,
      samplePeriodSamples: samplePeriodSamples ?? this.samplePeriodSamples,
      algorithmVersion: algorithmVersion ?? this.algorithmVersion,
      featureSchemaVersion: featureSchemaVersion ?? this.featureSchemaVersion,
      sourceAudioSha256: sourceAudioSha256 ?? this.sourceAudioSha256,
      sourceAudioByteLength:
          sourceAudioByteLength ?? this.sourceAudioByteLength,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (runId.present) {
      map['run_id'] = Variable<int>(runId.value);
    }
    if (frameCount.present) {
      map['frame_count'] = Variable<int>(frameCount.value);
    }
    if (startSampleIndex.present) {
      map['start_sample_index'] = Variable<int>(startSampleIndex.value);
    }
    if (samplePeriodSamples.present) {
      map['sample_period_samples'] = Variable<int>(samplePeriodSamples.value);
    }
    if (algorithmVersion.present) {
      map['algorithm_version'] = Variable<String>(algorithmVersion.value);
    }
    if (featureSchemaVersion.present) {
      map['feature_schema_version'] = Variable<int>(featureSchemaVersion.value);
    }
    if (sourceAudioSha256.present) {
      map['source_audio_sha256'] = Variable<String>(sourceAudioSha256.value);
    }
    if (sourceAudioByteLength.present) {
      map['source_audio_byte_length'] = Variable<int>(
        sourceAudioByteLength.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FeatureSeriesMetadataCompanion(')
          ..write('runId: $runId, ')
          ..write('frameCount: $frameCount, ')
          ..write('startSampleIndex: $startSampleIndex, ')
          ..write('samplePeriodSamples: $samplePeriodSamples, ')
          ..write('algorithmVersion: $algorithmVersion, ')
          ..write('featureSchemaVersion: $featureSchemaVersion, ')
          ..write('sourceAudioSha256: $sourceAudioSha256, ')
          ..write('sourceAudioByteLength: $sourceAudioByteLength')
          ..write(')'))
        .toString();
  }
}

class $SavedVoiceComparisonPlansTable extends SavedVoiceComparisonPlans
    with TableInfo<$SavedVoiceComparisonPlansTable, SavedVoiceComparisonPlan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedVoiceComparisonPlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schemaVersionMeta = const VerificationMeta(
    'schemaVersion',
  );
  @override
  late final GeneratedColumn<int> schemaVersion = GeneratedColumn<int>(
    'schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    schemaVersion,
    payloadJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_voice_comparison_plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedVoiceComparisonPlan> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('schema_version')) {
      context.handle(
        _schemaVersionMeta,
        schemaVersion.isAcceptableOrUnknown(
          data['schema_version']!,
          _schemaVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_schemaVersionMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedVoiceComparisonPlan map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedVoiceComparisonPlan(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      schemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schema_version'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SavedVoiceComparisonPlansTable createAlias(String alias) {
    return $SavedVoiceComparisonPlansTable(attachedDatabase, alias);
  }
}

class SavedVoiceComparisonPlan extends DataClass
    implements Insertable<SavedVoiceComparisonPlan> {
  final String id;
  final int schemaVersion;
  final String payloadJson;
  final DateTime updatedAt;
  const SavedVoiceComparisonPlan({
    required this.id,
    required this.schemaVersion,
    required this.payloadJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['schema_version'] = Variable<int>(schemaVersion);
    map['payload_json'] = Variable<String>(payloadJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SavedVoiceComparisonPlansCompanion toCompanion(bool nullToAbsent) {
    return SavedVoiceComparisonPlansCompanion(
      id: Value(id),
      schemaVersion: Value(schemaVersion),
      payloadJson: Value(payloadJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory SavedVoiceComparisonPlan.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedVoiceComparisonPlan(
      id: serializer.fromJson<String>(json['id']),
      schemaVersion: serializer.fromJson<int>(json['schemaVersion']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'schemaVersion': serializer.toJson<int>(schemaVersion),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SavedVoiceComparisonPlan copyWith({
    String? id,
    int? schemaVersion,
    String? payloadJson,
    DateTime? updatedAt,
  }) => SavedVoiceComparisonPlan(
    id: id ?? this.id,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    payloadJson: payloadJson ?? this.payloadJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SavedVoiceComparisonPlan copyWithCompanion(
    SavedVoiceComparisonPlansCompanion data,
  ) {
    return SavedVoiceComparisonPlan(
      id: data.id.present ? data.id.value : this.id,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedVoiceComparisonPlan(')
          ..write('id: $id, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, schemaVersion, payloadJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedVoiceComparisonPlan &&
          other.id == this.id &&
          other.schemaVersion == this.schemaVersion &&
          other.payloadJson == this.payloadJson &&
          other.updatedAt == this.updatedAt);
}

class SavedVoiceComparisonPlansCompanion
    extends UpdateCompanion<SavedVoiceComparisonPlan> {
  final Value<String> id;
  final Value<int> schemaVersion;
  final Value<String> payloadJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SavedVoiceComparisonPlansCompanion({
    this.id = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedVoiceComparisonPlansCompanion.insert({
    required String id,
    required int schemaVersion,
    required String payloadJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       schemaVersion = Value(schemaVersion),
       payloadJson = Value(payloadJson),
       updatedAt = Value(updatedAt);
  static Insertable<SavedVoiceComparisonPlan> custom({
    Expression<String>? id,
    Expression<int>? schemaVersion,
    Expression<String>? payloadJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedVoiceComparisonPlansCompanion copyWith({
    Value<String>? id,
    Value<int>? schemaVersion,
    Value<String>? payloadJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SavedVoiceComparisonPlansCompanion(
      id: id ?? this.id,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      payloadJson: payloadJson ?? this.payloadJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<int>(schemaVersion.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedVoiceComparisonPlansCompanion(')
          ..write('id: $id, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PracticeSessionsTable practiceSessions = $PracticeSessionsTable(
    this,
  );
  late final $RecordingsTable recordings = $RecordingsTable(this);
  late final $AnalysisRunsTable analysisRuns = $AnalysisRunsTable(this);
  late final $FeatureSeriesTableTable featureSeriesTable =
      $FeatureSeriesTableTable(this);
  late final $FeatureSeriesMetadataTable featureSeriesMetadata =
      $FeatureSeriesMetadataTable(this);
  late final $SavedVoiceComparisonPlansTable savedVoiceComparisonPlans =
      $SavedVoiceComparisonPlansTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    practiceSessions,
    recordings,
    analysisRuns,
    featureSeriesTable,
    featureSeriesMetadata,
    savedVoiceComparisonPlans,
  ];
}

typedef $$PracticeSessionsTableCreateCompanionBuilder =
    PracticeSessionsCompanion Function({
      required String id,
      required String templateJson,
      required DateTime startedAt,
      required int validFrameCount,
      required int totalFrameCount,
      required String qualityFlagsJson,
      Value<String> summaryJson,
      Value<String?> voiceComparisonJson,
      Value<int> rowid,
    });
typedef $$PracticeSessionsTableUpdateCompanionBuilder =
    PracticeSessionsCompanion Function({
      Value<String> id,
      Value<String> templateJson,
      Value<DateTime> startedAt,
      Value<int> validFrameCount,
      Value<int> totalFrameCount,
      Value<String> qualityFlagsJson,
      Value<String> summaryJson,
      Value<String?> voiceComparisonJson,
      Value<int> rowid,
    });

final class $$PracticeSessionsTableReferences
    extends
        BaseReferences<_$AppDatabase, $PracticeSessionsTable, PracticeSession> {
  $$PracticeSessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$RecordingsTable, List<Recording>>
  _recordingsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.recordings,
    aliasName: 'practice_sessions__id__recordings__session_id',
  );

  $$RecordingsTableProcessedTableManager get recordingsRefs {
    final manager = $$RecordingsTableTableManager(
      $_db,
      $_db.recordings,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_recordingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AnalysisRunsTable, List<AnalysisRun>>
  _analysisRunsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.analysisRuns,
    aliasName: 'practice_sessions__id__analysis_runs__session_id',
  );

  $$AnalysisRunsTableProcessedTableManager get analysisRunsRefs {
    final manager = $$AnalysisRunsTableTableManager(
      $_db,
      $_db.analysisRuns,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_analysisRunsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PracticeSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $PracticeSessionsTable> {
  $$PracticeSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateJson => $composableBuilder(
    column: $table.templateJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get validFrameCount => $composableBuilder(
    column: $table.validFrameCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalFrameCount => $composableBuilder(
    column: $table.totalFrameCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get qualityFlagsJson => $composableBuilder(
    column: $table.qualityFlagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voiceComparisonJson => $composableBuilder(
    column: $table.voiceComparisonJson,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> recordingsRefs(
    Expression<bool> Function($$RecordingsTableFilterComposer f) f,
  ) {
    final $$RecordingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recordings,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingsTableFilterComposer(
            $db: $db,
            $table: $db.recordings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> analysisRunsRefs(
    Expression<bool> Function($$AnalysisRunsTableFilterComposer f) f,
  ) {
    final $$AnalysisRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.analysisRuns,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnalysisRunsTableFilterComposer(
            $db: $db,
            $table: $db.analysisRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PracticeSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PracticeSessionsTable> {
  $$PracticeSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateJson => $composableBuilder(
    column: $table.templateJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get validFrameCount => $composableBuilder(
    column: $table.validFrameCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalFrameCount => $composableBuilder(
    column: $table.totalFrameCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get qualityFlagsJson => $composableBuilder(
    column: $table.qualityFlagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voiceComparisonJson => $composableBuilder(
    column: $table.voiceComparisonJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PracticeSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PracticeSessionsTable> {
  $$PracticeSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get templateJson => $composableBuilder(
    column: $table.templateJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get validFrameCount => $composableBuilder(
    column: $table.validFrameCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalFrameCount => $composableBuilder(
    column: $table.totalFrameCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get qualityFlagsJson => $composableBuilder(
    column: $table.qualityFlagsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get voiceComparisonJson => $composableBuilder(
    column: $table.voiceComparisonJson,
    builder: (column) => column,
  );

  Expression<T> recordingsRefs<T extends Object>(
    Expression<T> Function($$RecordingsTableAnnotationComposer a) f,
  ) {
    final $$RecordingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recordings,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingsTableAnnotationComposer(
            $db: $db,
            $table: $db.recordings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> analysisRunsRefs<T extends Object>(
    Expression<T> Function($$AnalysisRunsTableAnnotationComposer a) f,
  ) {
    final $$AnalysisRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.analysisRuns,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnalysisRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.analysisRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PracticeSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PracticeSessionsTable,
          PracticeSession,
          $$PracticeSessionsTableFilterComposer,
          $$PracticeSessionsTableOrderingComposer,
          $$PracticeSessionsTableAnnotationComposer,
          $$PracticeSessionsTableCreateCompanionBuilder,
          $$PracticeSessionsTableUpdateCompanionBuilder,
          (PracticeSession, $$PracticeSessionsTableReferences),
          PracticeSession,
          PrefetchHooks Function({bool recordingsRefs, bool analysisRunsRefs})
        > {
  $$PracticeSessionsTableTableManager(
    _$AppDatabase db,
    $PracticeSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PracticeSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PracticeSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PracticeSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> templateJson = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<int> validFrameCount = const Value.absent(),
                Value<int> totalFrameCount = const Value.absent(),
                Value<String> qualityFlagsJson = const Value.absent(),
                Value<String> summaryJson = const Value.absent(),
                Value<String?> voiceComparisonJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PracticeSessionsCompanion(
                id: id,
                templateJson: templateJson,
                startedAt: startedAt,
                validFrameCount: validFrameCount,
                totalFrameCount: totalFrameCount,
                qualityFlagsJson: qualityFlagsJson,
                summaryJson: summaryJson,
                voiceComparisonJson: voiceComparisonJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String templateJson,
                required DateTime startedAt,
                required int validFrameCount,
                required int totalFrameCount,
                required String qualityFlagsJson,
                Value<String> summaryJson = const Value.absent(),
                Value<String?> voiceComparisonJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PracticeSessionsCompanion.insert(
                id: id,
                templateJson: templateJson,
                startedAt: startedAt,
                validFrameCount: validFrameCount,
                totalFrameCount: totalFrameCount,
                qualityFlagsJson: qualityFlagsJson,
                summaryJson: summaryJson,
                voiceComparisonJson: voiceComparisonJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PracticeSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({recordingsRefs = false, analysisRunsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (recordingsRefs) db.recordings,
                    if (analysisRunsRefs) db.analysisRuns,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (recordingsRefs)
                        await $_getPrefetchedData<
                          PracticeSession,
                          $PracticeSessionsTable,
                          Recording
                        >(
                          currentTable: table,
                          referencedTable: $$PracticeSessionsTableReferences
                              ._recordingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PracticeSessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).recordingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (analysisRunsRefs)
                        await $_getPrefetchedData<
                          PracticeSession,
                          $PracticeSessionsTable,
                          AnalysisRun
                        >(
                          currentTable: table,
                          referencedTable: $$PracticeSessionsTableReferences
                              ._analysisRunsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PracticeSessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).analysisRunsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PracticeSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PracticeSessionsTable,
      PracticeSession,
      $$PracticeSessionsTableFilterComposer,
      $$PracticeSessionsTableOrderingComposer,
      $$PracticeSessionsTableAnnotationComposer,
      $$PracticeSessionsTableCreateCompanionBuilder,
      $$PracticeSessionsTableUpdateCompanionBuilder,
      (PracticeSession, $$PracticeSessionsTableReferences),
      PracticeSession,
      PrefetchHooks Function({bool recordingsRefs, bool analysisRunsRefs})
    >;
typedef $$RecordingsTableCreateCompanionBuilder =
    RecordingsCompanion Function({
      required String sessionId,
      required String locator,
      required String storageKind,
      Value<String?> contentSha256,
      Value<int?> contentByteLength,
      Value<bool> pendingDelete,
      Value<int> rowid,
    });
typedef $$RecordingsTableUpdateCompanionBuilder =
    RecordingsCompanion Function({
      Value<String> sessionId,
      Value<String> locator,
      Value<String> storageKind,
      Value<String?> contentSha256,
      Value<int?> contentByteLength,
      Value<bool> pendingDelete,
      Value<int> rowid,
    });

final class $$RecordingsTableReferences
    extends BaseReferences<_$AppDatabase, $RecordingsTable, Recording> {
  $$RecordingsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PracticeSessionsTable _sessionIdTable(_$AppDatabase db) => db
      .practiceSessions
      .createAlias('recordings__session_id__practice_sessions__id');

  $$PracticeSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$PracticeSessionsTableTableManager(
      $_db,
      $_db.practiceSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RecordingsTableFilterComposer
    extends Composer<_$AppDatabase, $RecordingsTable> {
  $$RecordingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get locator => $composableBuilder(
    column: $table.locator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storageKind => $composableBuilder(
    column: $table.storageKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentSha256 => $composableBuilder(
    column: $table.contentSha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get contentByteLength => $composableBuilder(
    column: $table.contentByteLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pendingDelete => $composableBuilder(
    column: $table.pendingDelete,
    builder: (column) => ColumnFilters(column),
  );

  $$PracticeSessionsTableFilterComposer get sessionId {
    final $$PracticeSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.practiceSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticeSessionsTableFilterComposer(
            $db: $db,
            $table: $db.practiceSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecordingsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecordingsTable> {
  $$RecordingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get locator => $composableBuilder(
    column: $table.locator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storageKind => $composableBuilder(
    column: $table.storageKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentSha256 => $composableBuilder(
    column: $table.contentSha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contentByteLength => $composableBuilder(
    column: $table.contentByteLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pendingDelete => $composableBuilder(
    column: $table.pendingDelete,
    builder: (column) => ColumnOrderings(column),
  );

  $$PracticeSessionsTableOrderingComposer get sessionId {
    final $$PracticeSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.practiceSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticeSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.practiceSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecordingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecordingsTable> {
  $$RecordingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get locator =>
      $composableBuilder(column: $table.locator, builder: (column) => column);

  GeneratedColumn<String> get storageKind => $composableBuilder(
    column: $table.storageKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentSha256 => $composableBuilder(
    column: $table.contentSha256,
    builder: (column) => column,
  );

  GeneratedColumn<int> get contentByteLength => $composableBuilder(
    column: $table.contentByteLength,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get pendingDelete => $composableBuilder(
    column: $table.pendingDelete,
    builder: (column) => column,
  );

  $$PracticeSessionsTableAnnotationComposer get sessionId {
    final $$PracticeSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.practiceSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticeSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.practiceSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecordingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecordingsTable,
          Recording,
          $$RecordingsTableFilterComposer,
          $$RecordingsTableOrderingComposer,
          $$RecordingsTableAnnotationComposer,
          $$RecordingsTableCreateCompanionBuilder,
          $$RecordingsTableUpdateCompanionBuilder,
          (Recording, $$RecordingsTableReferences),
          Recording,
          PrefetchHooks Function({bool sessionId})
        > {
  $$RecordingsTableTableManager(_$AppDatabase db, $RecordingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecordingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecordingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecordingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<String> locator = const Value.absent(),
                Value<String> storageKind = const Value.absent(),
                Value<String?> contentSha256 = const Value.absent(),
                Value<int?> contentByteLength = const Value.absent(),
                Value<bool> pendingDelete = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecordingsCompanion(
                sessionId: sessionId,
                locator: locator,
                storageKind: storageKind,
                contentSha256: contentSha256,
                contentByteLength: contentByteLength,
                pendingDelete: pendingDelete,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required String locator,
                required String storageKind,
                Value<String?> contentSha256 = const Value.absent(),
                Value<int?> contentByteLength = const Value.absent(),
                Value<bool> pendingDelete = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecordingsCompanion.insert(
                sessionId: sessionId,
                locator: locator,
                storageKind: storageKind,
                contentSha256: contentSha256,
                contentByteLength: contentByteLength,
                pendingDelete: pendingDelete,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RecordingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable: $$RecordingsTableReferences
                                    ._sessionIdTable(db),
                                referencedColumn: $$RecordingsTableReferences
                                    ._sessionIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RecordingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecordingsTable,
      Recording,
      $$RecordingsTableFilterComposer,
      $$RecordingsTableOrderingComposer,
      $$RecordingsTableAnnotationComposer,
      $$RecordingsTableCreateCompanionBuilder,
      $$RecordingsTableUpdateCompanionBuilder,
      (Recording, $$RecordingsTableReferences),
      Recording,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$AnalysisRunsTableCreateCompanionBuilder =
    AnalysisRunsCompanion Function({
      Value<int> id,
      required String sessionId,
      required DateTime createdAt,
      required String algorithmVersion,
    });
typedef $$AnalysisRunsTableUpdateCompanionBuilder =
    AnalysisRunsCompanion Function({
      Value<int> id,
      Value<String> sessionId,
      Value<DateTime> createdAt,
      Value<String> algorithmVersion,
    });

final class $$AnalysisRunsTableReferences
    extends BaseReferences<_$AppDatabase, $AnalysisRunsTable, AnalysisRun> {
  $$AnalysisRunsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PracticeSessionsTable _sessionIdTable(_$AppDatabase db) => db
      .practiceSessions
      .createAlias('analysis_runs__session_id__practice_sessions__id');

  $$PracticeSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$PracticeSessionsTableTableManager(
      $_db,
      $_db.practiceSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $FeatureSeriesTableTable,
    List<FeatureSeriesTableData>
  >
  _featureSeriesTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.featureSeriesTable,
        aliasName: 'analysis_runs__id__feature_series__run_id',
      );

  $$FeatureSeriesTableTableProcessedTableManager get featureSeriesTableRefs {
    final manager = $$FeatureSeriesTableTableTableManager(
      $_db,
      $_db.featureSeriesTable,
    ).filter((f) => f.runId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _featureSeriesTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $FeatureSeriesMetadataTable,
    List<FeatureSeriesMetadataData>
  >
  _featureSeriesMetadataRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.featureSeriesMetadata,
        aliasName: 'analysis_runs__id__feature_series_metadata__run_id',
      );

  $$FeatureSeriesMetadataTableProcessedTableManager
  get featureSeriesMetadataRefs {
    final manager = $$FeatureSeriesMetadataTableTableManager(
      $_db,
      $_db.featureSeriesMetadata,
    ).filter((f) => f.runId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _featureSeriesMetadataRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AnalysisRunsTableFilterComposer
    extends Composer<_$AppDatabase, $AnalysisRunsTable> {
  $$AnalysisRunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => ColumnFilters(column),
  );

  $$PracticeSessionsTableFilterComposer get sessionId {
    final $$PracticeSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.practiceSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticeSessionsTableFilterComposer(
            $db: $db,
            $table: $db.practiceSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> featureSeriesTableRefs(
    Expression<bool> Function($$FeatureSeriesTableTableFilterComposer f) f,
  ) {
    final $$FeatureSeriesTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.featureSeriesTable,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FeatureSeriesTableTableFilterComposer(
            $db: $db,
            $table: $db.featureSeriesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> featureSeriesMetadataRefs(
    Expression<bool> Function($$FeatureSeriesMetadataTableFilterComposer f) f,
  ) {
    final $$FeatureSeriesMetadataTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.featureSeriesMetadata,
          getReferencedColumn: (t) => t.runId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FeatureSeriesMetadataTableFilterComposer(
                $db: $db,
                $table: $db.featureSeriesMetadata,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$AnalysisRunsTableOrderingComposer
    extends Composer<_$AppDatabase, $AnalysisRunsTable> {
  $$AnalysisRunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => ColumnOrderings(column),
  );

  $$PracticeSessionsTableOrderingComposer get sessionId {
    final $$PracticeSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.practiceSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticeSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.practiceSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AnalysisRunsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnalysisRunsTable> {
  $$AnalysisRunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => column,
  );

  $$PracticeSessionsTableAnnotationComposer get sessionId {
    final $$PracticeSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.practiceSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticeSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.practiceSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> featureSeriesTableRefs<T extends Object>(
    Expression<T> Function($$FeatureSeriesTableTableAnnotationComposer a) f,
  ) {
    final $$FeatureSeriesTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.featureSeriesTable,
          getReferencedColumn: (t) => t.runId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FeatureSeriesTableTableAnnotationComposer(
                $db: $db,
                $table: $db.featureSeriesTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> featureSeriesMetadataRefs<T extends Object>(
    Expression<T> Function($$FeatureSeriesMetadataTableAnnotationComposer a) f,
  ) {
    final $$FeatureSeriesMetadataTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.featureSeriesMetadata,
          getReferencedColumn: (t) => t.runId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FeatureSeriesMetadataTableAnnotationComposer(
                $db: $db,
                $table: $db.featureSeriesMetadata,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$AnalysisRunsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AnalysisRunsTable,
          AnalysisRun,
          $$AnalysisRunsTableFilterComposer,
          $$AnalysisRunsTableOrderingComposer,
          $$AnalysisRunsTableAnnotationComposer,
          $$AnalysisRunsTableCreateCompanionBuilder,
          $$AnalysisRunsTableUpdateCompanionBuilder,
          (AnalysisRun, $$AnalysisRunsTableReferences),
          AnalysisRun,
          PrefetchHooks Function({
            bool sessionId,
            bool featureSeriesTableRefs,
            bool featureSeriesMetadataRefs,
          })
        > {
  $$AnalysisRunsTableTableManager(_$AppDatabase db, $AnalysisRunsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnalysisRunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnalysisRunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnalysisRunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> algorithmVersion = const Value.absent(),
              }) => AnalysisRunsCompanion(
                id: id,
                sessionId: sessionId,
                createdAt: createdAt,
                algorithmVersion: algorithmVersion,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sessionId,
                required DateTime createdAt,
                required String algorithmVersion,
              }) => AnalysisRunsCompanion.insert(
                id: id,
                sessionId: sessionId,
                createdAt: createdAt,
                algorithmVersion: algorithmVersion,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AnalysisRunsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                sessionId = false,
                featureSeriesTableRefs = false,
                featureSeriesMetadataRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (featureSeriesTableRefs) db.featureSeriesTable,
                    if (featureSeriesMetadataRefs) db.featureSeriesMetadata,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (sessionId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.sessionId,
                                    referencedTable:
                                        $$AnalysisRunsTableReferences
                                            ._sessionIdTable(db),
                                    referencedColumn:
                                        $$AnalysisRunsTableReferences
                                            ._sessionIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (featureSeriesTableRefs)
                        await $_getPrefetchedData<
                          AnalysisRun,
                          $AnalysisRunsTable,
                          FeatureSeriesTableData
                        >(
                          currentTable: table,
                          referencedTable: $$AnalysisRunsTableReferences
                              ._featureSeriesTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AnalysisRunsTableReferences(
                                db,
                                table,
                                p0,
                              ).featureSeriesTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.runId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (featureSeriesMetadataRefs)
                        await $_getPrefetchedData<
                          AnalysisRun,
                          $AnalysisRunsTable,
                          FeatureSeriesMetadataData
                        >(
                          currentTable: table,
                          referencedTable: $$AnalysisRunsTableReferences
                              ._featureSeriesMetadataRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AnalysisRunsTableReferences(
                                db,
                                table,
                                p0,
                              ).featureSeriesMetadataRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.runId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$AnalysisRunsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AnalysisRunsTable,
      AnalysisRun,
      $$AnalysisRunsTableFilterComposer,
      $$AnalysisRunsTableOrderingComposer,
      $$AnalysisRunsTableAnnotationComposer,
      $$AnalysisRunsTableCreateCompanionBuilder,
      $$AnalysisRunsTableUpdateCompanionBuilder,
      (AnalysisRun, $$AnalysisRunsTableReferences),
      AnalysisRun,
      PrefetchHooks Function({
        bool sessionId,
        bool featureSeriesTableRefs,
        bool featureSeriesMetadataRefs,
      })
    >;
typedef $$FeatureSeriesTableTableCreateCompanionBuilder =
    FeatureSeriesTableCompanion Function({
      Value<int> id,
      required int runId,
      required String kind,
      required int frameCount,
      required int codecVersion,
      required Uint8List payload,
      required String sha256,
    });
typedef $$FeatureSeriesTableTableUpdateCompanionBuilder =
    FeatureSeriesTableCompanion Function({
      Value<int> id,
      Value<int> runId,
      Value<String> kind,
      Value<int> frameCount,
      Value<int> codecVersion,
      Value<Uint8List> payload,
      Value<String> sha256,
    });

final class $$FeatureSeriesTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $FeatureSeriesTableTable,
          FeatureSeriesTableData
        > {
  $$FeatureSeriesTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AnalysisRunsTable _runIdTable(_$AppDatabase db) =>
      db.analysisRuns.createAlias('feature_series__run_id__analysis_runs__id');

  $$AnalysisRunsTableProcessedTableManager get runId {
    final $_column = $_itemColumn<int>('run_id')!;

    final manager = $$AnalysisRunsTableTableManager(
      $_db,
      $_db.analysisRuns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_runIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FeatureSeriesTableTableFilterComposer
    extends Composer<_$AppDatabase, $FeatureSeriesTableTable> {
  $$FeatureSeriesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get frameCount => $composableBuilder(
    column: $table.frameCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get codecVersion => $composableBuilder(
    column: $table.codecVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  $$AnalysisRunsTableFilterComposer get runId {
    final $$AnalysisRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.analysisRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnalysisRunsTableFilterComposer(
            $db: $db,
            $table: $db.analysisRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FeatureSeriesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $FeatureSeriesTableTable> {
  $$FeatureSeriesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get frameCount => $composableBuilder(
    column: $table.frameCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get codecVersion => $composableBuilder(
    column: $table.codecVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  $$AnalysisRunsTableOrderingComposer get runId {
    final $$AnalysisRunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.analysisRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnalysisRunsTableOrderingComposer(
            $db: $db,
            $table: $db.analysisRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FeatureSeriesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $FeatureSeriesTableTable> {
  $$FeatureSeriesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get frameCount => $composableBuilder(
    column: $table.frameCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get codecVersion => $composableBuilder(
    column: $table.codecVersion,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  $$AnalysisRunsTableAnnotationComposer get runId {
    final $$AnalysisRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.analysisRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnalysisRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.analysisRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FeatureSeriesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FeatureSeriesTableTable,
          FeatureSeriesTableData,
          $$FeatureSeriesTableTableFilterComposer,
          $$FeatureSeriesTableTableOrderingComposer,
          $$FeatureSeriesTableTableAnnotationComposer,
          $$FeatureSeriesTableTableCreateCompanionBuilder,
          $$FeatureSeriesTableTableUpdateCompanionBuilder,
          (FeatureSeriesTableData, $$FeatureSeriesTableTableReferences),
          FeatureSeriesTableData,
          PrefetchHooks Function({bool runId})
        > {
  $$FeatureSeriesTableTableTableManager(
    _$AppDatabase db,
    $FeatureSeriesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FeatureSeriesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FeatureSeriesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FeatureSeriesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> runId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> frameCount = const Value.absent(),
                Value<int> codecVersion = const Value.absent(),
                Value<Uint8List> payload = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
              }) => FeatureSeriesTableCompanion(
                id: id,
                runId: runId,
                kind: kind,
                frameCount: frameCount,
                codecVersion: codecVersion,
                payload: payload,
                sha256: sha256,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int runId,
                required String kind,
                required int frameCount,
                required int codecVersion,
                required Uint8List payload,
                required String sha256,
              }) => FeatureSeriesTableCompanion.insert(
                id: id,
                runId: runId,
                kind: kind,
                frameCount: frameCount,
                codecVersion: codecVersion,
                payload: payload,
                sha256: sha256,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FeatureSeriesTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({runId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (runId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.runId,
                                referencedTable:
                                    $$FeatureSeriesTableTableReferences
                                        ._runIdTable(db),
                                referencedColumn:
                                    $$FeatureSeriesTableTableReferences
                                        ._runIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FeatureSeriesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FeatureSeriesTableTable,
      FeatureSeriesTableData,
      $$FeatureSeriesTableTableFilterComposer,
      $$FeatureSeriesTableTableOrderingComposer,
      $$FeatureSeriesTableTableAnnotationComposer,
      $$FeatureSeriesTableTableCreateCompanionBuilder,
      $$FeatureSeriesTableTableUpdateCompanionBuilder,
      (FeatureSeriesTableData, $$FeatureSeriesTableTableReferences),
      FeatureSeriesTableData,
      PrefetchHooks Function({bool runId})
    >;
typedef $$FeatureSeriesMetadataTableCreateCompanionBuilder =
    FeatureSeriesMetadataCompanion Function({
      Value<int> runId,
      required int frameCount,
      required int startSampleIndex,
      required int samplePeriodSamples,
      required String algorithmVersion,
      Value<int> featureSchemaVersion,
      Value<String?> sourceAudioSha256,
      Value<int?> sourceAudioByteLength,
    });
typedef $$FeatureSeriesMetadataTableUpdateCompanionBuilder =
    FeatureSeriesMetadataCompanion Function({
      Value<int> runId,
      Value<int> frameCount,
      Value<int> startSampleIndex,
      Value<int> samplePeriodSamples,
      Value<String> algorithmVersion,
      Value<int> featureSchemaVersion,
      Value<String?> sourceAudioSha256,
      Value<int?> sourceAudioByteLength,
    });

final class $$FeatureSeriesMetadataTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $FeatureSeriesMetadataTable,
          FeatureSeriesMetadataData
        > {
  $$FeatureSeriesMetadataTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AnalysisRunsTable _runIdTable(_$AppDatabase db) => db.analysisRuns
      .createAlias('feature_series_metadata__run_id__analysis_runs__id');

  $$AnalysisRunsTableProcessedTableManager get runId {
    final $_column = $_itemColumn<int>('run_id')!;

    final manager = $$AnalysisRunsTableTableManager(
      $_db,
      $_db.analysisRuns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_runIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FeatureSeriesMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $FeatureSeriesMetadataTable> {
  $$FeatureSeriesMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get frameCount => $composableBuilder(
    column: $table.frameCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startSampleIndex => $composableBuilder(
    column: $table.startSampleIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get samplePeriodSamples => $composableBuilder(
    column: $table.samplePeriodSamples,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get featureSchemaVersion => $composableBuilder(
    column: $table.featureSchemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceAudioSha256 => $composableBuilder(
    column: $table.sourceAudioSha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceAudioByteLength => $composableBuilder(
    column: $table.sourceAudioByteLength,
    builder: (column) => ColumnFilters(column),
  );

  $$AnalysisRunsTableFilterComposer get runId {
    final $$AnalysisRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.analysisRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnalysisRunsTableFilterComposer(
            $db: $db,
            $table: $db.analysisRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FeatureSeriesMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $FeatureSeriesMetadataTable> {
  $$FeatureSeriesMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get frameCount => $composableBuilder(
    column: $table.frameCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startSampleIndex => $composableBuilder(
    column: $table.startSampleIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get samplePeriodSamples => $composableBuilder(
    column: $table.samplePeriodSamples,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get featureSchemaVersion => $composableBuilder(
    column: $table.featureSchemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceAudioSha256 => $composableBuilder(
    column: $table.sourceAudioSha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceAudioByteLength => $composableBuilder(
    column: $table.sourceAudioByteLength,
    builder: (column) => ColumnOrderings(column),
  );

  $$AnalysisRunsTableOrderingComposer get runId {
    final $$AnalysisRunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.analysisRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnalysisRunsTableOrderingComposer(
            $db: $db,
            $table: $db.analysisRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FeatureSeriesMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $FeatureSeriesMetadataTable> {
  $$FeatureSeriesMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get frameCount => $composableBuilder(
    column: $table.frameCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startSampleIndex => $composableBuilder(
    column: $table.startSampleIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get samplePeriodSamples => $composableBuilder(
    column: $table.samplePeriodSamples,
    builder: (column) => column,
  );

  GeneratedColumn<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get featureSchemaVersion => $composableBuilder(
    column: $table.featureSchemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceAudioSha256 => $composableBuilder(
    column: $table.sourceAudioSha256,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sourceAudioByteLength => $composableBuilder(
    column: $table.sourceAudioByteLength,
    builder: (column) => column,
  );

  $$AnalysisRunsTableAnnotationComposer get runId {
    final $$AnalysisRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.analysisRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnalysisRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.analysisRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FeatureSeriesMetadataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FeatureSeriesMetadataTable,
          FeatureSeriesMetadataData,
          $$FeatureSeriesMetadataTableFilterComposer,
          $$FeatureSeriesMetadataTableOrderingComposer,
          $$FeatureSeriesMetadataTableAnnotationComposer,
          $$FeatureSeriesMetadataTableCreateCompanionBuilder,
          $$FeatureSeriesMetadataTableUpdateCompanionBuilder,
          (FeatureSeriesMetadataData, $$FeatureSeriesMetadataTableReferences),
          FeatureSeriesMetadataData,
          PrefetchHooks Function({bool runId})
        > {
  $$FeatureSeriesMetadataTableTableManager(
    _$AppDatabase db,
    $FeatureSeriesMetadataTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FeatureSeriesMetadataTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$FeatureSeriesMetadataTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$FeatureSeriesMetadataTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> runId = const Value.absent(),
                Value<int> frameCount = const Value.absent(),
                Value<int> startSampleIndex = const Value.absent(),
                Value<int> samplePeriodSamples = const Value.absent(),
                Value<String> algorithmVersion = const Value.absent(),
                Value<int> featureSchemaVersion = const Value.absent(),
                Value<String?> sourceAudioSha256 = const Value.absent(),
                Value<int?> sourceAudioByteLength = const Value.absent(),
              }) => FeatureSeriesMetadataCompanion(
                runId: runId,
                frameCount: frameCount,
                startSampleIndex: startSampleIndex,
                samplePeriodSamples: samplePeriodSamples,
                algorithmVersion: algorithmVersion,
                featureSchemaVersion: featureSchemaVersion,
                sourceAudioSha256: sourceAudioSha256,
                sourceAudioByteLength: sourceAudioByteLength,
              ),
          createCompanionCallback:
              ({
                Value<int> runId = const Value.absent(),
                required int frameCount,
                required int startSampleIndex,
                required int samplePeriodSamples,
                required String algorithmVersion,
                Value<int> featureSchemaVersion = const Value.absent(),
                Value<String?> sourceAudioSha256 = const Value.absent(),
                Value<int?> sourceAudioByteLength = const Value.absent(),
              }) => FeatureSeriesMetadataCompanion.insert(
                runId: runId,
                frameCount: frameCount,
                startSampleIndex: startSampleIndex,
                samplePeriodSamples: samplePeriodSamples,
                algorithmVersion: algorithmVersion,
                featureSchemaVersion: featureSchemaVersion,
                sourceAudioSha256: sourceAudioSha256,
                sourceAudioByteLength: sourceAudioByteLength,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FeatureSeriesMetadataTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({runId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (runId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.runId,
                                referencedTable:
                                    $$FeatureSeriesMetadataTableReferences
                                        ._runIdTable(db),
                                referencedColumn:
                                    $$FeatureSeriesMetadataTableReferences
                                        ._runIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FeatureSeriesMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FeatureSeriesMetadataTable,
      FeatureSeriesMetadataData,
      $$FeatureSeriesMetadataTableFilterComposer,
      $$FeatureSeriesMetadataTableOrderingComposer,
      $$FeatureSeriesMetadataTableAnnotationComposer,
      $$FeatureSeriesMetadataTableCreateCompanionBuilder,
      $$FeatureSeriesMetadataTableUpdateCompanionBuilder,
      (FeatureSeriesMetadataData, $$FeatureSeriesMetadataTableReferences),
      FeatureSeriesMetadataData,
      PrefetchHooks Function({bool runId})
    >;
typedef $$SavedVoiceComparisonPlansTableCreateCompanionBuilder =
    SavedVoiceComparisonPlansCompanion Function({
      required String id,
      required int schemaVersion,
      required String payloadJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$SavedVoiceComparisonPlansTableUpdateCompanionBuilder =
    SavedVoiceComparisonPlansCompanion Function({
      Value<String> id,
      Value<int> schemaVersion,
      Value<String> payloadJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SavedVoiceComparisonPlansTableFilterComposer
    extends Composer<_$AppDatabase, $SavedVoiceComparisonPlansTable> {
  $$SavedVoiceComparisonPlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SavedVoiceComparisonPlansTableOrderingComposer
    extends Composer<_$AppDatabase, $SavedVoiceComparisonPlansTable> {
  $$SavedVoiceComparisonPlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavedVoiceComparisonPlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $SavedVoiceComparisonPlansTable> {
  $$SavedVoiceComparisonPlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SavedVoiceComparisonPlansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SavedVoiceComparisonPlansTable,
          SavedVoiceComparisonPlan,
          $$SavedVoiceComparisonPlansTableFilterComposer,
          $$SavedVoiceComparisonPlansTableOrderingComposer,
          $$SavedVoiceComparisonPlansTableAnnotationComposer,
          $$SavedVoiceComparisonPlansTableCreateCompanionBuilder,
          $$SavedVoiceComparisonPlansTableUpdateCompanionBuilder,
          (
            SavedVoiceComparisonPlan,
            BaseReferences<
              _$AppDatabase,
              $SavedVoiceComparisonPlansTable,
              SavedVoiceComparisonPlan
            >,
          ),
          SavedVoiceComparisonPlan,
          PrefetchHooks Function()
        > {
  $$SavedVoiceComparisonPlansTableTableManager(
    _$AppDatabase db,
    $SavedVoiceComparisonPlansTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedVoiceComparisonPlansTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SavedVoiceComparisonPlansTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SavedVoiceComparisonPlansTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> schemaVersion = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedVoiceComparisonPlansCompanion(
                id: id,
                schemaVersion: schemaVersion,
                payloadJson: payloadJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int schemaVersion,
                required String payloadJson,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SavedVoiceComparisonPlansCompanion.insert(
                id: id,
                schemaVersion: schemaVersion,
                payloadJson: payloadJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SavedVoiceComparisonPlansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SavedVoiceComparisonPlansTable,
      SavedVoiceComparisonPlan,
      $$SavedVoiceComparisonPlansTableFilterComposer,
      $$SavedVoiceComparisonPlansTableOrderingComposer,
      $$SavedVoiceComparisonPlansTableAnnotationComposer,
      $$SavedVoiceComparisonPlansTableCreateCompanionBuilder,
      $$SavedVoiceComparisonPlansTableUpdateCompanionBuilder,
      (
        SavedVoiceComparisonPlan,
        BaseReferences<
          _$AppDatabase,
          $SavedVoiceComparisonPlansTable,
          SavedVoiceComparisonPlan
        >,
      ),
      SavedVoiceComparisonPlan,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PracticeSessionsTableTableManager get practiceSessions =>
      $$PracticeSessionsTableTableManager(_db, _db.practiceSessions);
  $$RecordingsTableTableManager get recordings =>
      $$RecordingsTableTableManager(_db, _db.recordings);
  $$AnalysisRunsTableTableManager get analysisRuns =>
      $$AnalysisRunsTableTableManager(_db, _db.analysisRuns);
  $$FeatureSeriesTableTableTableManager get featureSeriesTable =>
      $$FeatureSeriesTableTableTableManager(_db, _db.featureSeriesTable);
  $$FeatureSeriesMetadataTableTableManager get featureSeriesMetadata =>
      $$FeatureSeriesMetadataTableTableManager(_db, _db.featureSeriesMetadata);
  $$SavedVoiceComparisonPlansTableTableManager get savedVoiceComparisonPlans =>
      $$SavedVoiceComparisonPlansTableTableManager(
        _db,
        _db.savedVoiceComparisonPlans,
      );
}
