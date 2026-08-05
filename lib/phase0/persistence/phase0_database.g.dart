// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'phase0_database.dart';

// ignore_for_file: type=lint
class $AnalysisRunsTable extends AnalysisRuns
    with TableInfo<$AnalysisRunsTable, AnalysisRunRow> {
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
  static const VerificationMeta _sampleRateMeta = const VerificationMeta(
    'sampleRate',
  );
  @override
  late final GeneratedColumn<int> sampleRate = GeneratedColumn<int>(
    'sample_rate',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _frameRateMilliHzMeta = const VerificationMeta(
    'frameRateMilliHz',
  );
  @override
  late final GeneratedColumn<int> frameRateMilliHz = GeneratedColumn<int>(
    'frame_rate_milli_hz',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    sampleRate,
    frameRateMilliHz,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'analysis_runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<AnalysisRunRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('sample_rate')) {
      context.handle(
        _sampleRateMeta,
        sampleRate.isAcceptableOrUnknown(data['sample_rate']!, _sampleRateMeta),
      );
    } else if (isInserting) {
      context.missing(_sampleRateMeta);
    }
    if (data.containsKey('frame_rate_milli_hz')) {
      context.handle(
        _frameRateMilliHzMeta,
        frameRateMilliHz.isAcceptableOrUnknown(
          data['frame_rate_milli_hz']!,
          _frameRateMilliHzMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_frameRateMilliHzMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AnalysisRunRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnalysisRunRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      sampleRate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sample_rate'],
      )!,
      frameRateMilliHz: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}frame_rate_milli_hz'],
      )!,
    );
  }

  @override
  $AnalysisRunsTable createAlias(String alias) {
    return $AnalysisRunsTable(attachedDatabase, alias);
  }
}

class AnalysisRunRow extends DataClass implements Insertable<AnalysisRunRow> {
  final int id;
  final DateTime createdAt;
  final int sampleRate;
  final int frameRateMilliHz;
  const AnalysisRunRow({
    required this.id,
    required this.createdAt,
    required this.sampleRate,
    required this.frameRateMilliHz,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['sample_rate'] = Variable<int>(sampleRate);
    map['frame_rate_milli_hz'] = Variable<int>(frameRateMilliHz);
    return map;
  }

  AnalysisRunsCompanion toCompanion(bool nullToAbsent) {
    return AnalysisRunsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      sampleRate: Value(sampleRate),
      frameRateMilliHz: Value(frameRateMilliHz),
    );
  }

  factory AnalysisRunRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnalysisRunRow(
      id: serializer.fromJson<int>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      sampleRate: serializer.fromJson<int>(json['sampleRate']),
      frameRateMilliHz: serializer.fromJson<int>(json['frameRateMilliHz']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'sampleRate': serializer.toJson<int>(sampleRate),
      'frameRateMilliHz': serializer.toJson<int>(frameRateMilliHz),
    };
  }

  AnalysisRunRow copyWith({
    int? id,
    DateTime? createdAt,
    int? sampleRate,
    int? frameRateMilliHz,
  }) => AnalysisRunRow(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    sampleRate: sampleRate ?? this.sampleRate,
    frameRateMilliHz: frameRateMilliHz ?? this.frameRateMilliHz,
  );
  AnalysisRunRow copyWithCompanion(AnalysisRunsCompanion data) {
    return AnalysisRunRow(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      sampleRate: data.sampleRate.present
          ? data.sampleRate.value
          : this.sampleRate,
      frameRateMilliHz: data.frameRateMilliHz.present
          ? data.frameRateMilliHz.value
          : this.frameRateMilliHz,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnalysisRunRow(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('frameRateMilliHz: $frameRateMilliHz')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, createdAt, sampleRate, frameRateMilliHz);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnalysisRunRow &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.sampleRate == this.sampleRate &&
          other.frameRateMilliHz == this.frameRateMilliHz);
}

class AnalysisRunsCompanion extends UpdateCompanion<AnalysisRunRow> {
  final Value<int> id;
  final Value<DateTime> createdAt;
  final Value<int> sampleRate;
  final Value<int> frameRateMilliHz;
  const AnalysisRunsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.sampleRate = const Value.absent(),
    this.frameRateMilliHz = const Value.absent(),
  });
  AnalysisRunsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime createdAt,
    required int sampleRate,
    required int frameRateMilliHz,
  }) : createdAt = Value(createdAt),
       sampleRate = Value(sampleRate),
       frameRateMilliHz = Value(frameRateMilliHz);
  static Insertable<AnalysisRunRow> custom({
    Expression<int>? id,
    Expression<DateTime>? createdAt,
    Expression<int>? sampleRate,
    Expression<int>? frameRateMilliHz,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (sampleRate != null) 'sample_rate': sampleRate,
      if (frameRateMilliHz != null) 'frame_rate_milli_hz': frameRateMilliHz,
    });
  }

  AnalysisRunsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? createdAt,
    Value<int>? sampleRate,
    Value<int>? frameRateMilliHz,
  }) {
    return AnalysisRunsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      sampleRate: sampleRate ?? this.sampleRate,
      frameRateMilliHz: frameRateMilliHz ?? this.frameRateMilliHz,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (sampleRate.present) {
      map['sample_rate'] = Variable<int>(sampleRate.value);
    }
    if (frameRateMilliHz.present) {
      map['frame_rate_milli_hz'] = Variable<int>(frameRateMilliHz.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnalysisRunsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('frameRateMilliHz: $frameRateMilliHz')
          ..write(')'))
        .toString();
  }
}

class $FeatureSeriesTable extends FeatureSeries
    with TableInfo<$FeatureSeriesTable, FeatureSeriesRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FeatureSeriesTable(this.attachedDatabase, [this._alias]);
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
    Insertable<FeatureSeriesRow> instance, {
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
  FeatureSeriesRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FeatureSeriesRow(
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
  $FeatureSeriesTable createAlias(String alias) {
    return $FeatureSeriesTable(attachedDatabase, alias);
  }
}

class FeatureSeriesRow extends DataClass
    implements Insertable<FeatureSeriesRow> {
  final int id;
  final int runId;
  final String kind;
  final int frameCount;
  final int codecVersion;
  final Uint8List payload;
  final String sha256;
  const FeatureSeriesRow({
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

  FeatureSeriesCompanion toCompanion(bool nullToAbsent) {
    return FeatureSeriesCompanion(
      id: Value(id),
      runId: Value(runId),
      kind: Value(kind),
      frameCount: Value(frameCount),
      codecVersion: Value(codecVersion),
      payload: Value(payload),
      sha256: Value(sha256),
    );
  }

  factory FeatureSeriesRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FeatureSeriesRow(
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

  FeatureSeriesRow copyWith({
    int? id,
    int? runId,
    String? kind,
    int? frameCount,
    int? codecVersion,
    Uint8List? payload,
    String? sha256,
  }) => FeatureSeriesRow(
    id: id ?? this.id,
    runId: runId ?? this.runId,
    kind: kind ?? this.kind,
    frameCount: frameCount ?? this.frameCount,
    codecVersion: codecVersion ?? this.codecVersion,
    payload: payload ?? this.payload,
    sha256: sha256 ?? this.sha256,
  );
  FeatureSeriesRow copyWithCompanion(FeatureSeriesCompanion data) {
    return FeatureSeriesRow(
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
    return (StringBuffer('FeatureSeriesRow(')
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
      (other is FeatureSeriesRow &&
          other.id == this.id &&
          other.runId == this.runId &&
          other.kind == this.kind &&
          other.frameCount == this.frameCount &&
          other.codecVersion == this.codecVersion &&
          $driftBlobEquality.equals(other.payload, this.payload) &&
          other.sha256 == this.sha256);
}

class FeatureSeriesCompanion extends UpdateCompanion<FeatureSeriesRow> {
  final Value<int> id;
  final Value<int> runId;
  final Value<String> kind;
  final Value<int> frameCount;
  final Value<int> codecVersion;
  final Value<Uint8List> payload;
  final Value<String> sha256;
  const FeatureSeriesCompanion({
    this.id = const Value.absent(),
    this.runId = const Value.absent(),
    this.kind = const Value.absent(),
    this.frameCount = const Value.absent(),
    this.codecVersion = const Value.absent(),
    this.payload = const Value.absent(),
    this.sha256 = const Value.absent(),
  });
  FeatureSeriesCompanion.insert({
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
  static Insertable<FeatureSeriesRow> custom({
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

  FeatureSeriesCompanion copyWith({
    Value<int>? id,
    Value<int>? runId,
    Value<String>? kind,
    Value<int>? frameCount,
    Value<int>? codecVersion,
    Value<Uint8List>? payload,
    Value<String>? sha256,
  }) {
    return FeatureSeriesCompanion(
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
    return (StringBuffer('FeatureSeriesCompanion(')
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

abstract class _$Phase0Database extends GeneratedDatabase {
  _$Phase0Database(QueryExecutor e) : super(e);
  $Phase0DatabaseManager get managers => $Phase0DatabaseManager(this);
  late final $AnalysisRunsTable analysisRuns = $AnalysisRunsTable(this);
  late final $FeatureSeriesTable featureSeries = $FeatureSeriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    analysisRuns,
    featureSeries,
  ];
}

typedef $$AnalysisRunsTableCreateCompanionBuilder =
    AnalysisRunsCompanion Function({
      Value<int> id,
      required DateTime createdAt,
      required int sampleRate,
      required int frameRateMilliHz,
    });
typedef $$AnalysisRunsTableUpdateCompanionBuilder =
    AnalysisRunsCompanion Function({
      Value<int> id,
      Value<DateTime> createdAt,
      Value<int> sampleRate,
      Value<int> frameRateMilliHz,
    });

final class $$AnalysisRunsTableReferences
    extends
        BaseReferences<_$Phase0Database, $AnalysisRunsTable, AnalysisRunRow> {
  $$AnalysisRunsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FeatureSeriesTable, List<FeatureSeriesRow>>
  _featureSeriesRefsTable(_$Phase0Database db) => MultiTypedResultKey.fromTable(
    db.featureSeries,
    aliasName: 'analysis_runs__id__feature_series__run_id',
  );

  $$FeatureSeriesTableProcessedTableManager get featureSeriesRefs {
    final manager = $$FeatureSeriesTableTableManager(
      $_db,
      $_db.featureSeries,
    ).filter((f) => f.runId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_featureSeriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AnalysisRunsTableFilterComposer
    extends Composer<_$Phase0Database, $AnalysisRunsTable> {
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

  ColumnFilters<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get frameRateMilliHz => $composableBuilder(
    column: $table.frameRateMilliHz,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> featureSeriesRefs(
    Expression<bool> Function($$FeatureSeriesTableFilterComposer f) f,
  ) {
    final $$FeatureSeriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.featureSeries,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FeatureSeriesTableFilterComposer(
            $db: $db,
            $table: $db.featureSeries,
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
    extends Composer<_$Phase0Database, $AnalysisRunsTable> {
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

  ColumnOrderings<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get frameRateMilliHz => $composableBuilder(
    column: $table.frameRateMilliHz,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AnalysisRunsTableAnnotationComposer
    extends Composer<_$Phase0Database, $AnalysisRunsTable> {
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

  GeneratedColumn<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get frameRateMilliHz => $composableBuilder(
    column: $table.frameRateMilliHz,
    builder: (column) => column,
  );

  Expression<T> featureSeriesRefs<T extends Object>(
    Expression<T> Function($$FeatureSeriesTableAnnotationComposer a) f,
  ) {
    final $$FeatureSeriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.featureSeries,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FeatureSeriesTableAnnotationComposer(
            $db: $db,
            $table: $db.featureSeries,
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
          _$Phase0Database,
          $AnalysisRunsTable,
          AnalysisRunRow,
          $$AnalysisRunsTableFilterComposer,
          $$AnalysisRunsTableOrderingComposer,
          $$AnalysisRunsTableAnnotationComposer,
          $$AnalysisRunsTableCreateCompanionBuilder,
          $$AnalysisRunsTableUpdateCompanionBuilder,
          (AnalysisRunRow, $$AnalysisRunsTableReferences),
          AnalysisRunRow,
          PrefetchHooks Function({bool featureSeriesRefs})
        > {
  $$AnalysisRunsTableTableManager(_$Phase0Database db, $AnalysisRunsTable table)
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
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> sampleRate = const Value.absent(),
                Value<int> frameRateMilliHz = const Value.absent(),
              }) => AnalysisRunsCompanion(
                id: id,
                createdAt: createdAt,
                sampleRate: sampleRate,
                frameRateMilliHz: frameRateMilliHz,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime createdAt,
                required int sampleRate,
                required int frameRateMilliHz,
              }) => AnalysisRunsCompanion.insert(
                id: id,
                createdAt: createdAt,
                sampleRate: sampleRate,
                frameRateMilliHz: frameRateMilliHz,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AnalysisRunsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({featureSeriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (featureSeriesRefs) db.featureSeries,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (featureSeriesRefs)
                    await $_getPrefetchedData<
                      AnalysisRunRow,
                      $AnalysisRunsTable,
                      FeatureSeriesRow
                    >(
                      currentTable: table,
                      referencedTable: $$AnalysisRunsTableReferences
                          ._featureSeriesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$AnalysisRunsTableReferences(
                            db,
                            table,
                            p0,
                          ).featureSeriesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.runId == item.id),
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
      _$Phase0Database,
      $AnalysisRunsTable,
      AnalysisRunRow,
      $$AnalysisRunsTableFilterComposer,
      $$AnalysisRunsTableOrderingComposer,
      $$AnalysisRunsTableAnnotationComposer,
      $$AnalysisRunsTableCreateCompanionBuilder,
      $$AnalysisRunsTableUpdateCompanionBuilder,
      (AnalysisRunRow, $$AnalysisRunsTableReferences),
      AnalysisRunRow,
      PrefetchHooks Function({bool featureSeriesRefs})
    >;
typedef $$FeatureSeriesTableCreateCompanionBuilder =
    FeatureSeriesCompanion Function({
      Value<int> id,
      required int runId,
      required String kind,
      required int frameCount,
      required int codecVersion,
      required Uint8List payload,
      required String sha256,
    });
typedef $$FeatureSeriesTableUpdateCompanionBuilder =
    FeatureSeriesCompanion Function({
      Value<int> id,
      Value<int> runId,
      Value<String> kind,
      Value<int> frameCount,
      Value<int> codecVersion,
      Value<Uint8List> payload,
      Value<String> sha256,
    });

final class $$FeatureSeriesTableReferences
    extends
        BaseReferences<
          _$Phase0Database,
          $FeatureSeriesTable,
          FeatureSeriesRow
        > {
  $$FeatureSeriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AnalysisRunsTable _runIdTable(_$Phase0Database db) =>
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

class $$FeatureSeriesTableFilterComposer
    extends Composer<_$Phase0Database, $FeatureSeriesTable> {
  $$FeatureSeriesTableFilterComposer({
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

class $$FeatureSeriesTableOrderingComposer
    extends Composer<_$Phase0Database, $FeatureSeriesTable> {
  $$FeatureSeriesTableOrderingComposer({
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

class $$FeatureSeriesTableAnnotationComposer
    extends Composer<_$Phase0Database, $FeatureSeriesTable> {
  $$FeatureSeriesTableAnnotationComposer({
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

class $$FeatureSeriesTableTableManager
    extends
        RootTableManager<
          _$Phase0Database,
          $FeatureSeriesTable,
          FeatureSeriesRow,
          $$FeatureSeriesTableFilterComposer,
          $$FeatureSeriesTableOrderingComposer,
          $$FeatureSeriesTableAnnotationComposer,
          $$FeatureSeriesTableCreateCompanionBuilder,
          $$FeatureSeriesTableUpdateCompanionBuilder,
          (FeatureSeriesRow, $$FeatureSeriesTableReferences),
          FeatureSeriesRow,
          PrefetchHooks Function({bool runId})
        > {
  $$FeatureSeriesTableTableManager(
    _$Phase0Database db,
    $FeatureSeriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FeatureSeriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FeatureSeriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FeatureSeriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> runId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> frameCount = const Value.absent(),
                Value<int> codecVersion = const Value.absent(),
                Value<Uint8List> payload = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
              }) => FeatureSeriesCompanion(
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
              }) => FeatureSeriesCompanion.insert(
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
                  $$FeatureSeriesTableReferences(db, table, e),
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
                                referencedTable: $$FeatureSeriesTableReferences
                                    ._runIdTable(db),
                                referencedColumn: $$FeatureSeriesTableReferences
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

typedef $$FeatureSeriesTableProcessedTableManager =
    ProcessedTableManager<
      _$Phase0Database,
      $FeatureSeriesTable,
      FeatureSeriesRow,
      $$FeatureSeriesTableFilterComposer,
      $$FeatureSeriesTableOrderingComposer,
      $$FeatureSeriesTableAnnotationComposer,
      $$FeatureSeriesTableCreateCompanionBuilder,
      $$FeatureSeriesTableUpdateCompanionBuilder,
      (FeatureSeriesRow, $$FeatureSeriesTableReferences),
      FeatureSeriesRow,
      PrefetchHooks Function({bool runId})
    >;

class $Phase0DatabaseManager {
  final _$Phase0Database _db;
  $Phase0DatabaseManager(this._db);
  $$AnalysisRunsTableTableManager get analysisRuns =>
      $$AnalysisRunsTableTableManager(_db, _db.analysisRuns);
  $$FeatureSeriesTableTableManager get featureSeries =>
      $$FeatureSeriesTableTableManager(_db, _db.featureSeries);
}
