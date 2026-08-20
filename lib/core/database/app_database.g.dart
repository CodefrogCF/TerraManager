// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $BoxesTable extends Boxes with TableInfo<$BoxesTable, Boxe> {
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
  List<GeneratedColumn> get $columns => [id, qrId, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'boxes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Boxe> instance, {
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
  Boxe map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Boxe(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      qrId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}qr_id'],
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
  $BoxesTable createAlias(String alias) {
    return $BoxesTable(attachedDatabase, alias);
  }
}

class Boxe extends DataClass implements Insertable<Boxe> {
  final int id;
  final String qrId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Boxe({
    required this.id,
    required this.qrId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['qr_id'] = Variable<String>(qrId);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BoxesCompanion toCompanion(bool nullToAbsent) {
    return BoxesCompanion(
      id: Value(id),
      qrId: Value(qrId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Boxe.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Boxe(
      id: serializer.fromJson<int>(json['id']),
      qrId: serializer.fromJson<String>(json['qrId']),
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
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Boxe copyWith({
    int? id,
    String? qrId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Boxe(
    id: id ?? this.id,
    qrId: qrId ?? this.qrId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Boxe copyWithCompanion(BoxesCompanion data) {
    return Boxe(
      id: data.id.present ? data.id.value : this.id,
      qrId: data.qrId.present ? data.qrId.value : this.qrId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Boxe(')
          ..write('id: $id, ')
          ..write('qrId: $qrId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, qrId, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Boxe &&
          other.id == this.id &&
          other.qrId == this.qrId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BoxesCompanion extends UpdateCompanion<Boxe> {
  final Value<int> id;
  final Value<String> qrId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const BoxesCompanion({
    this.id = const Value.absent(),
    this.qrId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  BoxesCompanion.insert({
    this.id = const Value.absent(),
    required String qrId,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : qrId = Value(qrId);
  static Insertable<Boxe> custom({
    Expression<int>? id,
    Expression<String>? qrId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (qrId != null) 'qr_id': qrId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  BoxesCompanion copyWith({
    Value<int>? id,
    Value<String>? qrId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return BoxesCompanion(
      id: id ?? this.id,
      qrId: qrId ?? this.qrId,
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
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES boxes (id)',
    ),
  );
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
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
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
    notes,
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
    } else if (isInserting) {
      context.missing(_boxIdMeta);
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
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
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
      )!,
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
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
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

  static TypeConverter<Sex, String> $convertersex = const SexConverter();
  static TypeConverter<Sex?, String?> $convertersexn =
      NullAwareTypeConverter.wrap($convertersex);
  static TypeConverter<BirthDateAccuracy, String> $converterbirthDateAccuracy =
      const BirthDateAccuracyConverter();
  static TypeConverter<BirthDateAccuracy?, String?>
  $converterbirthDateAccuracyn = NullAwareTypeConverter.wrap(
    $converterbirthDateAccuracy,
  );
}

class Animal extends DataClass implements Insertable<Animal> {
  final int id;
  final int boxId;
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
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Animal({
    required this.id,
    required this.boxId,
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
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['box_id'] = Variable<int>(boxId);
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
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AnimalsCompanion toCompanion(bool nullToAbsent) {
    return AnimalsCompanion(
      id: Value(id),
      boxId: Value(boxId),
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
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
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
      boxId: serializer.fromJson<int>(json['boxId']),
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
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'boxId': serializer.toJson<int>(boxId),
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
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Animal copyWith({
    int? id,
    int? boxId,
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
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Animal(
    id: id ?? this.id,
    boxId: boxId ?? this.boxId,
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
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Animal copyWithCompanion(AnimalsCompanion data) {
    return Animal(
      id: data.id.present ? data.id.value : this.id,
      boxId: data.boxId.present ? data.boxId.value : this.boxId,
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
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Animal(')
          ..write('id: $id, ')
          ..write('boxId: $boxId, ')
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
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    boxId,
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
    notes,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Animal &&
          other.id == this.id &&
          other.boxId == this.boxId &&
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
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AnimalsCompanion extends UpdateCompanion<Animal> {
  final Value<int> id;
  final Value<int> boxId;
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
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const AnimalsCompanion({
    this.id = const Value.absent(),
    this.boxId = const Value.absent(),
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
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AnimalsCompanion.insert({
    this.id = const Value.absent(),
    required int boxId,
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
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : boxId = Value(boxId),
       commonName = Value(commonName),
       latinName = Value(latinName),
       tempMin = Value(tempMin),
       tempMax = Value(tempMax),
       humidityMin = Value(humidityMin),
       humidityMax = Value(humidityMax);
  static Insertable<Animal> custom({
    Expression<int>? id,
    Expression<int>? boxId,
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
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (boxId != null) 'box_id': boxId,
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
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AnimalsCompanion copyWith({
    Value<int>? id,
    Value<int>? boxId,
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
    Value<String?>? notes,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return AnimalsCompanion(
      id: id ?? this.id,
      boxId: boxId ?? this.boxId,
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
      notes: notes ?? this.notes,
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
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
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
          ..write('notes: $notes, ')
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
  late final $BoxesTable boxes = $BoxesTable(this);
  late final $AnimalsTable animals = $AnimalsTable(this);
  late final $FeedingEventsTable feedingEvents = $FeedingEventsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    boxes,
    animals,
    feedingEvents,
  ];
}

typedef $$BoxesTableCreateCompanionBuilder = BoxesCompanion Function({
  Value<int> id,
  required String qrId,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$BoxesTableUpdateCompanionBuilder = BoxesCompanion Function({
  Value<int> id,
  Value<String> qrId,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$BoxesTableReferences
    extends BaseReferences<_$AppDatabase, $BoxesTable, Boxe> {
  $$BoxesTableReferences(super.$_db, super.$_table, super.$_typedResult);

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

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

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

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
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

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

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
          Boxe,
          $$BoxesTableFilterComposer,
          $$BoxesTableOrderingComposer,
          $$BoxesTableAnnotationComposer,
          $$BoxesTableCreateCompanionBuilder,
          $$BoxesTableUpdateCompanionBuilder,
          (Boxe, $$BoxesTableReferences),
          Boxe,
          PrefetchHooks Function({bool animalsRefs})
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
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => BoxesCompanion(
                id: id,
                qrId: qrId,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String qrId,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => BoxesCompanion.insert(
                id: id,
                qrId: qrId,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$BoxesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({animalsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (animalsRefs) db.animals],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (animalsRefs)
                    await $_getPrefetchedData<Boxe, $BoxesTable, Animal>(
                      currentTable: table,
                      referencedTable: $$BoxesTableReferences._animalsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$BoxesTableReferences(db, table, p0).animalsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.boxId == item.id),
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
      Boxe,
      $$BoxesTableFilterComposer,
      $$BoxesTableOrderingComposer,
      $$BoxesTableAnnotationComposer,
      $$BoxesTableCreateCompanionBuilder,
      $$BoxesTableUpdateCompanionBuilder,
      (Boxe, $$BoxesTableReferences),
      Boxe,
      PrefetchHooks Function({bool animalsRefs})
    >;
typedef $$AnimalsTableCreateCompanionBuilder = AnimalsCompanion Function({
  Value<int> id,
  required int boxId,
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
  Value<String?> notes,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$AnimalsTableUpdateCompanionBuilder = AnimalsCompanion Function({
  Value<int> id,
  Value<int> boxId,
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
  Value<String?> notes,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$AnimalsTableReferences
    extends BaseReferences<_$AppDatabase, $AnimalsTable, Animal> {
  $$AnimalsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BoxesTable _boxIdTable(_$AppDatabase db) =>
      db.boxes.createAlias('animals__box_id__boxes__id');

  $$BoxesTableProcessedTableManager get boxId {
    final $_column = $_itemColumn<int>('box_id')!;

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
          PrefetchHooks Function({bool boxId, bool feedingEventsRefs})
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
                Value<int> boxId = const Value.absent(),
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
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AnimalsCompanion(
                id: id,
                boxId: boxId,
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
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int boxId,
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
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AnimalsCompanion.insert(
                id: id,
                boxId: boxId,
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
                notes: notes,
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
          prefetchHooksCallback: ({boxId = false, feedingEventsRefs = false}) {
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
                        referencedTable: $$AnimalsTableReferences._boxIdTable(
                          db,
                        ),
                        referencedColumn: $$AnimalsTableReferences
                            ._boxIdTable(db)
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
                      managerFromTypedResult: (p0) => $$AnimalsTableReferences(
                        db,
                        table,
                        p0,
                      ).feedingEventsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.animalId == item.id),
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
      PrefetchHooks Function({bool boxId, bool feedingEventsRefs})
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
  $$BoxesTableTableManager get boxes =>
      $$BoxesTableTableManager(_db, _db.boxes);
  $$AnimalsTableTableManager get animals =>
      $$AnimalsTableTableManager(_db, _db.animals);
  $$FeedingEventsTableTableManager get feedingEvents =>
      $$FeedingEventsTableTableManager(_db, _db.feedingEvents);
}
