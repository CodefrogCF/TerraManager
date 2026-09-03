// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MediaAssetsTable extends MediaAssets
    with TableInfo<$MediaAssetsTable, MediaAsset> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaAssetsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<Uint8List> data = GeneratedColumn<Uint8List>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fileName,
    mimeType,
    data,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_assets';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaAsset> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MediaAsset map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaAsset(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}data'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MediaAssetsTable createAlias(String alias) {
    return $MediaAssetsTable(attachedDatabase, alias);
  }
}

class MediaAsset extends DataClass implements Insertable<MediaAsset> {
  final int id;
  final String fileName;
  final String mimeType;
  final Uint8List data;
  final DateTime createdAt;
  final DateTime updatedAt;
  const MediaAsset({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.data,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['file_name'] = Variable<String>(fileName);
    map['mime_type'] = Variable<String>(mimeType);
    map['data'] = Variable<Uint8List>(data);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MediaAssetsCompanion toCompanion(bool nullToAbsent) {
    return MediaAssetsCompanion(
      id: Value(id),
      fileName: Value(fileName),
      mimeType: Value(mimeType),
      data: Value(data),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MediaAsset.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaAsset(
      id: serializer.fromJson<int>(json['id']),
      fileName: serializer.fromJson<String>(json['fileName']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      data: serializer.fromJson<Uint8List>(json['data']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fileName': serializer.toJson<String>(fileName),
      'mimeType': serializer.toJson<String>(mimeType),
      'data': serializer.toJson<Uint8List>(data),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MediaAsset copyWith({
    int? id,
    String? fileName,
    String? mimeType,
    Uint8List? data,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => MediaAsset(
    id: id ?? this.id,
    fileName: fileName ?? this.fileName,
    mimeType: mimeType ?? this.mimeType,
    data: data ?? this.data,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MediaAsset copyWithCompanion(MediaAssetsCompanion data) {
    return MediaAsset(
      id: data.id.present ? data.id.value : this.id,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      data: data.data.present ? data.data.value : this.data,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaAsset(')
          ..write('id: $id, ')
          ..write('fileName: $fileName, ')
          ..write('mimeType: $mimeType, ')
          ..write('data: $data, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    fileName,
    mimeType,
    $driftBlobEquality.hash(data),
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaAsset &&
          other.id == this.id &&
          other.fileName == this.fileName &&
          other.mimeType == this.mimeType &&
          $driftBlobEquality.equals(other.data, this.data) &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MediaAssetsCompanion extends UpdateCompanion<MediaAsset> {
  final Value<int> id;
  final Value<String> fileName;
  final Value<String> mimeType;
  final Value<Uint8List> data;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const MediaAssetsCompanion({
    this.id = const Value.absent(),
    this.fileName = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.data = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  MediaAssetsCompanion.insert({
    this.id = const Value.absent(),
    required String fileName,
    required String mimeType,
    required Uint8List data,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : fileName = Value(fileName),
       mimeType = Value(mimeType),
       data = Value(data);
  static Insertable<MediaAsset> custom({
    Expression<int>? id,
    Expression<String>? fileName,
    Expression<String>? mimeType,
    Expression<Uint8List>? data,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fileName != null) 'file_name': fileName,
      if (mimeType != null) 'mime_type': mimeType,
      if (data != null) 'data': data,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  MediaAssetsCompanion copyWith({
    Value<int>? id,
    Value<String>? fileName,
    Value<String>? mimeType,
    Value<Uint8List>? data,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return MediaAssetsCompanion(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (data.present) {
      map['data'] = Variable<Uint8List>(data.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaAssetsCompanion(')
          ..write('id: $id, ')
          ..write('fileName: $fileName, ')
          ..write('mimeType: $mimeType, ')
          ..write('data: $data, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $BoxesTable extends Boxes with TableInfo<$BoxesTable, Box> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BoxesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _qrIdMeta = const VerificationMeta('qrId');
  @override
  late final GeneratedColumn<String> qrId = GeneratedColumn<String>(
    'qr_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _widthCmMeta = const VerificationMeta(
    'widthCm',
  );
  @override
  late final GeneratedColumn<double> widthCm = GeneratedColumn<double>(
    'width_cm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightCmMeta = const VerificationMeta(
    'heightCm',
  );
  @override
  late final GeneratedColumn<double> heightCm = GeneratedColumn<double>(
    'height_cm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _depthCmMeta = const VerificationMeta(
    'depthCm',
  );
  @override
  late final GeneratedColumn<double> depthCm = GeneratedColumn<double>(
    'depth_cm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pictureMediaIdMeta = const VerificationMeta(
    'pictureMediaId',
  );
  @override
  late final GeneratedColumn<int> pictureMediaId = GeneratedColumn<int>(
    'picture_media_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES media_assets (id)',
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    qrId,
    widthCm,
    heightCm,
    depthCm,
    pictureMediaId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'boxes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Box> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('qr_id')) {
      context.handle(
        _qrIdMeta,
        qrId.isAcceptableOrUnknown(data['qr_id']!, _qrIdMeta),
      );
    } else if (isInserting) {
      context.missing(_qrIdMeta);
    }
    if (data.containsKey('width_cm')) {
      context.handle(
        _widthCmMeta,
        widthCm.isAcceptableOrUnknown(data['width_cm']!, _widthCmMeta),
      );
    }
    if (data.containsKey('height_cm')) {
      context.handle(
        _heightCmMeta,
        heightCm.isAcceptableOrUnknown(data['height_cm']!, _heightCmMeta),
      );
    }
    if (data.containsKey('depth_cm')) {
      context.handle(
        _depthCmMeta,
        depthCm.isAcceptableOrUnknown(data['depth_cm']!, _depthCmMeta),
      );
    }
    if (data.containsKey('picture_media_id')) {
      context.handle(
        _pictureMediaIdMeta,
        pictureMediaId.isAcceptableOrUnknown(
          data['picture_media_id']!,
          _pictureMediaIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Box map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Box(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      qrId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}qr_id'],
      )!,
      widthCm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}width_cm'],
      ),
      heightCm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}height_cm'],
      ),
      depthCm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}depth_cm'],
      ),
      pictureMediaId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}picture_media_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $BoxesTable createAlias(String alias) {
    return $BoxesTable(attachedDatabase, alias);
  }
}

class Box extends DataClass implements Insertable<Box> {
  final int id;
  final String qrId;
  final double? widthCm;
  final double? heightCm;
  final double? depthCm;
  final int? pictureMediaId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Box({
    required this.id,
    required this.qrId,
    this.widthCm,
    this.heightCm,
    this.depthCm,
    this.pictureMediaId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['qr_id'] = Variable<String>(qrId);
    if (!nullToAbsent || widthCm != null) {
      map['width_cm'] = Variable<double>(widthCm);
    }
    if (!nullToAbsent || heightCm != null) {
      map['height_cm'] = Variable<double>(heightCm);
    }
    if (!nullToAbsent || depthCm != null) {
      map['depth_cm'] = Variable<double>(depthCm);
    }
    if (!nullToAbsent || pictureMediaId != null) {
      map['picture_media_id'] = Variable<int>(pictureMediaId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BoxesCompanion toCompanion(bool nullToAbsent) {
    return BoxesCompanion(
      id: Value(id),
      qrId: Value(qrId),
      widthCm: widthCm == null && nullToAbsent
          ? const Value.absent()
          : Value(widthCm),
      heightCm: heightCm == null && nullToAbsent
          ? const Value.absent()
          : Value(heightCm),
      depthCm: depthCm == null && nullToAbsent
          ? const Value.absent()
          : Value(depthCm),
      pictureMediaId: pictureMediaId == null && nullToAbsent
          ? const Value.absent()
          : Value(pictureMediaId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Box.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Box(
      id: serializer.fromJson<int>(json['id']),
      qrId: serializer.fromJson<String>(json['qrId']),
      widthCm: serializer.fromJson<double?>(json['widthCm']),
      heightCm: serializer.fromJson<double?>(json['heightCm']),
      depthCm: serializer.fromJson<double?>(json['depthCm']),
      pictureMediaId: serializer.fromJson<int?>(json['pictureMediaId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'qrId': serializer.toJson<String>(qrId),
      'widthCm': serializer.toJson<double?>(widthCm),
      'heightCm': serializer.toJson<double?>(heightCm),
      'depthCm': serializer.toJson<double?>(depthCm),
      'pictureMediaId': serializer.toJson<int?>(pictureMediaId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Box copyWith({
    int? id,
    String? qrId,
    Value<double?> widthCm = const Value.absent(),
    Value<double?> heightCm = const Value.absent(),
    Value<double?> depthCm = const Value.absent(),
    Value<int?> pictureMediaId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Box(
    id: id ?? this.id,
    qrId: qrId ?? this.qrId,
    widthCm: widthCm.present ? widthCm.value : this.widthCm,
    heightCm: heightCm.present ? heightCm.value : this.heightCm,
    depthCm: depthCm.present ? depthCm.value : this.depthCm,
    pictureMediaId: pictureMediaId.present
        ? pictureMediaId.value
        : this.pictureMediaId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Box copyWithCompanion(BoxesCompanion data) {
    return Box(
      id: data.id.present ? data.id.value : this.id,
      qrId: data.qrId.present ? data.qrId.value : this.qrId,
      widthCm: data.widthCm.present ? data.widthCm.value : this.widthCm,
      heightCm: data.heightCm.present ? data.heightCm.value : this.heightCm,
      depthCm: data.depthCm.present ? data.depthCm.value : this.depthCm,
      pictureMediaId: data.pictureMediaId.present
          ? data.pictureMediaId.value
          : this.pictureMediaId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Box(')
          ..write('id: $id, ')
          ..write('qrId: $qrId, ')
          ..write('widthCm: $widthCm, ')
          ..write('heightCm: $heightCm, ')
          ..write('depthCm: $depthCm, ')
          ..write('pictureMediaId: $pictureMediaId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    qrId,
    widthCm,
    heightCm,
    depthCm,
    pictureMediaId,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Box &&
          other.id == this.id &&
          other.qrId == this.qrId &&
          other.widthCm == this.widthCm &&
          other.heightCm == this.heightCm &&
          other.depthCm == this.depthCm &&
          other.pictureMediaId == this.pictureMediaId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BoxesCompanion extends UpdateCompanion<Box> {
  final Value<int> id;
  final Value<String> qrId;
  final Value<double?> widthCm;
  final Value<double?> heightCm;
  final Value<double?> depthCm;
  final Value<int?> pictureMediaId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const BoxesCompanion({
    this.id = const Value.absent(),
    this.qrId = const Value.absent(),
    this.widthCm = const Value.absent(),
    this.heightCm = const Value.absent(),
    this.depthCm = const Value.absent(),
    this.pictureMediaId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  BoxesCompanion.insert({
    this.id = const Value.absent(),
    required String qrId,
    this.widthCm = const Value.absent(),
    this.heightCm = const Value.absent(),
    this.depthCm = const Value.absent(),
    this.pictureMediaId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : qrId = Value(qrId);
  static Insertable<Box> custom({
    Expression<int>? id,
    Expression<String>? qrId,
    Expression<double>? widthCm,
    Expression<double>? heightCm,
    Expression<double>? depthCm,
    Expression<int>? pictureMediaId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (qrId != null) 'qr_id': qrId,
      if (widthCm != null) 'width_cm': widthCm,
      if (heightCm != null) 'height_cm': heightCm,
      if (depthCm != null) 'depth_cm': depthCm,
      if (pictureMediaId != null) 'picture_media_id': pictureMediaId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  BoxesCompanion copyWith({
    Value<int>? id,
    Value<String>? qrId,
    Value<double?>? widthCm,
    Value<double?>? heightCm,
    Value<double?>? depthCm,
    Value<int?>? pictureMediaId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return BoxesCompanion(
      id: id ?? this.id,
      qrId: qrId ?? this.qrId,
      widthCm: widthCm ?? this.widthCm,
      heightCm: heightCm ?? this.heightCm,
      depthCm: depthCm ?? this.depthCm,
      pictureMediaId: pictureMediaId ?? this.pictureMediaId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (qrId.present) {
      map['qr_id'] = Variable<String>(qrId.value);
    }
    if (widthCm.present) {
      map['width_cm'] = Variable<double>(widthCm.value);
    }
    if (heightCm.present) {
      map['height_cm'] = Variable<double>(heightCm.value);
    }
    if (depthCm.present) {
      map['depth_cm'] = Variable<double>(depthCm.value);
    }
    if (pictureMediaId.present) {
      map['picture_media_id'] = Variable<int>(pictureMediaId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BoxesCompanion(')
          ..write('id: $id, ')
          ..write('qrId: $qrId, ')
          ..write('widthCm: $widthCm, ')
          ..write('heightCm: $heightCm, ')
          ..write('depthCm: $depthCm, ')
          ..write('pictureMediaId: $pictureMediaId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $AnimalsTable extends Animals with TableInfo<$AnimalsTable, Animal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnimalsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _boxIdMeta = const VerificationMeta('boxId');
  @override
  late final GeneratedColumn<int> boxId = GeneratedColumn<int>(
    'box_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES boxes (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<AnimalStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('active'),
      ).withConverter<AnimalStatus>($AnimalsTable.$converterstatus);
  static const VerificationMeta _commonNameMeta = const VerificationMeta(
    'commonName',
  );
  @override
  late final GeneratedColumn<String> commonName = GeneratedColumn<String>(
    'common_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latinNameMeta = const VerificationMeta(
    'latinName',
  );
  @override
  late final GeneratedColumn<String> latinName = GeneratedColumn<String>(
    'latin_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Sex?, String> sex =
      GeneratedColumn<String>(
        'sex',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<Sex?>($AnimalsTable.$convertersexn);
  static const VerificationMeta _birthDateMeta = const VerificationMeta(
    'birthDate',
  );
  @override
  late final GeneratedColumn<DateTime> birthDate = GeneratedColumn<DateTime>(
    'birth_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<BirthDateAccuracy?, String>
  birthDateAccuracy =
      GeneratedColumn<String>(
        'birth_date_accuracy',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<BirthDateAccuracy?>(
        $AnimalsTable.$converterbirthDateAccuracyn,
      );
  static const VerificationMeta _tempMinMeta = const VerificationMeta(
    'tempMin',
  );
  @override
  late final GeneratedColumn<double> tempMin = GeneratedColumn<double>(
    'temp_min',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tempMaxMeta = const VerificationMeta(
    'tempMax',
  );
  @override
  late final GeneratedColumn<double> tempMax = GeneratedColumn<double>(
    'temp_max',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _humidityMinMeta = const VerificationMeta(
    'humidityMin',
  );
  @override
  late final GeneratedColumn<double> humidityMin = GeneratedColumn<double>(
    'humidity_min',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _humidityMaxMeta = const VerificationMeta(
    'humidityMax',
  );
  @override
  late final GeneratedColumn<double> humidityMax = GeneratedColumn<double>(
    'humidity_max',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _picturePathMeta = const VerificationMeta(
    'picturePath',
  );
  @override
  late final GeneratedColumn<String> picturePath = GeneratedColumn<String>(
    'picture_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pictureMediaIdMeta = const VerificationMeta(
    'pictureMediaId',
  );
  @override
  late final GeneratedColumn<int> pictureMediaId = GeneratedColumn<int>(
    'picture_media_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES media_assets (id)',
    ),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AnimalArchiveReason?, String>
  archiveReason = GeneratedColumn<String>(
    'archive_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<AnimalArchiveReason?>($AnimalsTable.$converterarchiveReasonn);
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archiveNotesMeta = const VerificationMeta(
    'archiveNotes',
  );
  @override
  late final GeneratedColumn<String> archiveNotes = GeneratedColumn<String>(
    'archive_notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    boxId,
    status,
    commonName,
    latinName,
    sex,
    birthDate,
    birthDateAccuracy,
    tempMin,
    tempMax,
    humidityMin,
    humidityMax,
    picturePath,
    pictureMediaId,
    notes,
    archiveReason,
    archivedAt,
    archiveNotes,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'animals';
  @override
  VerificationContext validateIntegrity(
    Insertable<Animal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('box_id')) {
      context.handle(
        _boxIdMeta,
        boxId.isAcceptableOrUnknown(data['box_id']!, _boxIdMeta),
      );
    }
    if (data.containsKey('common_name')) {
      context.handle(
        _commonNameMeta,
        commonName.isAcceptableOrUnknown(data['common_name']!, _commonNameMeta),
      );
    } else if (isInserting) {
      context.missing(_commonNameMeta);
    }
    if (data.containsKey('latin_name')) {
      context.handle(
        _latinNameMeta,
        latinName.isAcceptableOrUnknown(data['latin_name']!, _latinNameMeta),
      );
    } else if (isInserting) {
      context.missing(_latinNameMeta);
    }
    if (data.containsKey('birth_date')) {
      context.handle(
        _birthDateMeta,
        birthDate.isAcceptableOrUnknown(data['birth_date']!, _birthDateMeta),
      );
    }
    if (data.containsKey('temp_min')) {
      context.handle(
        _tempMinMeta,
        tempMin.isAcceptableOrUnknown(data['temp_min']!, _tempMinMeta),
      );
    } else if (isInserting) {
      context.missing(_tempMinMeta);
    }
    if (data.containsKey('temp_max')) {
      context.handle(
        _tempMaxMeta,
        tempMax.isAcceptableOrUnknown(data['temp_max']!, _tempMaxMeta),
      );
    } else if (isInserting) {
      context.missing(_tempMaxMeta);
    }
    if (data.containsKey('humidity_min')) {
      context.handle(
        _humidityMinMeta,
        humidityMin.isAcceptableOrUnknown(
          data['humidity_min']!,
          _humidityMinMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_humidityMinMeta);
    }
    if (data.containsKey('humidity_max')) {
      context.handle(
        _humidityMaxMeta,
        humidityMax.isAcceptableOrUnknown(
          data['humidity_max']!,
          _humidityMaxMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_humidityMaxMeta);
    }
    if (data.containsKey('picture_path')) {
      context.handle(
        _picturePathMeta,
        picturePath.isAcceptableOrUnknown(
          data['picture_path']!,
          _picturePathMeta,
        ),
      );
    }
    if (data.containsKey('picture_media_id')) {
      context.handle(
        _pictureMediaIdMeta,
        pictureMediaId.isAcceptableOrUnknown(
          data['picture_media_id']!,
          _pictureMediaIdMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('archive_notes')) {
      context.handle(
        _archiveNotesMeta,
        archiveNotes.isAcceptableOrUnknown(
          data['archive_notes']!,
          _archiveNotesMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Animal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Animal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      boxId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}box_id'],
      ),
      status: $AnimalsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      commonName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}common_name'],
      )!,
      latinName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}latin_name'],
      )!,
      sex: $AnimalsTable.$convertersexn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}sex'],
        ),
      ),
      birthDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}birth_date'],
      ),
      birthDateAccuracy: $AnimalsTable.$converterbirthDateAccuracyn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}birth_date_accuracy'],
        ),
      ),
      tempMin: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}temp_min'],
      )!,
      tempMax: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}temp_max'],
      )!,
      humidityMin: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}humidity_min'],
      )!,
      humidityMax: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}humidity_max'],
      )!,
      picturePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}picture_path'],
      ),
      pictureMediaId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}picture_media_id'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      archiveReason: $AnimalsTable.$converterarchiveReasonn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}archive_reason'],
        ),
      ),
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      archiveNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}archive_notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AnimalsTable createAlias(String alias) {
    return $AnimalsTable(attachedDatabase, alias);
  }

  static TypeConverter<AnimalStatus, String> $converterstatus =
      const AnimalStatusConverter();
  static TypeConverter<Sex, String> $convertersex = const SexConverter();
  static TypeConverter<Sex?, String?> $convertersexn =
      NullAwareTypeConverter.wrap($convertersex);
  static TypeConverter<BirthDateAccuracy, String> $converterbirthDateAccuracy =
      const BirthDateAccuracyConverter();
  static TypeConverter<BirthDateAccuracy?, String?>
  $converterbirthDateAccuracyn = NullAwareTypeConverter.wrap(
    $converterbirthDateAccuracy,
  );
  static TypeConverter<AnimalArchiveReason, String> $converterarchiveReason =
      const AnimalArchiveReasonConverter();
  static TypeConverter<AnimalArchiveReason?, String?> $converterarchiveReasonn =
      NullAwareTypeConverter.wrap($converterarchiveReason);
}

class Animal extends DataClass implements Insertable<Animal> {
  final int id;
  final int? boxId;
  final AnimalStatus status;
  final String commonName;
  final String latinName;
  final Sex? sex;
  final DateTime? birthDate;
  final BirthDateAccuracy? birthDateAccuracy;
  final double tempMin;
  final double tempMax;
  final double humidityMin;
  final double humidityMax;
  final String? picturePath;
  final int? pictureMediaId;
  final String? notes;
  final AnimalArchiveReason? archiveReason;
  final DateTime? archivedAt;
  final String? archiveNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Animal({
    required this.id,
    this.boxId,
    required this.status,
    required this.commonName,
    required this.latinName,
    this.sex,
    this.birthDate,
    this.birthDateAccuracy,
    required this.tempMin,
    required this.tempMax,
    required this.humidityMin,
    required this.humidityMax,
    this.picturePath,
    this.pictureMediaId,
    this.notes,
    this.archiveReason,
    this.archivedAt,
    this.archiveNotes,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || boxId != null) {
      map['box_id'] = Variable<int>(boxId);
    }
    {
      map['status'] = Variable<String>(
        $AnimalsTable.$converterstatus.toSql(status),
      );
    }
    map['common_name'] = Variable<String>(commonName);
    map['latin_name'] = Variable<String>(latinName);
    if (!nullToAbsent || sex != null) {
      map['sex'] = Variable<String>($AnimalsTable.$convertersexn.toSql(sex));
    }
    if (!nullToAbsent || birthDate != null) {
      map['birth_date'] = Variable<DateTime>(birthDate);
    }
    if (!nullToAbsent || birthDateAccuracy != null) {
      map['birth_date_accuracy'] = Variable<String>(
        $AnimalsTable.$converterbirthDateAccuracyn.toSql(birthDateAccuracy),
      );
    }
    map['temp_min'] = Variable<double>(tempMin);
    map['temp_max'] = Variable<double>(tempMax);
    map['humidity_min'] = Variable<double>(humidityMin);
    map['humidity_max'] = Variable<double>(humidityMax);
    if (!nullToAbsent || picturePath != null) {
      map['picture_path'] = Variable<String>(picturePath);
    }
    if (!nullToAbsent || pictureMediaId != null) {
      map['picture_media_id'] = Variable<int>(pictureMediaId);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || archiveReason != null) {
      map['archive_reason'] = Variable<String>(
        $AnimalsTable.$converterarchiveReasonn.toSql(archiveReason),
      );
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    if (!nullToAbsent || archiveNotes != null) {
      map['archive_notes'] = Variable<String>(archiveNotes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AnimalsCompanion toCompanion(bool nullToAbsent) {
    return AnimalsCompanion(
      id: Value(id),
      boxId: boxId == null && nullToAbsent
          ? const Value.absent()
          : Value(boxId),
      status: Value(status),
      commonName: Value(commonName),
      latinName: Value(latinName),
      sex: sex == null && nullToAbsent ? const Value.absent() : Value(sex),
      birthDate: birthDate == null && nullToAbsent
          ? const Value.absent()
          : Value(birthDate),
      birthDateAccuracy: birthDateAccuracy == null && nullToAbsent
          ? const Value.absent()
          : Value(birthDateAccuracy),
      tempMin: Value(tempMin),
      tempMax: Value(tempMax),
      humidityMin: Value(humidityMin),
      humidityMax: Value(humidityMax),
      picturePath: picturePath == null && nullToAbsent
          ? const Value.absent()
          : Value(picturePath),
      pictureMediaId: pictureMediaId == null && nullToAbsent
          ? const Value.absent()
          : Value(pictureMediaId),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      archiveReason: archiveReason == null && nullToAbsent
          ? const Value.absent()
          : Value(archiveReason),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      archiveNotes: archiveNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(archiveNotes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Animal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Animal(
      id: serializer.fromJson<int>(json['id']),
      boxId: serializer.fromJson<int?>(json['boxId']),
      status: serializer.fromJson<AnimalStatus>(json['status']),
      commonName: serializer.fromJson<String>(json['commonName']),
      latinName: serializer.fromJson<String>(json['latinName']),
      sex: serializer.fromJson<Sex?>(json['sex']),
      birthDate: serializer.fromJson<DateTime?>(json['birthDate']),
      birthDateAccuracy: serializer.fromJson<BirthDateAccuracy?>(
        json['birthDateAccuracy'],
      ),
      tempMin: serializer.fromJson<double>(json['tempMin']),
      tempMax: serializer.fromJson<double>(json['tempMax']),
      humidityMin: serializer.fromJson<double>(json['humidityMin']),
      humidityMax: serializer.fromJson<double>(json['humidityMax']),
      picturePath: serializer.fromJson<String?>(json['picturePath']),
      pictureMediaId: serializer.fromJson<int?>(json['pictureMediaId']),
      notes: serializer.fromJson<String?>(json['notes']),
      archiveReason: serializer.fromJson<AnimalArchiveReason?>(
        json['archiveReason'],
      ),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      archiveNotes: serializer.fromJson<String?>(json['archiveNotes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'boxId': serializer.toJson<int?>(boxId),
      'status': serializer.toJson<AnimalStatus>(status),
      'commonName': serializer.toJson<String>(commonName),
      'latinName': serializer.toJson<String>(latinName),
      'sex': serializer.toJson<Sex?>(sex),
      'birthDate': serializer.toJson<DateTime?>(birthDate),
      'birthDateAccuracy': serializer.toJson<BirthDateAccuracy?>(
        birthDateAccuracy,
      ),
      'tempMin': serializer.toJson<double>(tempMin),
      'tempMax': serializer.toJson<double>(tempMax),
      'humidityMin': serializer.toJson<double>(humidityMin),
      'humidityMax': serializer.toJson<double>(humidityMax),
      'picturePath': serializer.toJson<String?>(picturePath),
      'pictureMediaId': serializer.toJson<int?>(pictureMediaId),
      'notes': serializer.toJson<String?>(notes),
      'archiveReason': serializer.toJson<AnimalArchiveReason?>(archiveReason),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'archiveNotes': serializer.toJson<String?>(archiveNotes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Animal copyWith({
    int? id,
    Value<int?> boxId = const Value.absent(),
    AnimalStatus? status,
    String? commonName,
    String? latinName,
    Value<Sex?> sex = const Value.absent(),
    Value<DateTime?> birthDate = const Value.absent(),
    Value<BirthDateAccuracy?> birthDateAccuracy = const Value.absent(),
    double? tempMin,
    double? tempMax,
    double? humidityMin,
    double? humidityMax,
    Value<String?> picturePath = const Value.absent(),
    Value<int?> pictureMediaId = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<AnimalArchiveReason?> archiveReason = const Value.absent(),
    Value<DateTime?> archivedAt = const Value.absent(),
    Value<String?> archiveNotes = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Animal(
    id: id ?? this.id,
    boxId: boxId.present ? boxId.value : this.boxId,
    status: status ?? this.status,
    commonName: commonName ?? this.commonName,
    latinName: latinName ?? this.latinName,
    sex: sex.present ? sex.value : this.sex,
    birthDate: birthDate.present ? birthDate.value : this.birthDate,
    birthDateAccuracy: birthDateAccuracy.present
        ? birthDateAccuracy.value
        : this.birthDateAccuracy,
    tempMin: tempMin ?? this.tempMin,
    tempMax: tempMax ?? this.tempMax,
    humidityMin: humidityMin ?? this.humidityMin,
    humidityMax: humidityMax ?? this.humidityMax,
    picturePath: picturePath.present ? picturePath.value : this.picturePath,
    pictureMediaId: pictureMediaId.present
        ? pictureMediaId.value
        : this.pictureMediaId,
    notes: notes.present ? notes.value : this.notes,
    archiveReason: archiveReason.present
        ? archiveReason.value
        : this.archiveReason,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    archiveNotes: archiveNotes.present ? archiveNotes.value : this.archiveNotes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Animal copyWithCompanion(AnimalsCompanion data) {
    return Animal(
      id: data.id.present ? data.id.value : this.id,
      boxId: data.boxId.present ? data.boxId.value : this.boxId,
      status: data.status.present ? data.status.value : this.status,
      commonName: data.commonName.present
          ? data.commonName.value
          : this.commonName,
      latinName: data.latinName.present ? data.latinName.value : this.latinName,
      sex: data.sex.present ? data.sex.value : this.sex,
      birthDate: data.birthDate.present ? data.birthDate.value : this.birthDate,
      birthDateAccuracy: data.birthDateAccuracy.present
          ? data.birthDateAccuracy.value
          : this.birthDateAccuracy,
      tempMin: data.tempMin.present ? data.tempMin.value : this.tempMin,
      tempMax: data.tempMax.present ? data.tempMax.value : this.tempMax,
      humidityMin: data.humidityMin.present
          ? data.humidityMin.value
          : this.humidityMin,
      humidityMax: data.humidityMax.present
          ? data.humidityMax.value
          : this.humidityMax,
      picturePath: data.picturePath.present
          ? data.picturePath.value
          : this.picturePath,
      pictureMediaId: data.pictureMediaId.present
          ? data.pictureMediaId.value
          : this.pictureMediaId,
      notes: data.notes.present ? data.notes.value : this.notes,
      archiveReason: data.archiveReason.present
          ? data.archiveReason.value
          : this.archiveReason,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      archiveNotes: data.archiveNotes.present
          ? data.archiveNotes.value
          : this.archiveNotes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Animal(')
          ..write('id: $id, ')
          ..write('boxId: $boxId, ')
          ..write('status: $status, ')
          ..write('commonName: $commonName, ')
          ..write('latinName: $latinName, ')
          ..write('sex: $sex, ')
          ..write('birthDate: $birthDate, ')
          ..write('birthDateAccuracy: $birthDateAccuracy, ')
          ..write('tempMin: $tempMin, ')
          ..write('tempMax: $tempMax, ')
          ..write('humidityMin: $humidityMin, ')
          ..write('humidityMax: $humidityMax, ')
          ..write('picturePath: $picturePath, ')
          ..write('pictureMediaId: $pictureMediaId, ')
          ..write('notes: $notes, ')
          ..write('archiveReason: $archiveReason, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('archiveNotes: $archiveNotes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    boxId,
    status,
    commonName,
    latinName,
    sex,
    birthDate,
    birthDateAccuracy,
    tempMin,
    tempMax,
    humidityMin,
    humidityMax,
    picturePath,
    pictureMediaId,
    notes,
    archiveReason,
    archivedAt,
    archiveNotes,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Animal &&
          other.id == this.id &&
          other.boxId == this.boxId &&
          other.status == this.status &&
          other.commonName == this.commonName &&
          other.latinName == this.latinName &&
          other.sex == this.sex &&
          other.birthDate == this.birthDate &&
          other.birthDateAccuracy == this.birthDateAccuracy &&
          other.tempMin == this.tempMin &&
          other.tempMax == this.tempMax &&
          other.humidityMin == this.humidityMin &&
          other.humidityMax == this.humidityMax &&
          other.picturePath == this.picturePath &&
          other.pictureMediaId == this.pictureMediaId &&
          other.notes == this.notes &&
          other.archiveReason == this.archiveReason &&
          other.archivedAt == this.archivedAt &&
          other.archiveNotes == this.archiveNotes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AnimalsCompanion extends UpdateCompanion<Animal> {
  final Value<int> id;
  final Value<int?> boxId;
  final Value<AnimalStatus> status;
  final Value<String> commonName;
  final Value<String> latinName;
  final Value<Sex?> sex;
  final Value<DateTime?> birthDate;
  final Value<BirthDateAccuracy?> birthDateAccuracy;
  final Value<double> tempMin;
  final Value<double> tempMax;
  final Value<double> humidityMin;
  final Value<double> humidityMax;
  final Value<String?> picturePath;
  final Value<int?> pictureMediaId;
  final Value<String?> notes;
  final Value<AnimalArchiveReason?> archiveReason;
  final Value<DateTime?> archivedAt;
  final Value<String?> archiveNotes;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const AnimalsCompanion({
    this.id = const Value.absent(),
    this.boxId = const Value.absent(),
    this.status = const Value.absent(),
    this.commonName = const Value.absent(),
    this.latinName = const Value.absent(),
    this.sex = const Value.absent(),
    this.birthDate = const Value.absent(),
    this.birthDateAccuracy = const Value.absent(),
    this.tempMin = const Value.absent(),
    this.tempMax = const Value.absent(),
    this.humidityMin = const Value.absent(),
    this.humidityMax = const Value.absent(),
    this.picturePath = const Value.absent(),
    this.pictureMediaId = const Value.absent(),
    this.notes = const Value.absent(),
    this.archiveReason = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.archiveNotes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AnimalsCompanion.insert({
    this.id = const Value.absent(),
    this.boxId = const Value.absent(),
    this.status = const Value.absent(),
    required String commonName,
    required String latinName,
    this.sex = const Value.absent(),
    this.birthDate = const Value.absent(),
    this.birthDateAccuracy = const Value.absent(),
    required double tempMin,
    required double tempMax,
    required double humidityMin,
    required double humidityMax,
    this.picturePath = const Value.absent(),
    this.pictureMediaId = const Value.absent(),
    this.notes = const Value.absent(),
    this.archiveReason = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.archiveNotes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : commonName = Value(commonName),
       latinName = Value(latinName),
       tempMin = Value(tempMin),
       tempMax = Value(tempMax),
       humidityMin = Value(humidityMin),
       humidityMax = Value(humidityMax);
  static Insertable<Animal> custom({
    Expression<int>? id,
    Expression<int>? boxId,
    Expression<String>? status,
    Expression<String>? commonName,
    Expression<String>? latinName,
    Expression<String>? sex,
    Expression<DateTime>? birthDate,
    Expression<String>? birthDateAccuracy,
    Expression<double>? tempMin,
    Expression<double>? tempMax,
    Expression<double>? humidityMin,
    Expression<double>? humidityMax,
    Expression<String>? picturePath,
    Expression<int>? pictureMediaId,
    Expression<String>? notes,
    Expression<String>? archiveReason,
    Expression<DateTime>? archivedAt,
    Expression<String>? archiveNotes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (boxId != null) 'box_id': boxId,
      if (status != null) 'status': status,
      if (commonName != null) 'common_name': commonName,
      if (latinName != null) 'latin_name': latinName,
      if (sex != null) 'sex': sex,
      if (birthDate != null) 'birth_date': birthDate,
      if (birthDateAccuracy != null) 'birth_date_accuracy': birthDateAccuracy,
      if (tempMin != null) 'temp_min': tempMin,
      if (tempMax != null) 'temp_max': tempMax,
      if (humidityMin != null) 'humidity_min': humidityMin,
      if (humidityMax != null) 'humidity_max': humidityMax,
      if (picturePath != null) 'picture_path': picturePath,
      if (pictureMediaId != null) 'picture_media_id': pictureMediaId,
      if (notes != null) 'notes': notes,
      if (archiveReason != null) 'archive_reason': archiveReason,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (archiveNotes != null) 'archive_notes': archiveNotes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AnimalsCompanion copyWith({
    Value<int>? id,
    Value<int?>? boxId,
    Value<AnimalStatus>? status,
    Value<String>? commonName,
    Value<String>? latinName,
    Value<Sex?>? sex,
    Value<DateTime?>? birthDate,
    Value<BirthDateAccuracy?>? birthDateAccuracy,
    Value<double>? tempMin,
    Value<double>? tempMax,
    Value<double>? humidityMin,
    Value<double>? humidityMax,
    Value<String?>? picturePath,
    Value<int?>? pictureMediaId,
    Value<String?>? notes,
    Value<AnimalArchiveReason?>? archiveReason,
    Value<DateTime?>? archivedAt,
    Value<String?>? archiveNotes,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return AnimalsCompanion(
      id: id ?? this.id,
      boxId: boxId ?? this.boxId,
      status: status ?? this.status,
      commonName: commonName ?? this.commonName,
      latinName: latinName ?? this.latinName,
      sex: sex ?? this.sex,
      birthDate: birthDate ?? this.birthDate,
      birthDateAccuracy: birthDateAccuracy ?? this.birthDateAccuracy,
      tempMin: tempMin ?? this.tempMin,
      tempMax: tempMax ?? this.tempMax,
      humidityMin: humidityMin ?? this.humidityMin,
      humidityMax: humidityMax ?? this.humidityMax,
      picturePath: picturePath ?? this.picturePath,
      pictureMediaId: pictureMediaId ?? this.pictureMediaId,
      notes: notes ?? this.notes,
      archiveReason: archiveReason ?? this.archiveReason,
      archivedAt: archivedAt ?? this.archivedAt,
      archiveNotes: archiveNotes ?? this.archiveNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (boxId.present) {
      map['box_id'] = Variable<int>(boxId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $AnimalsTable.$converterstatus.toSql(status.value),
      );
    }
    if (commonName.present) {
      map['common_name'] = Variable<String>(commonName.value);
    }
    if (latinName.present) {
      map['latin_name'] = Variable<String>(latinName.value);
    }
    if (sex.present) {
      map['sex'] = Variable<String>(
        $AnimalsTable.$convertersexn.toSql(sex.value),
      );
    }
    if (birthDate.present) {
      map['birth_date'] = Variable<DateTime>(birthDate.value);
    }
    if (birthDateAccuracy.present) {
      map['birth_date_accuracy'] = Variable<String>(
        $AnimalsTable.$converterbirthDateAccuracyn.toSql(
          birthDateAccuracy.value,
        ),
      );
    }
    if (tempMin.present) {
      map['temp_min'] = Variable<double>(tempMin.value);
    }
    if (tempMax.present) {
      map['temp_max'] = Variable<double>(tempMax.value);
    }
    if (humidityMin.present) {
      map['humidity_min'] = Variable<double>(humidityMin.value);
    }
    if (humidityMax.present) {
      map['humidity_max'] = Variable<double>(humidityMax.value);
    }
    if (picturePath.present) {
      map['picture_path'] = Variable<String>(picturePath.value);
    }
    if (pictureMediaId.present) {
      map['picture_media_id'] = Variable<int>(pictureMediaId.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (archiveReason.present) {
      map['archive_reason'] = Variable<String>(
        $AnimalsTable.$converterarchiveReasonn.toSql(archiveReason.value),
      );
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (archiveNotes.present) {
      map['archive_notes'] = Variable<String>(archiveNotes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnimalsCompanion(')
          ..write('id: $id, ')
          ..write('boxId: $boxId, ')
          ..write('status: $status, ')
          ..write('commonName: $commonName, ')
          ..write('latinName: $latinName, ')
          ..write('sex: $sex, ')
          ..write('birthDate: $birthDate, ')
          ..write('birthDateAccuracy: $birthDateAccuracy, ')
          ..write('tempMin: $tempMin, ')
          ..write('tempMax: $tempMax, ')
          ..write('humidityMin: $humidityMin, ')
          ..write('humidityMax: $humidityMax, ')
          ..write('picturePath: $picturePath, ')
          ..write('pictureMediaId: $pictureMediaId, ')
          ..write('notes: $notes, ')
          ..write('archiveReason: $archiveReason, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('archiveNotes: $archiveNotes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $FeedingEventsTable extends FeedingEvents
    with TableInfo<$FeedingEventsTable, FeedingEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FeedingEventsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _animalIdMeta = const VerificationMeta(
    'animalId',
  );
  @override
  late final GeneratedColumn<int> animalId = GeneratedColumn<int>(
    'animal_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES animals (id)',
    ),
  );
  static const VerificationMeta _fedAtMeta = const VerificationMeta('fedAt');
  @override
  late final GeneratedColumn<DateTime> fedAt = GeneratedColumn<DateTime>(
    'fed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, animalId, fedAt, notes];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'feeding_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<FeedingEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('animal_id')) {
      context.handle(
        _animalIdMeta,
        animalId.isAcceptableOrUnknown(data['animal_id']!, _animalIdMeta),
      );
    } else if (isInserting) {
      context.missing(_animalIdMeta);
    }
    if (data.containsKey('fed_at')) {
      context.handle(
        _fedAtMeta,
        fedAt.isAcceptableOrUnknown(data['fed_at']!, _fedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fedAtMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FeedingEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FeedingEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      animalId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}animal_id'],
      )!,
      fedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fed_at'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $FeedingEventsTable createAlias(String alias) {
    return $FeedingEventsTable(attachedDatabase, alias);
  }
}

class FeedingEvent extends DataClass implements Insertable<FeedingEvent> {
  final int id;
  final int animalId;
  final DateTime fedAt;
  final String? notes;
  const FeedingEvent({
    required this.id,
    required this.animalId,
    required this.fedAt,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['animal_id'] = Variable<int>(animalId);
    map['fed_at'] = Variable<DateTime>(fedAt);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  FeedingEventsCompanion toCompanion(bool nullToAbsent) {
    return FeedingEventsCompanion(
      id: Value(id),
      animalId: Value(animalId),
      fedAt: Value(fedAt),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory FeedingEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FeedingEvent(
      id: serializer.fromJson<int>(json['id']),
      animalId: serializer.fromJson<int>(json['animalId']),
      fedAt: serializer.fromJson<DateTime>(json['fedAt']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'animalId': serializer.toJson<int>(animalId),
      'fedAt': serializer.toJson<DateTime>(fedAt),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  FeedingEvent copyWith({
    int? id,
    int? animalId,
    DateTime? fedAt,
    Value<String?> notes = const Value.absent(),
  }) => FeedingEvent(
    id: id ?? this.id,
    animalId: animalId ?? this.animalId,
    fedAt: fedAt ?? this.fedAt,
    notes: notes.present ? notes.value : this.notes,
  );
  FeedingEvent copyWithCompanion(FeedingEventsCompanion data) {
    return FeedingEvent(
      id: data.id.present ? data.id.value : this.id,
      animalId: data.animalId.present ? data.animalId.value : this.animalId,
      fedAt: data.fedAt.present ? data.fedAt.value : this.fedAt,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FeedingEvent(')
          ..write('id: $id, ')
          ..write('animalId: $animalId, ')
          ..write('fedAt: $fedAt, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, animalId, fedAt, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FeedingEvent &&
          other.id == this.id &&
          other.animalId == this.animalId &&
          other.fedAt == this.fedAt &&
          other.notes == this.notes);
}

class FeedingEventsCompanion extends UpdateCompanion<FeedingEvent> {
  final Value<int> id;
  final Value<int> animalId;
  final Value<DateTime> fedAt;
  final Value<String?> notes;
  const FeedingEventsCompanion({
    this.id = const Value.absent(),
    this.animalId = const Value.absent(),
    this.fedAt = const Value.absent(),
    this.notes = const Value.absent(),
  });
  FeedingEventsCompanion.insert({
    this.id = const Value.absent(),
    required int animalId,
    required DateTime fedAt,
    this.notes = const Value.absent(),
  }) : animalId = Value(animalId),
       fedAt = Value(fedAt);
  static Insertable<FeedingEvent> custom({
    Expression<int>? id,
    Expression<int>? animalId,
    Expression<DateTime>? fedAt,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (animalId != null) 'animal_id': animalId,
      if (fedAt != null) 'fed_at': fedAt,
      if (notes != null) 'notes': notes,
    });
  }

  FeedingEventsCompanion copyWith({
    Value<int>? id,
    Value<int>? animalId,
    Value<DateTime>? fedAt,
    Value<String?>? notes,
  }) {
    return FeedingEventsCompanion(
      id: id ?? this.id,
      animalId: animalId ?? this.animalId,
      fedAt: fedAt ?? this.fedAt,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (animalId.present) {
      map['animal_id'] = Variable<int>(animalId.value);
    }
    if (fedAt.present) {
      map['fed_at'] = Variable<DateTime>(fedAt.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FeedingEventsCompanion(')
          ..write('id: $id, ')
          ..write('animalId: $animalId, ')
          ..write('fedAt: $fedAt, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MediaAssetsTable mediaAssets = $MediaAssetsTable(this);
  late final $BoxesTable boxes = $BoxesTable(this);
  late final $AnimalsTable animals = $AnimalsTable(this);
  late final $FeedingEventsTable feedingEvents = $FeedingEventsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    mediaAssets,
    boxes,
    animals,
    feedingEvents,
  ];
}

typedef $$MediaAssetsTableCreateCompanionBuilder =
    MediaAssetsCompanion Function({
      Value<int> id,
      required String fileName,
      required String mimeType,
      required Uint8List data,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$MediaAssetsTableUpdateCompanionBuilder =
    MediaAssetsCompanion Function({
      Value<int> id,
      Value<String> fileName,
      Value<String> mimeType,
      Value<Uint8List> data,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$MediaAssetsTableReferences
    extends BaseReferences<_$AppDatabase, $MediaAssetsTable, MediaAsset> {
  $$MediaAssetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$BoxesTable, List<Box>> _boxesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.boxes,
    aliasName: 'media_assets__id__boxes__picture_media_id',
  );

  $$BoxesTableProcessedTableManager get boxesRefs {
    final manager = $$BoxesTableTableManager(
      $_db,
      $_db.boxes,
    ).filter((f) => f.pictureMediaId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_boxesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AnimalsTable, List<Animal>> _animalsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.animals,
    aliasName: 'media_assets__id__animals__picture_media_id',
  );

  $$AnimalsTableProcessedTableManager get animalsRefs {
    final manager = $$AnimalsTableTableManager(
      $_db,
      $_db.animals,
    ).filter((f) => f.pictureMediaId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_animalsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MediaAssetsTableFilterComposer
    extends Composer<_$AppDatabase, $MediaAssetsTable> {
  $$MediaAssetsTableFilterComposer({
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

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> boxesRefs(
    Expression<bool> Function($$BoxesTableFilterComposer f) f,
  ) {
    final $$BoxesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.boxes,
      getReferencedColumn: (t) => t.pictureMediaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoxesTableFilterComposer(
            $db: $db,
            $table: $db.boxes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> animalsRefs(
    Expression<bool> Function($$AnimalsTableFilterComposer f) f,
  ) {
    final $$AnimalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.animals,
      getReferencedColumn: (t) => t.pictureMediaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnimalsTableFilterComposer(
            $db: $db,
            $table: $db.animals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MediaAssetsTableOrderingComposer
    extends Composer<_$AppDatabase, $MediaAssetsTable> {
  $$MediaAssetsTableOrderingComposer({
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

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MediaAssetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MediaAssetsTable> {
  $$MediaAssetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<Uint8List> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> boxesRefs<T extends Object>(
    Expression<T> Function($$BoxesTableAnnotationComposer a) f,
  ) {
    final $$BoxesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.boxes,
      getReferencedColumn: (t) => t.pictureMediaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoxesTableAnnotationComposer(
            $db: $db,
            $table: $db.boxes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> animalsRefs<T extends Object>(
    Expression<T> Function($$AnimalsTableAnnotationComposer a) f,
  ) {
    final $$AnimalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.animals,
      getReferencedColumn: (t) => t.pictureMediaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnimalsTableAnnotationComposer(
            $db: $db,
            $table: $db.animals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MediaAssetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MediaAssetsTable,
          MediaAsset,
          $$MediaAssetsTableFilterComposer,
          $$MediaAssetsTableOrderingComposer,
          $$MediaAssetsTableAnnotationComposer,
          $$MediaAssetsTableCreateCompanionBuilder,
          $$MediaAssetsTableUpdateCompanionBuilder,
          (MediaAsset, $$MediaAssetsTableReferences),
          MediaAsset,
          PrefetchHooks Function({bool boxesRefs, bool animalsRefs})
        > {
  $$MediaAssetsTableTableManager(_$AppDatabase db, $MediaAssetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaAssetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaAssetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaAssetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<Uint8List> data = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => MediaAssetsCompanion(
                id: id,
                fileName: fileName,
                mimeType: mimeType,
                data: data,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String fileName,
                required String mimeType,
                required Uint8List data,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => MediaAssetsCompanion.insert(
                id: id,
                fileName: fileName,
                mimeType: mimeType,
                data: data,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MediaAssetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({boxesRefs = false, animalsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (boxesRefs) db.boxes,
                if (animalsRefs) db.animals,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (boxesRefs)
                    await $_getPrefetchedData<
                      MediaAsset,
                      $MediaAssetsTable,
                      Box
                    >(
                      currentTable: table,
                      referencedTable: $$MediaAssetsTableReferences
                          ._boxesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$MediaAssetsTableReferences(db, table, p0).boxesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.pictureMediaId == item.id,
                          ),
                      typedResults: items,
                    ),
                  if (animalsRefs)
                    await $_getPrefetchedData<
                      MediaAsset,
                      $MediaAssetsTable,
                      Animal
                    >(
                      currentTable: table,
                      referencedTable: $$MediaAssetsTableReferences
                          ._animalsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$MediaAssetsTableReferences(
                            db,
                            table,
                            p0,
                          ).animalsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.pictureMediaId == item.id,
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

typedef $$MediaAssetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MediaAssetsTable,
      MediaAsset,
      $$MediaAssetsTableFilterComposer,
      $$MediaAssetsTableOrderingComposer,
      $$MediaAssetsTableAnnotationComposer,
      $$MediaAssetsTableCreateCompanionBuilder,
      $$MediaAssetsTableUpdateCompanionBuilder,
      (MediaAsset, $$MediaAssetsTableReferences),
      MediaAsset,
      PrefetchHooks Function({bool boxesRefs, bool animalsRefs})
    >;
typedef $$BoxesTableCreateCompanionBuilder = BoxesCompanion Function({
  Value<int> id,
  required String qrId,
  Value<double?> widthCm,
  Value<double?> heightCm,
  Value<double?> depthCm,
  Value<int?> pictureMediaId,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$BoxesTableUpdateCompanionBuilder = BoxesCompanion Function({
  Value<int> id,
  Value<String> qrId,
  Value<double?> widthCm,
  Value<double?> heightCm,
  Value<double?> depthCm,
  Value<int?> pictureMediaId,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$BoxesTableReferences
    extends BaseReferences<_$AppDatabase, $BoxesTable, Box> {
  $$BoxesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MediaAssetsTable _pictureMediaIdTable(_$AppDatabase db) =>
      db.mediaAssets.createAlias('boxes__picture_media_id__media_assets__id');

  $$MediaAssetsTableProcessedTableManager? get pictureMediaId {
    final $_column = $_itemColumn<int>('picture_media_id');
    if ($_column == null) return null;
    final manager = $$MediaAssetsTableTableManager(
      $_db,
      $_db.mediaAssets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pictureMediaIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$AnimalsTable, List<Animal>> _animalsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.animals,
    aliasName: 'boxes__id__animals__box_id',
  );

  $$AnimalsTableProcessedTableManager get animalsRefs {
    final manager = $$AnimalsTableTableManager(
      $_db,
      $_db.animals,
    ).filter((f) => f.boxId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_animalsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BoxesTableFilterComposer extends Composer<_$AppDatabase, $BoxesTable> {
  $$BoxesTableFilterComposer({
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

  ColumnFilters<String> get qrId => $composableBuilder(
    column: $table.qrId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get widthCm => $composableBuilder(
    column: $table.widthCm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get depthCm => $composableBuilder(
    column: $table.depthCm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MediaAssetsTableFilterComposer get pictureMediaId {
    final $$MediaAssetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pictureMediaId,
      referencedTable: $db.mediaAssets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaAssetsTableFilterComposer(
            $db: $db,
            $table: $db.mediaAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> animalsRefs(
    Expression<bool> Function($$AnimalsTableFilterComposer f) f,
  ) {
    final $$AnimalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.animals,
      getReferencedColumn: (t) => t.boxId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnimalsTableFilterComposer(
            $db: $db,
            $table: $db.animals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BoxesTableOrderingComposer
    extends Composer<_$AppDatabase, $BoxesTable> {
  $$BoxesTableOrderingComposer({
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

  ColumnOrderings<String> get qrId => $composableBuilder(
    column: $table.qrId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get widthCm => $composableBuilder(
    column: $table.widthCm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get depthCm => $composableBuilder(
    column: $table.depthCm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MediaAssetsTableOrderingComposer get pictureMediaId {
    final $$MediaAssetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pictureMediaId,
      referencedTable: $db.mediaAssets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaAssetsTableOrderingComposer(
            $db: $db,
            $table: $db.mediaAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BoxesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BoxesTable> {
  $$BoxesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get qrId =>
      $composableBuilder(column: $table.qrId, builder: (column) => column);

  GeneratedColumn<double> get widthCm =>
      $composableBuilder(column: $table.widthCm, builder: (column) => column);

  GeneratedColumn<double> get heightCm =>
      $composableBuilder(column: $table.heightCm, builder: (column) => column);

  GeneratedColumn<double> get depthCm =>
      $composableBuilder(column: $table.depthCm, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$MediaAssetsTableAnnotationComposer get pictureMediaId {
    final $$MediaAssetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pictureMediaId,
      referencedTable: $db.mediaAssets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaAssetsTableAnnotationComposer(
            $db: $db,
            $table: $db.mediaAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> animalsRefs<T extends Object>(
    Expression<T> Function($$AnimalsTableAnnotationComposer a) f,
  ) {
    final $$AnimalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.animals,
      getReferencedColumn: (t) => t.boxId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnimalsTableAnnotationComposer(
            $db: $db,
            $table: $db.animals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BoxesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BoxesTable,
          Box,
          $$BoxesTableFilterComposer,
          $$BoxesTableOrderingComposer,
          $$BoxesTableAnnotationComposer,
          $$BoxesTableCreateCompanionBuilder,
          $$BoxesTableUpdateCompanionBuilder,
          (Box, $$BoxesTableReferences),
          Box,
          PrefetchHooks Function({bool pictureMediaId, bool animalsRefs})
        > {
  $$BoxesTableTableManager(_$AppDatabase db, $BoxesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BoxesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BoxesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BoxesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> qrId = const Value.absent(),
                Value<double?> widthCm = const Value.absent(),
                Value<double?> heightCm = const Value.absent(),
                Value<double?> depthCm = const Value.absent(),
                Value<int?> pictureMediaId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => BoxesCompanion(
                id: id,
                qrId: qrId,
                widthCm: widthCm,
                heightCm: heightCm,
                depthCm: depthCm,
                pictureMediaId: pictureMediaId,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String qrId,
                Value<double?> widthCm = const Value.absent(),
                Value<double?> heightCm = const Value.absent(),
                Value<double?> depthCm = const Value.absent(),
                Value<int?> pictureMediaId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => BoxesCompanion.insert(
                id: id,
                qrId: qrId,
                widthCm: widthCm,
                heightCm: heightCm,
                depthCm: depthCm,
                pictureMediaId: pictureMediaId,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$BoxesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({pictureMediaId = false, animalsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [if (animalsRefs) db.animals],
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
                        if (pictureMediaId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.pictureMediaId,
                            referencedTable: $$BoxesTableReferences
                                ._pictureMediaIdTable(db),
                            referencedColumn: $$BoxesTableReferences
                                ._pictureMediaIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (animalsRefs)
                        await $_getPrefetchedData<Box, $BoxesTable, Animal>(
                          currentTable: table,
                          referencedTable: $$BoxesTableReferences
                              ._animalsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BoxesTableReferences(db, table, p0).animalsRefs,
                          referencedItemsForCurrentItem: (
                            item,
                            referencedItems,
                          ) => referencedItems.where((e) => e.boxId == item.id),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$BoxesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BoxesTable,
      Box,
      $$BoxesTableFilterComposer,
      $$BoxesTableOrderingComposer,
      $$BoxesTableAnnotationComposer,
      $$BoxesTableCreateCompanionBuilder,
      $$BoxesTableUpdateCompanionBuilder,
      (Box, $$BoxesTableReferences),
      Box,
      PrefetchHooks Function({bool pictureMediaId, bool animalsRefs})
    >;
typedef $$AnimalsTableCreateCompanionBuilder = AnimalsCompanion Function({
  Value<int> id,
  Value<int?> boxId,
  Value<AnimalStatus> status,
  required String commonName,
  required String latinName,
  Value<Sex?> sex,
  Value<DateTime?> birthDate,
  Value<BirthDateAccuracy?> birthDateAccuracy,
  required double tempMin,
  required double tempMax,
  required double humidityMin,
  required double humidityMax,
  Value<String?> picturePath,
  Value<int?> pictureMediaId,
  Value<String?> notes,
  Value<AnimalArchiveReason?> archiveReason,
  Value<DateTime?> archivedAt,
  Value<String?> archiveNotes,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$AnimalsTableUpdateCompanionBuilder = AnimalsCompanion Function({
  Value<int> id,
  Value<int?> boxId,
  Value<AnimalStatus> status,
  Value<String> commonName,
  Value<String> latinName,
  Value<Sex?> sex,
  Value<DateTime?> birthDate,
  Value<BirthDateAccuracy?> birthDateAccuracy,
  Value<double> tempMin,
  Value<double> tempMax,
  Value<double> humidityMin,
  Value<double> humidityMax,
  Value<String?> picturePath,
  Value<int?> pictureMediaId,
  Value<String?> notes,
  Value<AnimalArchiveReason?> archiveReason,
  Value<DateTime?> archivedAt,
  Value<String?> archiveNotes,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$AnimalsTableReferences
    extends BaseReferences<_$AppDatabase, $AnimalsTable, Animal> {
  $$AnimalsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BoxesTable _boxIdTable(_$AppDatabase db) =>
      db.boxes.createAlias('animals__box_id__boxes__id');

  $$BoxesTableProcessedTableManager? get boxId {
    final $_column = $_itemColumn<int>('box_id');
    if ($_column == null) return null;
    final manager = $$BoxesTableTableManager(
      $_db,
      $_db.boxes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_boxIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $MediaAssetsTable _pictureMediaIdTable(_$AppDatabase db) =>
      db.mediaAssets.createAlias('animals__picture_media_id__media_assets__id');

  $$MediaAssetsTableProcessedTableManager? get pictureMediaId {
    final $_column = $_itemColumn<int>('picture_media_id');
    if ($_column == null) return null;
    final manager = $$MediaAssetsTableTableManager(
      $_db,
      $_db.mediaAssets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pictureMediaIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$FeedingEventsTable, List<FeedingEvent>>
  _feedingEventsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.feedingEvents,
    aliasName: 'animals__id__feeding_events__animal_id',
  );

  $$FeedingEventsTableProcessedTableManager get feedingEventsRefs {
    final manager = $$FeedingEventsTableTableManager(
      $_db,
      $_db.feedingEvents,
    ).filter((f) => f.animalId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_feedingEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AnimalsTableFilterComposer
    extends Composer<_$AppDatabase, $AnimalsTable> {
  $$AnimalsTableFilterComposer({
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

  ColumnWithTypeConverterFilters<AnimalStatus, AnimalStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get commonName => $composableBuilder(
    column: $table.commonName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get latinName => $composableBuilder(
    column: $table.latinName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Sex?, Sex, String> get sex =>
      $composableBuilder(
        column: $table.sex,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<BirthDateAccuracy?, BirthDateAccuracy, String>
  get birthDateAccuracy => $composableBuilder(
    column: $table.birthDateAccuracy,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<double> get tempMin => $composableBuilder(
    column: $table.tempMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get tempMax => $composableBuilder(
    column: $table.tempMax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get humidityMin => $composableBuilder(
    column: $table.humidityMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get humidityMax => $composableBuilder(
    column: $table.humidityMax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get picturePath => $composableBuilder(
    column: $table.picturePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    AnimalArchiveReason?,
    AnimalArchiveReason,
    String
  >
  get archiveReason => $composableBuilder(
    column: $table.archiveReason,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get archiveNotes => $composableBuilder(
    column: $table.archiveNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$BoxesTableFilterComposer get boxId {
    final $$BoxesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.boxId,
      referencedTable: $db.boxes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoxesTableFilterComposer(
            $db: $db,
            $table: $db.boxes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MediaAssetsTableFilterComposer get pictureMediaId {
    final $$MediaAssetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pictureMediaId,
      referencedTable: $db.mediaAssets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaAssetsTableFilterComposer(
            $db: $db,
            $table: $db.mediaAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> feedingEventsRefs(
    Expression<bool> Function($$FeedingEventsTableFilterComposer f) f,
  ) {
    final $$FeedingEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.feedingEvents,
      getReferencedColumn: (t) => t.animalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FeedingEventsTableFilterComposer(
            $db: $db,
            $table: $db.feedingEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AnimalsTableOrderingComposer
    extends Composer<_$AppDatabase, $AnimalsTable> {
  $$AnimalsTableOrderingComposer({
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

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commonName => $composableBuilder(
    column: $table.commonName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get latinName => $composableBuilder(
    column: $table.latinName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sex => $composableBuilder(
    column: $table.sex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get birthDateAccuracy => $composableBuilder(
    column: $table.birthDateAccuracy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get tempMin => $composableBuilder(
    column: $table.tempMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get tempMax => $composableBuilder(
    column: $table.tempMax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get humidityMin => $composableBuilder(
    column: $table.humidityMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get humidityMax => $composableBuilder(
    column: $table.humidityMax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get picturePath => $composableBuilder(
    column: $table.picturePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get archiveReason => $composableBuilder(
    column: $table.archiveReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get archiveNotes => $composableBuilder(
    column: $table.archiveNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$BoxesTableOrderingComposer get boxId {
    final $$BoxesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.boxId,
      referencedTable: $db.boxes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoxesTableOrderingComposer(
            $db: $db,
            $table: $db.boxes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MediaAssetsTableOrderingComposer get pictureMediaId {
    final $$MediaAssetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pictureMediaId,
      referencedTable: $db.mediaAssets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaAssetsTableOrderingComposer(
            $db: $db,
            $table: $db.mediaAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AnimalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnimalsTable> {
  $$AnimalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AnimalStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get commonName => $composableBuilder(
    column: $table.commonName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get latinName =>
      $composableBuilder(column: $table.latinName, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Sex?, String> get sex =>
      $composableBuilder(column: $table.sex, builder: (column) => column);

  GeneratedColumn<DateTime> get birthDate =>
      $composableBuilder(column: $table.birthDate, builder: (column) => column);

  GeneratedColumnWithTypeConverter<BirthDateAccuracy?, String>
  get birthDateAccuracy => $composableBuilder(
    column: $table.birthDateAccuracy,
    builder: (column) => column,
  );

  GeneratedColumn<double> get tempMin =>
      $composableBuilder(column: $table.tempMin, builder: (column) => column);

  GeneratedColumn<double> get tempMax =>
      $composableBuilder(column: $table.tempMax, builder: (column) => column);

  GeneratedColumn<double> get humidityMin => $composableBuilder(
    column: $table.humidityMin,
    builder: (column) => column,
  );

  GeneratedColumn<double> get humidityMax => $composableBuilder(
    column: $table.humidityMax,
    builder: (column) => column,
  );

  GeneratedColumn<String> get picturePath => $composableBuilder(
    column: $table.picturePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AnimalArchiveReason?, String>
  get archiveReason => $composableBuilder(
    column: $table.archiveReason,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get archiveNotes => $composableBuilder(
    column: $table.archiveNotes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$BoxesTableAnnotationComposer get boxId {
    final $$BoxesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.boxId,
      referencedTable: $db.boxes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoxesTableAnnotationComposer(
            $db: $db,
            $table: $db.boxes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MediaAssetsTableAnnotationComposer get pictureMediaId {
    final $$MediaAssetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pictureMediaId,
      referencedTable: $db.mediaAssets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaAssetsTableAnnotationComposer(
            $db: $db,
            $table: $db.mediaAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> feedingEventsRefs<T extends Object>(
    Expression<T> Function($$FeedingEventsTableAnnotationComposer a) f,
  ) {
    final $$FeedingEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.feedingEvents,
      getReferencedColumn: (t) => t.animalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FeedingEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.feedingEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AnimalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AnimalsTable,
          Animal,
          $$AnimalsTableFilterComposer,
          $$AnimalsTableOrderingComposer,
          $$AnimalsTableAnnotationComposer,
          $$AnimalsTableCreateCompanionBuilder,
          $$AnimalsTableUpdateCompanionBuilder,
          (Animal, $$AnimalsTableReferences),
          Animal,
          PrefetchHooks Function({
            bool boxId,
            bool pictureMediaId,
            bool feedingEventsRefs,
          })
        > {
  $$AnimalsTableTableManager(_$AppDatabase db, $AnimalsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnimalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnimalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnimalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> boxId = const Value.absent(),
                Value<AnimalStatus> status = const Value.absent(),
                Value<String> commonName = const Value.absent(),
                Value<String> latinName = const Value.absent(),
                Value<Sex?> sex = const Value.absent(),
                Value<DateTime?> birthDate = const Value.absent(),
                Value<BirthDateAccuracy?> birthDateAccuracy =
                    const Value.absent(),
                Value<double> tempMin = const Value.absent(),
                Value<double> tempMax = const Value.absent(),
                Value<double> humidityMin = const Value.absent(),
                Value<double> humidityMax = const Value.absent(),
                Value<String?> picturePath = const Value.absent(),
                Value<int?> pictureMediaId = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<AnimalArchiveReason?> archiveReason =
                    const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<String?> archiveNotes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AnimalsCompanion(
                id: id,
                boxId: boxId,
                status: status,
                commonName: commonName,
                latinName: latinName,
                sex: sex,
                birthDate: birthDate,
                birthDateAccuracy: birthDateAccuracy,
                tempMin: tempMin,
                tempMax: tempMax,
                humidityMin: humidityMin,
                humidityMax: humidityMax,
                picturePath: picturePath,
                pictureMediaId: pictureMediaId,
                notes: notes,
                archiveReason: archiveReason,
                archivedAt: archivedAt,
                archiveNotes: archiveNotes,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> boxId = const Value.absent(),
                Value<AnimalStatus> status = const Value.absent(),
                required String commonName,
                required String latinName,
                Value<Sex?> sex = const Value.absent(),
                Value<DateTime?> birthDate = const Value.absent(),
                Value<BirthDateAccuracy?> birthDateAccuracy =
                    const Value.absent(),
                required double tempMin,
                required double tempMax,
                required double humidityMin,
                required double humidityMax,
                Value<String?> picturePath = const Value.absent(),
                Value<int?> pictureMediaId = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<AnimalArchiveReason?> archiveReason =
                    const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<String?> archiveNotes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AnimalsCompanion.insert(
                id: id,
                boxId: boxId,
                status: status,
                commonName: commonName,
                latinName: latinName,
                sex: sex,
                birthDate: birthDate,
                birthDateAccuracy: birthDateAccuracy,
                tempMin: tempMin,
                tempMax: tempMax,
                humidityMin: humidityMin,
                humidityMax: humidityMax,
                picturePath: picturePath,
                pictureMediaId: pictureMediaId,
                notes: notes,
                archiveReason: archiveReason,
                archivedAt: archivedAt,
                archiveNotes: archiveNotes,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AnimalsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                boxId = false,
                pictureMediaId = false,
                feedingEventsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (feedingEventsRefs) db.feedingEvents,
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
                        if (boxId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.boxId,
                            referencedTable: $$AnimalsTableReferences
                                ._boxIdTable(db),
                            referencedColumn: $$AnimalsTableReferences
                                ._boxIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (pictureMediaId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.pictureMediaId,
                            referencedTable: $$AnimalsTableReferences
                                ._pictureMediaIdTable(db),
                            referencedColumn: $$AnimalsTableReferences
                                ._pictureMediaIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (feedingEventsRefs)
                        await $_getPrefetchedData<
                          Animal,
                          $AnimalsTable,
                          FeedingEvent
                        >(
                          currentTable: table,
                          referencedTable: $$AnimalsTableReferences
                              ._feedingEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AnimalsTableReferences(
                                db,
                                table,
                                p0,
                              ).feedingEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.animalId == item.id,
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

typedef $$AnimalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AnimalsTable,
      Animal,
      $$AnimalsTableFilterComposer,
      $$AnimalsTableOrderingComposer,
      $$AnimalsTableAnnotationComposer,
      $$AnimalsTableCreateCompanionBuilder,
      $$AnimalsTableUpdateCompanionBuilder,
      (Animal, $$AnimalsTableReferences),
      Animal,
      PrefetchHooks Function({
        bool boxId,
        bool pictureMediaId,
        bool feedingEventsRefs,
      })
    >;
typedef $$FeedingEventsTableCreateCompanionBuilder =
    FeedingEventsCompanion Function({
      Value<int> id,
      required int animalId,
      required DateTime fedAt,
      Value<String?> notes,
    });
typedef $$FeedingEventsTableUpdateCompanionBuilder =
    FeedingEventsCompanion Function({
      Value<int> id,
      Value<int> animalId,
      Value<DateTime> fedAt,
      Value<String?> notes,
    });

final class $$FeedingEventsTableReferences
    extends BaseReferences<_$AppDatabase, $FeedingEventsTable, FeedingEvent> {
  $$FeedingEventsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AnimalsTable _animalIdTable(_$AppDatabase db) =>
      db.animals.createAlias('feeding_events__animal_id__animals__id');

  $$AnimalsTableProcessedTableManager get animalId {
    final $_column = $_itemColumn<int>('animal_id')!;

    final manager = $$AnimalsTableTableManager(
      $_db,
      $_db.animals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_animalIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FeedingEventsTableFilterComposer
    extends Composer<_$AppDatabase, $FeedingEventsTable> {
  $$FeedingEventsTableFilterComposer({
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

  ColumnFilters<DateTime> get fedAt => $composableBuilder(
    column: $table.fedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$AnimalsTableFilterComposer get animalId {
    final $$AnimalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.animalId,
      referencedTable: $db.animals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnimalsTableFilterComposer(
            $db: $db,
            $table: $db.animals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FeedingEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $FeedingEventsTable> {
  $$FeedingEventsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get fedAt => $composableBuilder(
    column: $table.fedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$AnimalsTableOrderingComposer get animalId {
    final $$AnimalsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.animalId,
      referencedTable: $db.animals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnimalsTableOrderingComposer(
            $db: $db,
            $table: $db.animals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FeedingEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FeedingEventsTable> {
  $$FeedingEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get fedAt =>
      $composableBuilder(column: $table.fedAt, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$AnimalsTableAnnotationComposer get animalId {
    final $$AnimalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.animalId,
      referencedTable: $db.animals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnimalsTableAnnotationComposer(
            $db: $db,
            $table: $db.animals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FeedingEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FeedingEventsTable,
          FeedingEvent,
          $$FeedingEventsTableFilterComposer,
          $$FeedingEventsTableOrderingComposer,
          $$FeedingEventsTableAnnotationComposer,
          $$FeedingEventsTableCreateCompanionBuilder,
          $$FeedingEventsTableUpdateCompanionBuilder,
          (FeedingEvent, $$FeedingEventsTableReferences),
          FeedingEvent,
          PrefetchHooks Function({bool animalId})
        > {
  $$FeedingEventsTableTableManager(_$AppDatabase db, $FeedingEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FeedingEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FeedingEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FeedingEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> animalId = const Value.absent(),
                Value<DateTime> fedAt = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => FeedingEventsCompanion(
                id: id,
                animalId: animalId,
                fedAt: fedAt,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int animalId,
                required DateTime fedAt,
                Value<String?> notes = const Value.absent(),
              }) => FeedingEventsCompanion.insert(
                id: id,
                animalId: animalId,
                fedAt: fedAt,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FeedingEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({animalId = false}) {
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
                    if (animalId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.animalId,
                        referencedTable: $$FeedingEventsTableReferences
                            ._animalIdTable(db),
                        referencedColumn: $$FeedingEventsTableReferences
                            ._animalIdTable(db)
                            .id,
                      ) as T;
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

typedef $$FeedingEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FeedingEventsTable,
      FeedingEvent,
      $$FeedingEventsTableFilterComposer,
      $$FeedingEventsTableOrderingComposer,
      $$FeedingEventsTableAnnotationComposer,
      $$FeedingEventsTableCreateCompanionBuilder,
      $$FeedingEventsTableUpdateCompanionBuilder,
      (FeedingEvent, $$FeedingEventsTableReferences),
      FeedingEvent,
      PrefetchHooks Function({bool animalId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MediaAssetsTableTableManager get mediaAssets =>
      $$MediaAssetsTableTableManager(_db, _db.mediaAssets);
  $$BoxesTableTableManager get boxes =>
      $$BoxesTableTableManager(_db, _db.boxes);
  $$AnimalsTableTableManager get animals =>
      $$AnimalsTableTableManager(_db, _db.animals);
  $$FeedingEventsTableTableManager get feedingEvents =>
      $$FeedingEventsTableTableManager(_db, _db.feedingEvents);
}
