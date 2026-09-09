// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $BanksTable extends Banks with TableInfo<$BanksTable, Bank> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BanksTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _logoUriMeta = const VerificationMeta(
    'logoUri',
  );
  @override
  late final GeneratedColumn<String> logoUri = GeneratedColumn<String>(
    'logo_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isCustomMeta = const VerificationMeta(
    'isCustom',
  );
  @override
  late final GeneratedColumn<bool> isCustom = GeneratedColumn<bool>(
    'is_custom',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_custom" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, logoUri, isCustom];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'banks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Bank> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('logo_uri')) {
      context.handle(
        _logoUriMeta,
        logoUri.isAcceptableOrUnknown(data['logo_uri']!, _logoUriMeta),
      );
    }
    if (data.containsKey('is_custom')) {
      context.handle(
        _isCustomMeta,
        isCustom.isAcceptableOrUnknown(data['is_custom']!, _isCustomMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Bank map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bank(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      logoUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}logo_uri'],
      ),
      isCustom: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_custom'],
      )!,
    );
  }

  @override
  $BanksTable createAlias(String alias) {
    return $BanksTable(attachedDatabase, alias);
  }
}

class Bank extends DataClass implements Insertable<Bank> {
  final int id;
  final String name;
  final String? logoUri;
  final bool isCustom;
  const Bank({
    required this.id,
    required this.name,
    this.logoUri,
    required this.isCustom,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || logoUri != null) {
      map['logo_uri'] = Variable<String>(logoUri);
    }
    map['is_custom'] = Variable<bool>(isCustom);
    return map;
  }

  BanksCompanion toCompanion(bool nullToAbsent) {
    return BanksCompanion(
      id: Value(id),
      name: Value(name),
      logoUri: logoUri == null && nullToAbsent
          ? const Value.absent()
          : Value(logoUri),
      isCustom: Value(isCustom),
    );
  }

  factory Bank.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Bank(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      logoUri: serializer.fromJson<String?>(json['logoUri']),
      isCustom: serializer.fromJson<bool>(json['isCustom']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'logoUri': serializer.toJson<String?>(logoUri),
      'isCustom': serializer.toJson<bool>(isCustom),
    };
  }

  Bank copyWith({
    int? id,
    String? name,
    Value<String?> logoUri = const Value.absent(),
    bool? isCustom,
  }) => Bank(
    id: id ?? this.id,
    name: name ?? this.name,
    logoUri: logoUri.present ? logoUri.value : this.logoUri,
    isCustom: isCustom ?? this.isCustom,
  );
  Bank copyWithCompanion(BanksCompanion data) {
    return Bank(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      logoUri: data.logoUri.present ? data.logoUri.value : this.logoUri,
      isCustom: data.isCustom.present ? data.isCustom.value : this.isCustom,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bank(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('logoUri: $logoUri, ')
          ..write('isCustom: $isCustom')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, logoUri, isCustom);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bank &&
          other.id == this.id &&
          other.name == this.name &&
          other.logoUri == this.logoUri &&
          other.isCustom == this.isCustom);
}

class BanksCompanion extends UpdateCompanion<Bank> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> logoUri;
  final Value<bool> isCustom;
  const BanksCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.logoUri = const Value.absent(),
    this.isCustom = const Value.absent(),
  });
  BanksCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.logoUri = const Value.absent(),
    this.isCustom = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Bank> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? logoUri,
    Expression<bool>? isCustom,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (logoUri != null) 'logo_uri': logoUri,
      if (isCustom != null) 'is_custom': isCustom,
    });
  }

  BanksCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? logoUri,
    Value<bool>? isCustom,
  }) {
    return BanksCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      logoUri: logoUri ?? this.logoUri,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (logoUri.present) {
      map['logo_uri'] = Variable<String>(logoUri.value);
    }
    if (isCustom.present) {
      map['is_custom'] = Variable<bool>(isCustom.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BanksCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('logoUri: $logoUri, ')
          ..write('isCustom: $isCustom')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _parentCategoryIdMeta = const VerificationMeta(
    'parentCategoryId',
  );
  @override
  late final GeneratedColumn<int> parentCategoryId = GeneratedColumn<int>(
    'parent_category_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CategoryType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CategoryType>($CategoriesTable.$convertertype);
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    parentCategoryId,
    name,
    icon,
    color,
    type,
    isDefault,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('parent_category_id')) {
      context.handle(
        _parentCategoryIdMeta,
        parentCategoryId.isAcceptableOrUnknown(
          data['parent_category_id']!,
          _parentCategoryIdMeta,
        ),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    } else if (isInserting) {
      context.missing(_iconMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      parentCategoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parent_category_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      type: $CategoriesTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CategoryType, String, String> $convertertype =
      const EnumNameConverter<CategoryType>(CategoryType.values);
}

class Category extends DataClass implements Insertable<Category> {
  final int id;
  final int? parentCategoryId;
  final String name;
  final String icon;
  final String color;
  final CategoryType type;
  final bool isDefault;
  const Category({
    required this.id,
    this.parentCategoryId,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    required this.isDefault,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || parentCategoryId != null) {
      map['parent_category_id'] = Variable<int>(parentCategoryId);
    }
    map['name'] = Variable<String>(name);
    map['icon'] = Variable<String>(icon);
    map['color'] = Variable<String>(color);
    {
      map['type'] = Variable<String>(
        $CategoriesTable.$convertertype.toSql(type),
      );
    }
    map['is_default'] = Variable<bool>(isDefault);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      parentCategoryId: parentCategoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentCategoryId),
      name: Value(name),
      icon: Value(icon),
      color: Value(color),
      type: Value(type),
      isDefault: Value(isDefault),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<int>(json['id']),
      parentCategoryId: serializer.fromJson<int?>(json['parentCategoryId']),
      name: serializer.fromJson<String>(json['name']),
      icon: serializer.fromJson<String>(json['icon']),
      color: serializer.fromJson<String>(json['color']),
      type: $CategoriesTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'parentCategoryId': serializer.toJson<int?>(parentCategoryId),
      'name': serializer.toJson<String>(name),
      'icon': serializer.toJson<String>(icon),
      'color': serializer.toJson<String>(color),
      'type': serializer.toJson<String>(
        $CategoriesTable.$convertertype.toJson(type),
      ),
      'isDefault': serializer.toJson<bool>(isDefault),
    };
  }

  Category copyWith({
    int? id,
    Value<int?> parentCategoryId = const Value.absent(),
    String? name,
    String? icon,
    String? color,
    CategoryType? type,
    bool? isDefault,
  }) => Category(
    id: id ?? this.id,
    parentCategoryId: parentCategoryId.present
        ? parentCategoryId.value
        : this.parentCategoryId,
    name: name ?? this.name,
    icon: icon ?? this.icon,
    color: color ?? this.color,
    type: type ?? this.type,
    isDefault: isDefault ?? this.isDefault,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      parentCategoryId: data.parentCategoryId.present
          ? data.parentCategoryId.value
          : this.parentCategoryId,
      name: data.name.present ? data.name.value : this.name,
      icon: data.icon.present ? data.icon.value : this.icon,
      color: data.color.present ? data.color.value : this.color,
      type: data.type.present ? data.type.value : this.type,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('parentCategoryId: $parentCategoryId, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('type: $type, ')
          ..write('isDefault: $isDefault')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, parentCategoryId, name, icon, color, type, isDefault);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.parentCategoryId == this.parentCategoryId &&
          other.name == this.name &&
          other.icon == this.icon &&
          other.color == this.color &&
          other.type == this.type &&
          other.isDefault == this.isDefault);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<int> id;
  final Value<int?> parentCategoryId;
  final Value<String> name;
  final Value<String> icon;
  final Value<String> color;
  final Value<CategoryType> type;
  final Value<bool> isDefault;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.parentCategoryId = const Value.absent(),
    this.name = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.type = const Value.absent(),
    this.isDefault = const Value.absent(),
  });
  CategoriesCompanion.insert({
    this.id = const Value.absent(),
    this.parentCategoryId = const Value.absent(),
    required String name,
    required String icon,
    required String color,
    required CategoryType type,
    this.isDefault = const Value.absent(),
  }) : name = Value(name),
       icon = Value(icon),
       color = Value(color),
       type = Value(type);
  static Insertable<Category> custom({
    Expression<int>? id,
    Expression<int>? parentCategoryId,
    Expression<String>? name,
    Expression<String>? icon,
    Expression<String>? color,
    Expression<String>? type,
    Expression<bool>? isDefault,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (parentCategoryId != null) 'parent_category_id': parentCategoryId,
      if (name != null) 'name': name,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      if (type != null) 'type': type,
      if (isDefault != null) 'is_default': isDefault,
    });
  }

  CategoriesCompanion copyWith({
    Value<int>? id,
    Value<int?>? parentCategoryId,
    Value<String>? name,
    Value<String>? icon,
    Value<String>? color,
    Value<CategoryType>? type,
    Value<bool>? isDefault,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      parentCategoryId: parentCategoryId ?? this.parentCategoryId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (parentCategoryId.present) {
      map['parent_category_id'] = Variable<int>(parentCategoryId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $CategoriesTable.$convertertype.toSql(type.value),
      );
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('parentCategoryId: $parentCategoryId, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('type: $type, ')
          ..write('isDefault: $isDefault')
          ..write(')'))
        .toString();
  }
}

class $CardsTable extends Cards with TableInfo<$CardsTable, Card> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _bankIdMeta = const VerificationMeta('bankId');
  @override
  late final GeneratedColumn<int> bankId = GeneratedColumn<int>(
    'bank_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES banks (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<CardType, String> cardType =
      GeneratedColumn<String>(
        'card_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CardType>($CardsTable.$convertercardType);
  @override
  late final GeneratedColumnWithTypeConverter<CardCategory, String>
  cardCategory = GeneratedColumn<String>(
    'card_category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<CardCategory>($CardsTable.$convertercardCategory);
  static const VerificationMeta _nicknameMeta = const VerificationMeta(
    'nickname',
  );
  @override
  late final GeneratedColumn<String> nickname = GeneratedColumn<String>(
    'nickname',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _last4DigitsMeta = const VerificationMeta(
    'last4Digits',
  );
  @override
  late final GeneratedColumn<String> last4Digits = GeneratedColumn<String>(
    'last4_digits',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 4,
      maxTextLength: 4,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueDateDayMeta = const VerificationMeta(
    'dueDateDay',
  );
  @override
  late final GeneratedColumn<int> dueDateDay = GeneratedColumn<int>(
    'due_date_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statementDateDayMeta = const VerificationMeta(
    'statementDateDay',
  );
  @override
  late final GeneratedColumn<int> statementDateDay = GeneratedColumn<int>(
    'statement_date_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _creditLimitMeta = const VerificationMeta(
    'creditLimit',
  );
  @override
  late final GeneratedColumn<double> creditLimit = GeneratedColumn<double>(
    'credit_limit',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bankId,
    cardType,
    cardCategory,
    nickname,
    last4Digits,
    dueDateDay,
    statementDateDay,
    creditLimit,
    color,
    isActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<Card> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('bank_id')) {
      context.handle(
        _bankIdMeta,
        bankId.isAcceptableOrUnknown(data['bank_id']!, _bankIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bankIdMeta);
    }
    if (data.containsKey('nickname')) {
      context.handle(
        _nicknameMeta,
        nickname.isAcceptableOrUnknown(data['nickname']!, _nicknameMeta),
      );
    } else if (isInserting) {
      context.missing(_nicknameMeta);
    }
    if (data.containsKey('last4_digits')) {
      context.handle(
        _last4DigitsMeta,
        last4Digits.isAcceptableOrUnknown(
          data['last4_digits']!,
          _last4DigitsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_last4DigitsMeta);
    }
    if (data.containsKey('due_date_day')) {
      context.handle(
        _dueDateDayMeta,
        dueDateDay.isAcceptableOrUnknown(
          data['due_date_day']!,
          _dueDateDayMeta,
        ),
      );
    }
    if (data.containsKey('statement_date_day')) {
      context.handle(
        _statementDateDayMeta,
        statementDateDay.isAcceptableOrUnknown(
          data['statement_date_day']!,
          _statementDateDayMeta,
        ),
      );
    }
    if (data.containsKey('credit_limit')) {
      context.handle(
        _creditLimitMeta,
        creditLimit.isAcceptableOrUnknown(
          data['credit_limit']!,
          _creditLimitMeta,
        ),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Card map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Card(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bankId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bank_id'],
      )!,
      cardType: $CardsTable.$convertercardType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}card_type'],
        )!,
      ),
      cardCategory: $CardsTable.$convertercardCategory.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}card_category'],
        )!,
      ),
      nickname: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nickname'],
      )!,
      last4Digits: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last4_digits'],
      )!,
      dueDateDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_date_day'],
      ),
      statementDateDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}statement_date_day'],
      ),
      creditLimit: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}credit_limit'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  $CardsTable createAlias(String alias) {
    return $CardsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CardType, String, String> $convertercardType =
      const EnumNameConverter<CardType>(CardType.values);
  static JsonTypeConverter2<CardCategory, String, String>
  $convertercardCategory = const EnumNameConverter<CardCategory>(
    CardCategory.values,
  );
}

class Card extends DataClass implements Insertable<Card> {
  final int id;
  final int bankId;
  final CardType cardType;
  final CardCategory cardCategory;
  final String nickname;
  final String last4Digits;

  /// Day-of-month (1-31), credit cards only. Clamped to each month's real last day at use.
  final int? dueDateDay;
  final int? statementDateDay;
  final double? creditLimit;

  /// Rotates through AppSemanticColors.cardColorRotation at creation; user-editable later.
  final String color;
  final bool isActive;
  const Card({
    required this.id,
    required this.bankId,
    required this.cardType,
    required this.cardCategory,
    required this.nickname,
    required this.last4Digits,
    this.dueDateDay,
    this.statementDateDay,
    this.creditLimit,
    required this.color,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['bank_id'] = Variable<int>(bankId);
    {
      map['card_type'] = Variable<String>(
        $CardsTable.$convertercardType.toSql(cardType),
      );
    }
    {
      map['card_category'] = Variable<String>(
        $CardsTable.$convertercardCategory.toSql(cardCategory),
      );
    }
    map['nickname'] = Variable<String>(nickname);
    map['last4_digits'] = Variable<String>(last4Digits);
    if (!nullToAbsent || dueDateDay != null) {
      map['due_date_day'] = Variable<int>(dueDateDay);
    }
    if (!nullToAbsent || statementDateDay != null) {
      map['statement_date_day'] = Variable<int>(statementDateDay);
    }
    if (!nullToAbsent || creditLimit != null) {
      map['credit_limit'] = Variable<double>(creditLimit);
    }
    map['color'] = Variable<String>(color);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  CardsCompanion toCompanion(bool nullToAbsent) {
    return CardsCompanion(
      id: Value(id),
      bankId: Value(bankId),
      cardType: Value(cardType),
      cardCategory: Value(cardCategory),
      nickname: Value(nickname),
      last4Digits: Value(last4Digits),
      dueDateDay: dueDateDay == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDateDay),
      statementDateDay: statementDateDay == null && nullToAbsent
          ? const Value.absent()
          : Value(statementDateDay),
      creditLimit: creditLimit == null && nullToAbsent
          ? const Value.absent()
          : Value(creditLimit),
      color: Value(color),
      isActive: Value(isActive),
    );
  }

  factory Card.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Card(
      id: serializer.fromJson<int>(json['id']),
      bankId: serializer.fromJson<int>(json['bankId']),
      cardType: $CardsTable.$convertercardType.fromJson(
        serializer.fromJson<String>(json['cardType']),
      ),
      cardCategory: $CardsTable.$convertercardCategory.fromJson(
        serializer.fromJson<String>(json['cardCategory']),
      ),
      nickname: serializer.fromJson<String>(json['nickname']),
      last4Digits: serializer.fromJson<String>(json['last4Digits']),
      dueDateDay: serializer.fromJson<int?>(json['dueDateDay']),
      statementDateDay: serializer.fromJson<int?>(json['statementDateDay']),
      creditLimit: serializer.fromJson<double?>(json['creditLimit']),
      color: serializer.fromJson<String>(json['color']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bankId': serializer.toJson<int>(bankId),
      'cardType': serializer.toJson<String>(
        $CardsTable.$convertercardType.toJson(cardType),
      ),
      'cardCategory': serializer.toJson<String>(
        $CardsTable.$convertercardCategory.toJson(cardCategory),
      ),
      'nickname': serializer.toJson<String>(nickname),
      'last4Digits': serializer.toJson<String>(last4Digits),
      'dueDateDay': serializer.toJson<int?>(dueDateDay),
      'statementDateDay': serializer.toJson<int?>(statementDateDay),
      'creditLimit': serializer.toJson<double?>(creditLimit),
      'color': serializer.toJson<String>(color),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  Card copyWith({
    int? id,
    int? bankId,
    CardType? cardType,
    CardCategory? cardCategory,
    String? nickname,
    String? last4Digits,
    Value<int?> dueDateDay = const Value.absent(),
    Value<int?> statementDateDay = const Value.absent(),
    Value<double?> creditLimit = const Value.absent(),
    String? color,
    bool? isActive,
  }) => Card(
    id: id ?? this.id,
    bankId: bankId ?? this.bankId,
    cardType: cardType ?? this.cardType,
    cardCategory: cardCategory ?? this.cardCategory,
    nickname: nickname ?? this.nickname,
    last4Digits: last4Digits ?? this.last4Digits,
    dueDateDay: dueDateDay.present ? dueDateDay.value : this.dueDateDay,
    statementDateDay: statementDateDay.present
        ? statementDateDay.value
        : this.statementDateDay,
    creditLimit: creditLimit.present ? creditLimit.value : this.creditLimit,
    color: color ?? this.color,
    isActive: isActive ?? this.isActive,
  );
  Card copyWithCompanion(CardsCompanion data) {
    return Card(
      id: data.id.present ? data.id.value : this.id,
      bankId: data.bankId.present ? data.bankId.value : this.bankId,
      cardType: data.cardType.present ? data.cardType.value : this.cardType,
      cardCategory: data.cardCategory.present
          ? data.cardCategory.value
          : this.cardCategory,
      nickname: data.nickname.present ? data.nickname.value : this.nickname,
      last4Digits: data.last4Digits.present
          ? data.last4Digits.value
          : this.last4Digits,
      dueDateDay: data.dueDateDay.present
          ? data.dueDateDay.value
          : this.dueDateDay,
      statementDateDay: data.statementDateDay.present
          ? data.statementDateDay.value
          : this.statementDateDay,
      creditLimit: data.creditLimit.present
          ? data.creditLimit.value
          : this.creditLimit,
      color: data.color.present ? data.color.value : this.color,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Card(')
          ..write('id: $id, ')
          ..write('bankId: $bankId, ')
          ..write('cardType: $cardType, ')
          ..write('cardCategory: $cardCategory, ')
          ..write('nickname: $nickname, ')
          ..write('last4Digits: $last4Digits, ')
          ..write('dueDateDay: $dueDateDay, ')
          ..write('statementDateDay: $statementDateDay, ')
          ..write('creditLimit: $creditLimit, ')
          ..write('color: $color, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bankId,
    cardType,
    cardCategory,
    nickname,
    last4Digits,
    dueDateDay,
    statementDateDay,
    creditLimit,
    color,
    isActive,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Card &&
          other.id == this.id &&
          other.bankId == this.bankId &&
          other.cardType == this.cardType &&
          other.cardCategory == this.cardCategory &&
          other.nickname == this.nickname &&
          other.last4Digits == this.last4Digits &&
          other.dueDateDay == this.dueDateDay &&
          other.statementDateDay == this.statementDateDay &&
          other.creditLimit == this.creditLimit &&
          other.color == this.color &&
          other.isActive == this.isActive);
}

class CardsCompanion extends UpdateCompanion<Card> {
  final Value<int> id;
  final Value<int> bankId;
  final Value<CardType> cardType;
  final Value<CardCategory> cardCategory;
  final Value<String> nickname;
  final Value<String> last4Digits;
  final Value<int?> dueDateDay;
  final Value<int?> statementDateDay;
  final Value<double?> creditLimit;
  final Value<String> color;
  final Value<bool> isActive;
  const CardsCompanion({
    this.id = const Value.absent(),
    this.bankId = const Value.absent(),
    this.cardType = const Value.absent(),
    this.cardCategory = const Value.absent(),
    this.nickname = const Value.absent(),
    this.last4Digits = const Value.absent(),
    this.dueDateDay = const Value.absent(),
    this.statementDateDay = const Value.absent(),
    this.creditLimit = const Value.absent(),
    this.color = const Value.absent(),
    this.isActive = const Value.absent(),
  });
  CardsCompanion.insert({
    this.id = const Value.absent(),
    required int bankId,
    required CardType cardType,
    required CardCategory cardCategory,
    required String nickname,
    required String last4Digits,
    this.dueDateDay = const Value.absent(),
    this.statementDateDay = const Value.absent(),
    this.creditLimit = const Value.absent(),
    required String color,
    this.isActive = const Value.absent(),
  }) : bankId = Value(bankId),
       cardType = Value(cardType),
       cardCategory = Value(cardCategory),
       nickname = Value(nickname),
       last4Digits = Value(last4Digits),
       color = Value(color);
  static Insertable<Card> custom({
    Expression<int>? id,
    Expression<int>? bankId,
    Expression<String>? cardType,
    Expression<String>? cardCategory,
    Expression<String>? nickname,
    Expression<String>? last4Digits,
    Expression<int>? dueDateDay,
    Expression<int>? statementDateDay,
    Expression<double>? creditLimit,
    Expression<String>? color,
    Expression<bool>? isActive,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bankId != null) 'bank_id': bankId,
      if (cardType != null) 'card_type': cardType,
      if (cardCategory != null) 'card_category': cardCategory,
      if (nickname != null) 'nickname': nickname,
      if (last4Digits != null) 'last4_digits': last4Digits,
      if (dueDateDay != null) 'due_date_day': dueDateDay,
      if (statementDateDay != null) 'statement_date_day': statementDateDay,
      if (creditLimit != null) 'credit_limit': creditLimit,
      if (color != null) 'color': color,
      if (isActive != null) 'is_active': isActive,
    });
  }

  CardsCompanion copyWith({
    Value<int>? id,
    Value<int>? bankId,
    Value<CardType>? cardType,
    Value<CardCategory>? cardCategory,
    Value<String>? nickname,
    Value<String>? last4Digits,
    Value<int?>? dueDateDay,
    Value<int?>? statementDateDay,
    Value<double?>? creditLimit,
    Value<String>? color,
    Value<bool>? isActive,
  }) {
    return CardsCompanion(
      id: id ?? this.id,
      bankId: bankId ?? this.bankId,
      cardType: cardType ?? this.cardType,
      cardCategory: cardCategory ?? this.cardCategory,
      nickname: nickname ?? this.nickname,
      last4Digits: last4Digits ?? this.last4Digits,
      dueDateDay: dueDateDay ?? this.dueDateDay,
      statementDateDay: statementDateDay ?? this.statementDateDay,
      creditLimit: creditLimit ?? this.creditLimit,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bankId.present) {
      map['bank_id'] = Variable<int>(bankId.value);
    }
    if (cardType.present) {
      map['card_type'] = Variable<String>(
        $CardsTable.$convertercardType.toSql(cardType.value),
      );
    }
    if (cardCategory.present) {
      map['card_category'] = Variable<String>(
        $CardsTable.$convertercardCategory.toSql(cardCategory.value),
      );
    }
    if (nickname.present) {
      map['nickname'] = Variable<String>(nickname.value);
    }
    if (last4Digits.present) {
      map['last4_digits'] = Variable<String>(last4Digits.value);
    }
    if (dueDateDay.present) {
      map['due_date_day'] = Variable<int>(dueDateDay.value);
    }
    if (statementDateDay.present) {
      map['statement_date_day'] = Variable<int>(statementDateDay.value);
    }
    if (creditLimit.present) {
      map['credit_limit'] = Variable<double>(creditLimit.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardsCompanion(')
          ..write('id: $id, ')
          ..write('bankId: $bankId, ')
          ..write('cardType: $cardType, ')
          ..write('cardCategory: $cardCategory, ')
          ..write('nickname: $nickname, ')
          ..write('last4Digits: $last4Digits, ')
          ..write('dueDateDay: $dueDateDay, ')
          ..write('statementDateDay: $statementDateDay, ')
          ..write('creditLimit: $creditLimit, ')
          ..write('color: $color, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }
}

class $BeneficiariesTable extends Beneficiaries
    with TableInfo<$BeneficiariesTable, Beneficiary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BeneficiariesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _lastUsedAtMeta = const VerificationMeta(
    'lastUsedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastUsedAt = GeneratedColumn<DateTime>(
    'last_used_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, lastUsedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'beneficiaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<Beneficiary> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('last_used_at')) {
      context.handle(
        _lastUsedAtMeta,
        lastUsedAt.isAcceptableOrUnknown(
          data['last_used_at']!,
          _lastUsedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastUsedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Beneficiary map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Beneficiary(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      lastUsedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_used_at'],
      )!,
    );
  }

  @override
  $BeneficiariesTable createAlias(String alias) {
    return $BeneficiariesTable(attachedDatabase, alias);
  }
}

class Beneficiary extends DataClass implements Insertable<Beneficiary> {
  final int id;
  final String name;
  final DateTime lastUsedAt;
  const Beneficiary({
    required this.id,
    required this.name,
    required this.lastUsedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['last_used_at'] = Variable<DateTime>(lastUsedAt);
    return map;
  }

  BeneficiariesCompanion toCompanion(bool nullToAbsent) {
    return BeneficiariesCompanion(
      id: Value(id),
      name: Value(name),
      lastUsedAt: Value(lastUsedAt),
    );
  }

  factory Beneficiary.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Beneficiary(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      lastUsedAt: serializer.fromJson<DateTime>(json['lastUsedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'lastUsedAt': serializer.toJson<DateTime>(lastUsedAt),
    };
  }

  Beneficiary copyWith({int? id, String? name, DateTime? lastUsedAt}) =>
      Beneficiary(
        id: id ?? this.id,
        name: name ?? this.name,
        lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      );
  Beneficiary copyWithCompanion(BeneficiariesCompanion data) {
    return Beneficiary(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      lastUsedAt: data.lastUsedAt.present
          ? data.lastUsedAt.value
          : this.lastUsedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Beneficiary(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('lastUsedAt: $lastUsedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, lastUsedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Beneficiary &&
          other.id == this.id &&
          other.name == this.name &&
          other.lastUsedAt == this.lastUsedAt);
}

class BeneficiariesCompanion extends UpdateCompanion<Beneficiary> {
  final Value<int> id;
  final Value<String> name;
  final Value<DateTime> lastUsedAt;
  const BeneficiariesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
  });
  BeneficiariesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required DateTime lastUsedAt,
  }) : name = Value(name),
       lastUsedAt = Value(lastUsedAt);
  static Insertable<Beneficiary> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<DateTime>? lastUsedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
    });
  }

  BeneficiariesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<DateTime>? lastUsedAt,
  }) {
    return BeneficiariesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (lastUsedAt.present) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BeneficiariesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('lastUsedAt: $lastUsedAt')
          ..write(')'))
        .toString();
  }
}

class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, Transaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TransactionType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TransactionType>($TransactionsTable.$convertertype);
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<PaymentMethodType, String>
  paymentMethodType =
      GeneratedColumn<String>(
        'payment_method_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<PaymentMethodType>(
        $TransactionsTable.$converterpaymentMethodType,
      );
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<int> cardId = GeneratedColumn<int>(
    'card_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cards (id)',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attachmentUriMeta = const VerificationMeta(
    'attachmentUri',
  );
  @override
  late final GeneratedColumn<String> attachmentUri = GeneratedColumn<String>(
    'attachment_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _beneficiaryNameMeta = const VerificationMeta(
    'beneficiaryName',
  );
  @override
  late final GeneratedColumn<String> beneficiaryName = GeneratedColumn<String>(
    'beneficiary_name',
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    amount,
    type,
    categoryId,
    paymentMethodType,
    cardId,
    date,
    note,
    attachmentUri,
    beneficiaryName,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Transaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('attachment_uri')) {
      context.handle(
        _attachmentUriMeta,
        attachmentUri.isAcceptableOrUnknown(
          data['attachment_uri']!,
          _attachmentUriMeta,
        ),
      );
    }
    if (data.containsKey('beneficiary_name')) {
      context.handle(
        _beneficiaryNameMeta,
        beneficiaryName.isAcceptableOrUnknown(
          data['beneficiary_name']!,
          _beneficiaryNameMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      type: $TransactionsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      )!,
      paymentMethodType: $TransactionsTable.$converterpaymentMethodType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}payment_method_type'],
        )!,
      ),
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}card_id'],
      ),
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      attachmentUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachment_uri'],
      ),
      beneficiaryName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}beneficiary_name'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TransactionType, String, String> $convertertype =
      const EnumNameConverter<TransactionType>(TransactionType.values);
  static JsonTypeConverter2<PaymentMethodType, String, String>
  $converterpaymentMethodType = const EnumNameConverter<PaymentMethodType>(
    PaymentMethodType.values,
  );
}

class Transaction extends DataClass implements Insertable<Transaction> {
  final int id;
  final double amount;
  final TransactionType type;
  final int categoryId;
  final PaymentMethodType paymentMethodType;

  /// Non-null only when paymentMethodType = card — enforced by the form validator.
  final int? cardId;

  /// Gregorian, single source of truth — Hijri display/input converts only at the UI boundary.
  final DateTime date;

  /// Free-text note; the long-press "quick note" on the list edits this same column.
  final String? note;

  /// Persistent file path in app-support storage (outside iCloud backup on iOS); one max.
  final String? attachmentUri;
  final String? beneficiaryName;
  final DateTime createdAt;
  const Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.paymentMethodType,
    this.cardId,
    required this.date,
    this.note,
    this.attachmentUri,
    this.beneficiaryName,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['amount'] = Variable<double>(amount);
    {
      map['type'] = Variable<String>(
        $TransactionsTable.$convertertype.toSql(type),
      );
    }
    map['category_id'] = Variable<int>(categoryId);
    {
      map['payment_method_type'] = Variable<String>(
        $TransactionsTable.$converterpaymentMethodType.toSql(paymentMethodType),
      );
    }
    if (!nullToAbsent || cardId != null) {
      map['card_id'] = Variable<int>(cardId);
    }
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || attachmentUri != null) {
      map['attachment_uri'] = Variable<String>(attachmentUri);
    }
    if (!nullToAbsent || beneficiaryName != null) {
      map['beneficiary_name'] = Variable<String>(beneficiaryName);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      amount: Value(amount),
      type: Value(type),
      categoryId: Value(categoryId),
      paymentMethodType: Value(paymentMethodType),
      cardId: cardId == null && nullToAbsent
          ? const Value.absent()
          : Value(cardId),
      date: Value(date),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      attachmentUri: attachmentUri == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentUri),
      beneficiaryName: beneficiaryName == null && nullToAbsent
          ? const Value.absent()
          : Value(beneficiaryName),
      createdAt: Value(createdAt),
    );
  }

  factory Transaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transaction(
      id: serializer.fromJson<int>(json['id']),
      amount: serializer.fromJson<double>(json['amount']),
      type: $TransactionsTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      categoryId: serializer.fromJson<int>(json['categoryId']),
      paymentMethodType: $TransactionsTable.$converterpaymentMethodType
          .fromJson(serializer.fromJson<String>(json['paymentMethodType'])),
      cardId: serializer.fromJson<int?>(json['cardId']),
      date: serializer.fromJson<DateTime>(json['date']),
      note: serializer.fromJson<String?>(json['note']),
      attachmentUri: serializer.fromJson<String?>(json['attachmentUri']),
      beneficiaryName: serializer.fromJson<String?>(json['beneficiaryName']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'amount': serializer.toJson<double>(amount),
      'type': serializer.toJson<String>(
        $TransactionsTable.$convertertype.toJson(type),
      ),
      'categoryId': serializer.toJson<int>(categoryId),
      'paymentMethodType': serializer.toJson<String>(
        $TransactionsTable.$converterpaymentMethodType.toJson(
          paymentMethodType,
        ),
      ),
      'cardId': serializer.toJson<int?>(cardId),
      'date': serializer.toJson<DateTime>(date),
      'note': serializer.toJson<String?>(note),
      'attachmentUri': serializer.toJson<String?>(attachmentUri),
      'beneficiaryName': serializer.toJson<String?>(beneficiaryName),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Transaction copyWith({
    int? id,
    double? amount,
    TransactionType? type,
    int? categoryId,
    PaymentMethodType? paymentMethodType,
    Value<int?> cardId = const Value.absent(),
    DateTime? date,
    Value<String?> note = const Value.absent(),
    Value<String?> attachmentUri = const Value.absent(),
    Value<String?> beneficiaryName = const Value.absent(),
    DateTime? createdAt,
  }) => Transaction(
    id: id ?? this.id,
    amount: amount ?? this.amount,
    type: type ?? this.type,
    categoryId: categoryId ?? this.categoryId,
    paymentMethodType: paymentMethodType ?? this.paymentMethodType,
    cardId: cardId.present ? cardId.value : this.cardId,
    date: date ?? this.date,
    note: note.present ? note.value : this.note,
    attachmentUri: attachmentUri.present
        ? attachmentUri.value
        : this.attachmentUri,
    beneficiaryName: beneficiaryName.present
        ? beneficiaryName.value
        : this.beneficiaryName,
    createdAt: createdAt ?? this.createdAt,
  );
  Transaction copyWithCompanion(TransactionsCompanion data) {
    return Transaction(
      id: data.id.present ? data.id.value : this.id,
      amount: data.amount.present ? data.amount.value : this.amount,
      type: data.type.present ? data.type.value : this.type,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      paymentMethodType: data.paymentMethodType.present
          ? data.paymentMethodType.value
          : this.paymentMethodType,
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      date: data.date.present ? data.date.value : this.date,
      note: data.note.present ? data.note.value : this.note,
      attachmentUri: data.attachmentUri.present
          ? data.attachmentUri.value
          : this.attachmentUri,
      beneficiaryName: data.beneficiaryName.present
          ? data.beneficiaryName.value
          : this.beneficiaryName,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transaction(')
          ..write('id: $id, ')
          ..write('amount: $amount, ')
          ..write('type: $type, ')
          ..write('categoryId: $categoryId, ')
          ..write('paymentMethodType: $paymentMethodType, ')
          ..write('cardId: $cardId, ')
          ..write('date: $date, ')
          ..write('note: $note, ')
          ..write('attachmentUri: $attachmentUri, ')
          ..write('beneficiaryName: $beneficiaryName, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    amount,
    type,
    categoryId,
    paymentMethodType,
    cardId,
    date,
    note,
    attachmentUri,
    beneficiaryName,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaction &&
          other.id == this.id &&
          other.amount == this.amount &&
          other.type == this.type &&
          other.categoryId == this.categoryId &&
          other.paymentMethodType == this.paymentMethodType &&
          other.cardId == this.cardId &&
          other.date == this.date &&
          other.note == this.note &&
          other.attachmentUri == this.attachmentUri &&
          other.beneficiaryName == this.beneficiaryName &&
          other.createdAt == this.createdAt);
}

class TransactionsCompanion extends UpdateCompanion<Transaction> {
  final Value<int> id;
  final Value<double> amount;
  final Value<TransactionType> type;
  final Value<int> categoryId;
  final Value<PaymentMethodType> paymentMethodType;
  final Value<int?> cardId;
  final Value<DateTime> date;
  final Value<String?> note;
  final Value<String?> attachmentUri;
  final Value<String?> beneficiaryName;
  final Value<DateTime> createdAt;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.amount = const Value.absent(),
    this.type = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.paymentMethodType = const Value.absent(),
    this.cardId = const Value.absent(),
    this.date = const Value.absent(),
    this.note = const Value.absent(),
    this.attachmentUri = const Value.absent(),
    this.beneficiaryName = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TransactionsCompanion.insert({
    this.id = const Value.absent(),
    required double amount,
    required TransactionType type,
    required int categoryId,
    required PaymentMethodType paymentMethodType,
    this.cardId = const Value.absent(),
    required DateTime date,
    this.note = const Value.absent(),
    this.attachmentUri = const Value.absent(),
    this.beneficiaryName = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : amount = Value(amount),
       type = Value(type),
       categoryId = Value(categoryId),
       paymentMethodType = Value(paymentMethodType),
       date = Value(date);
  static Insertable<Transaction> custom({
    Expression<int>? id,
    Expression<double>? amount,
    Expression<String>? type,
    Expression<int>? categoryId,
    Expression<String>? paymentMethodType,
    Expression<int>? cardId,
    Expression<DateTime>? date,
    Expression<String>? note,
    Expression<String>? attachmentUri,
    Expression<String>? beneficiaryName,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (amount != null) 'amount': amount,
      if (type != null) 'type': type,
      if (categoryId != null) 'category_id': categoryId,
      if (paymentMethodType != null) 'payment_method_type': paymentMethodType,
      if (cardId != null) 'card_id': cardId,
      if (date != null) 'date': date,
      if (note != null) 'note': note,
      if (attachmentUri != null) 'attachment_uri': attachmentUri,
      if (beneficiaryName != null) 'beneficiary_name': beneficiaryName,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TransactionsCompanion copyWith({
    Value<int>? id,
    Value<double>? amount,
    Value<TransactionType>? type,
    Value<int>? categoryId,
    Value<PaymentMethodType>? paymentMethodType,
    Value<int?>? cardId,
    Value<DateTime>? date,
    Value<String?>? note,
    Value<String?>? attachmentUri,
    Value<String?>? beneficiaryName,
    Value<DateTime>? createdAt,
  }) {
    return TransactionsCompanion(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      paymentMethodType: paymentMethodType ?? this.paymentMethodType,
      cardId: cardId ?? this.cardId,
      date: date ?? this.date,
      note: note ?? this.note,
      attachmentUri: attachmentUri ?? this.attachmentUri,
      beneficiaryName: beneficiaryName ?? this.beneficiaryName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $TransactionsTable.$convertertype.toSql(type.value),
      );
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (paymentMethodType.present) {
      map['payment_method_type'] = Variable<String>(
        $TransactionsTable.$converterpaymentMethodType.toSql(
          paymentMethodType.value,
        ),
      );
    }
    if (cardId.present) {
      map['card_id'] = Variable<int>(cardId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (attachmentUri.present) {
      map['attachment_uri'] = Variable<String>(attachmentUri.value);
    }
    if (beneficiaryName.present) {
      map['beneficiary_name'] = Variable<String>(beneficiaryName.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('amount: $amount, ')
          ..write('type: $type, ')
          ..write('categoryId: $categoryId, ')
          ..write('paymentMethodType: $paymentMethodType, ')
          ..write('cardId: $cardId, ')
          ..write('date: $date, ')
          ..write('note: $note, ')
          ..write('attachmentUri: $attachmentUri, ')
          ..write('beneficiaryName: $beneficiaryName, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $CategoryBudgetsTable extends CategoryBudgets
    with TableInfo<$CategoryBudgetsTable, CategoryBudget> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoryBudgetsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'UNIQUE REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _monthlyLimitMeta = const VerificationMeta(
    'monthlyLimit',
  );
  @override
  late final GeneratedColumn<double> monthlyLimit = GeneratedColumn<double>(
    'monthly_limit',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    categoryId,
    monthlyLimit,
    isEnabled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'category_budgets';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryBudget> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('monthly_limit')) {
      context.handle(
        _monthlyLimitMeta,
        monthlyLimit.isAcceptableOrUnknown(
          data['monthly_limit']!,
          _monthlyLimitMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_monthlyLimitMeta);
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoryBudget map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryBudget(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      )!,
      monthlyLimit: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}monthly_limit'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
    );
  }

  @override
  $CategoryBudgetsTable createAlias(String alias) {
    return $CategoryBudgetsTable(attachedDatabase, alias);
  }
}

class CategoryBudget extends DataClass implements Insertable<CategoryBudget> {
  final int id;
  final int categoryId;
  final double monthlyLimit;
  final bool isEnabled;
  const CategoryBudget({
    required this.id,
    required this.categoryId,
    required this.monthlyLimit,
    required this.isEnabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['category_id'] = Variable<int>(categoryId);
    map['monthly_limit'] = Variable<double>(monthlyLimit);
    map['is_enabled'] = Variable<bool>(isEnabled);
    return map;
  }

  CategoryBudgetsCompanion toCompanion(bool nullToAbsent) {
    return CategoryBudgetsCompanion(
      id: Value(id),
      categoryId: Value(categoryId),
      monthlyLimit: Value(monthlyLimit),
      isEnabled: Value(isEnabled),
    );
  }

  factory CategoryBudget.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryBudget(
      id: serializer.fromJson<int>(json['id']),
      categoryId: serializer.fromJson<int>(json['categoryId']),
      monthlyLimit: serializer.fromJson<double>(json['monthlyLimit']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'categoryId': serializer.toJson<int>(categoryId),
      'monthlyLimit': serializer.toJson<double>(monthlyLimit),
      'isEnabled': serializer.toJson<bool>(isEnabled),
    };
  }

  CategoryBudget copyWith({
    int? id,
    int? categoryId,
    double? monthlyLimit,
    bool? isEnabled,
  }) => CategoryBudget(
    id: id ?? this.id,
    categoryId: categoryId ?? this.categoryId,
    monthlyLimit: monthlyLimit ?? this.monthlyLimit,
    isEnabled: isEnabled ?? this.isEnabled,
  );
  CategoryBudget copyWithCompanion(CategoryBudgetsCompanion data) {
    return CategoryBudget(
      id: data.id.present ? data.id.value : this.id,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      monthlyLimit: data.monthlyLimit.present
          ? data.monthlyLimit.value
          : this.monthlyLimit,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryBudget(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('monthlyLimit: $monthlyLimit, ')
          ..write('isEnabled: $isEnabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, categoryId, monthlyLimit, isEnabled);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryBudget &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.monthlyLimit == this.monthlyLimit &&
          other.isEnabled == this.isEnabled);
}

class CategoryBudgetsCompanion extends UpdateCompanion<CategoryBudget> {
  final Value<int> id;
  final Value<int> categoryId;
  final Value<double> monthlyLimit;
  final Value<bool> isEnabled;
  const CategoryBudgetsCompanion({
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.monthlyLimit = const Value.absent(),
    this.isEnabled = const Value.absent(),
  });
  CategoryBudgetsCompanion.insert({
    this.id = const Value.absent(),
    required int categoryId,
    required double monthlyLimit,
    this.isEnabled = const Value.absent(),
  }) : categoryId = Value(categoryId),
       monthlyLimit = Value(monthlyLimit);
  static Insertable<CategoryBudget> custom({
    Expression<int>? id,
    Expression<int>? categoryId,
    Expression<double>? monthlyLimit,
    Expression<bool>? isEnabled,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (monthlyLimit != null) 'monthly_limit': monthlyLimit,
      if (isEnabled != null) 'is_enabled': isEnabled,
    });
  }

  CategoryBudgetsCompanion copyWith({
    Value<int>? id,
    Value<int>? categoryId,
    Value<double>? monthlyLimit,
    Value<bool>? isEnabled,
  }) {
    return CategoryBudgetsCompanion(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (monthlyLimit.present) {
      map['monthly_limit'] = Variable<double>(monthlyLimit.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoryBudgetsCompanion(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('monthlyLimit: $monthlyLimit, ')
          ..write('isEnabled: $isEnabled')
          ..write(')'))
        .toString();
  }
}

class $NotificationPreferencesTable extends NotificationPreferences
    with TableInfo<$NotificationPreferencesTable, NotificationPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _configJsonMeta = const VerificationMeta(
    'configJson',
  );
  @override
  late final GeneratedColumn<String> configJson = GeneratedColumn<String>(
    'config_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [key, isEnabled, configJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notification_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<NotificationPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('config_json')) {
      context.handle(
        _configJsonMeta,
        configJson.isAcceptableOrUnknown(data['config_json']!, _configJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  NotificationPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotificationPreference(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      configJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config_json'],
      ),
    );
  }

  @override
  $NotificationPreferencesTable createAlias(String alias) {
    return $NotificationPreferencesTable(attachedDatabase, alias);
  }
}

class NotificationPreference extends DataClass
    implements Insertable<NotificationPreference> {
  final String key;
  final bool isEnabled;

  /// JSON-encoded config specific to the key, e.g. {"daysBefore":[7,1]} or {"hour":20}.
  final String? configJson;
  const NotificationPreference({
    required this.key,
    required this.isEnabled,
    this.configJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['is_enabled'] = Variable<bool>(isEnabled);
    if (!nullToAbsent || configJson != null) {
      map['config_json'] = Variable<String>(configJson);
    }
    return map;
  }

  NotificationPreferencesCompanion toCompanion(bool nullToAbsent) {
    return NotificationPreferencesCompanion(
      key: Value(key),
      isEnabled: Value(isEnabled),
      configJson: configJson == null && nullToAbsent
          ? const Value.absent()
          : Value(configJson),
    );
  }

  factory NotificationPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotificationPreference(
      key: serializer.fromJson<String>(json['key']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      configJson: serializer.fromJson<String?>(json['configJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'configJson': serializer.toJson<String?>(configJson),
    };
  }

  NotificationPreference copyWith({
    String? key,
    bool? isEnabled,
    Value<String?> configJson = const Value.absent(),
  }) => NotificationPreference(
    key: key ?? this.key,
    isEnabled: isEnabled ?? this.isEnabled,
    configJson: configJson.present ? configJson.value : this.configJson,
  );
  NotificationPreference copyWithCompanion(
    NotificationPreferencesCompanion data,
  ) {
    return NotificationPreference(
      key: data.key.present ? data.key.value : this.key,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      configJson: data.configJson.present
          ? data.configJson.value
          : this.configJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationPreference(')
          ..write('key: $key, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('configJson: $configJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, isEnabled, configJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationPreference &&
          other.key == this.key &&
          other.isEnabled == this.isEnabled &&
          other.configJson == this.configJson);
}

class NotificationPreferencesCompanion
    extends UpdateCompanion<NotificationPreference> {
  final Value<String> key;
  final Value<bool> isEnabled;
  final Value<String?> configJson;
  final Value<int> rowid;
  const NotificationPreferencesCompanion({
    this.key = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.configJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotificationPreferencesCompanion.insert({
    required String key,
    this.isEnabled = const Value.absent(),
    this.configJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<NotificationPreference> custom({
    Expression<String>? key,
    Expression<bool>? isEnabled,
    Expression<String>? configJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (configJson != null) 'config_json': configJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotificationPreferencesCompanion copyWith({
    Value<String>? key,
    Value<bool>? isEnabled,
    Value<String?>? configJson,
    Value<int>? rowid,
  }) {
    return NotificationPreferencesCompanion(
      key: key ?? this.key,
      isEnabled: isEnabled ?? this.isEnabled,
      configJson: configJson ?? this.configJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (configJson.present) {
      map['config_json'] = Variable<String>(configJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationPreferencesCompanion(')
          ..write('key: $key, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('configJson: $configJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScheduledNotificationsTable extends ScheduledNotifications
    with TableInfo<$ScheduledNotificationsTable, ScheduledNotification> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScheduledNotificationsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<int> cardId = GeneratedColumn<int>(
    'card_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cards (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<NotificationKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<NotificationKind>(
        $ScheduledNotificationsTable.$converterkind,
      );
  static const VerificationMeta _daysBeforeMeta = const VerificationMeta(
    'daysBefore',
  );
  @override
  late final GeneratedColumn<int> daysBefore = GeneratedColumn<int>(
    'days_before',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _triggerDateMeta = const VerificationMeta(
    'triggerDate',
  );
  @override
  late final GeneratedColumn<DateTime> triggerDate = GeneratedColumn<DateTime>(
    'trigger_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _osNotificationIdMeta = const VerificationMeta(
    'osNotificationId',
  );
  @override
  late final GeneratedColumn<int> osNotificationId = GeneratedColumn<int>(
    'os_notification_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cardId,
    kind,
    daysBefore,
    triggerDate,
    osNotificationId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scheduled_notifications';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScheduledNotification> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    }
    if (data.containsKey('days_before')) {
      context.handle(
        _daysBeforeMeta,
        daysBefore.isAcceptableOrUnknown(data['days_before']!, _daysBeforeMeta),
      );
    }
    if (data.containsKey('trigger_date')) {
      context.handle(
        _triggerDateMeta,
        triggerDate.isAcceptableOrUnknown(
          data['trigger_date']!,
          _triggerDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_triggerDateMeta);
    }
    if (data.containsKey('os_notification_id')) {
      context.handle(
        _osNotificationIdMeta,
        osNotificationId.isAcceptableOrUnknown(
          data['os_notification_id']!,
          _osNotificationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_osNotificationIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScheduledNotification map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScheduledNotification(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}card_id'],
      ),
      kind: $ScheduledNotificationsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      daysBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}days_before'],
      ),
      triggerDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}trigger_date'],
      )!,
      osNotificationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}os_notification_id'],
      )!,
    );
  }

  @override
  $ScheduledNotificationsTable createAlias(String alias) {
    return $ScheduledNotificationsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<NotificationKind, String, String> $converterkind =
      const EnumNameConverter<NotificationKind>(NotificationKind.values);
}

class ScheduledNotification extends DataClass
    implements Insertable<ScheduledNotification> {
  final int id;
  final int? cardId;
  final NotificationKind kind;

  /// e.g. 3, 7, 1 — days-before-due-date for dueDateReminder policies.
  final int? daysBefore;
  final DateTime triggerDate;

  /// The id used with flutter_local_notifications' zonedSchedule/cancel.
  final int osNotificationId;
  const ScheduledNotification({
    required this.id,
    this.cardId,
    required this.kind,
    this.daysBefore,
    required this.triggerDate,
    required this.osNotificationId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || cardId != null) {
      map['card_id'] = Variable<int>(cardId);
    }
    {
      map['kind'] = Variable<String>(
        $ScheduledNotificationsTable.$converterkind.toSql(kind),
      );
    }
    if (!nullToAbsent || daysBefore != null) {
      map['days_before'] = Variable<int>(daysBefore);
    }
    map['trigger_date'] = Variable<DateTime>(triggerDate);
    map['os_notification_id'] = Variable<int>(osNotificationId);
    return map;
  }

  ScheduledNotificationsCompanion toCompanion(bool nullToAbsent) {
    return ScheduledNotificationsCompanion(
      id: Value(id),
      cardId: cardId == null && nullToAbsent
          ? const Value.absent()
          : Value(cardId),
      kind: Value(kind),
      daysBefore: daysBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(daysBefore),
      triggerDate: Value(triggerDate),
      osNotificationId: Value(osNotificationId),
    );
  }

  factory ScheduledNotification.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScheduledNotification(
      id: serializer.fromJson<int>(json['id']),
      cardId: serializer.fromJson<int?>(json['cardId']),
      kind: $ScheduledNotificationsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      daysBefore: serializer.fromJson<int?>(json['daysBefore']),
      triggerDate: serializer.fromJson<DateTime>(json['triggerDate']),
      osNotificationId: serializer.fromJson<int>(json['osNotificationId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cardId': serializer.toJson<int?>(cardId),
      'kind': serializer.toJson<String>(
        $ScheduledNotificationsTable.$converterkind.toJson(kind),
      ),
      'daysBefore': serializer.toJson<int?>(daysBefore),
      'triggerDate': serializer.toJson<DateTime>(triggerDate),
      'osNotificationId': serializer.toJson<int>(osNotificationId),
    };
  }

  ScheduledNotification copyWith({
    int? id,
    Value<int?> cardId = const Value.absent(),
    NotificationKind? kind,
    Value<int?> daysBefore = const Value.absent(),
    DateTime? triggerDate,
    int? osNotificationId,
  }) => ScheduledNotification(
    id: id ?? this.id,
    cardId: cardId.present ? cardId.value : this.cardId,
    kind: kind ?? this.kind,
    daysBefore: daysBefore.present ? daysBefore.value : this.daysBefore,
    triggerDate: triggerDate ?? this.triggerDate,
    osNotificationId: osNotificationId ?? this.osNotificationId,
  );
  ScheduledNotification copyWithCompanion(
    ScheduledNotificationsCompanion data,
  ) {
    return ScheduledNotification(
      id: data.id.present ? data.id.value : this.id,
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      kind: data.kind.present ? data.kind.value : this.kind,
      daysBefore: data.daysBefore.present
          ? data.daysBefore.value
          : this.daysBefore,
      triggerDate: data.triggerDate.present
          ? data.triggerDate.value
          : this.triggerDate,
      osNotificationId: data.osNotificationId.present
          ? data.osNotificationId.value
          : this.osNotificationId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScheduledNotification(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('kind: $kind, ')
          ..write('daysBefore: $daysBefore, ')
          ..write('triggerDate: $triggerDate, ')
          ..write('osNotificationId: $osNotificationId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, cardId, kind, daysBefore, triggerDate, osNotificationId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduledNotification &&
          other.id == this.id &&
          other.cardId == this.cardId &&
          other.kind == this.kind &&
          other.daysBefore == this.daysBefore &&
          other.triggerDate == this.triggerDate &&
          other.osNotificationId == this.osNotificationId);
}

class ScheduledNotificationsCompanion
    extends UpdateCompanion<ScheduledNotification> {
  final Value<int> id;
  final Value<int?> cardId;
  final Value<NotificationKind> kind;
  final Value<int?> daysBefore;
  final Value<DateTime> triggerDate;
  final Value<int> osNotificationId;
  const ScheduledNotificationsCompanion({
    this.id = const Value.absent(),
    this.cardId = const Value.absent(),
    this.kind = const Value.absent(),
    this.daysBefore = const Value.absent(),
    this.triggerDate = const Value.absent(),
    this.osNotificationId = const Value.absent(),
  });
  ScheduledNotificationsCompanion.insert({
    this.id = const Value.absent(),
    this.cardId = const Value.absent(),
    required NotificationKind kind,
    this.daysBefore = const Value.absent(),
    required DateTime triggerDate,
    required int osNotificationId,
  }) : kind = Value(kind),
       triggerDate = Value(triggerDate),
       osNotificationId = Value(osNotificationId);
  static Insertable<ScheduledNotification> custom({
    Expression<int>? id,
    Expression<int>? cardId,
    Expression<String>? kind,
    Expression<int>? daysBefore,
    Expression<DateTime>? triggerDate,
    Expression<int>? osNotificationId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cardId != null) 'card_id': cardId,
      if (kind != null) 'kind': kind,
      if (daysBefore != null) 'days_before': daysBefore,
      if (triggerDate != null) 'trigger_date': triggerDate,
      if (osNotificationId != null) 'os_notification_id': osNotificationId,
    });
  }

  ScheduledNotificationsCompanion copyWith({
    Value<int>? id,
    Value<int?>? cardId,
    Value<NotificationKind>? kind,
    Value<int?>? daysBefore,
    Value<DateTime>? triggerDate,
    Value<int>? osNotificationId,
  }) {
    return ScheduledNotificationsCompanion(
      id: id ?? this.id,
      cardId: cardId ?? this.cardId,
      kind: kind ?? this.kind,
      daysBefore: daysBefore ?? this.daysBefore,
      triggerDate: triggerDate ?? this.triggerDate,
      osNotificationId: osNotificationId ?? this.osNotificationId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cardId.present) {
      map['card_id'] = Variable<int>(cardId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $ScheduledNotificationsTable.$converterkind.toSql(kind.value),
      );
    }
    if (daysBefore.present) {
      map['days_before'] = Variable<int>(daysBefore.value);
    }
    if (triggerDate.present) {
      map['trigger_date'] = Variable<DateTime>(triggerDate.value);
    }
    if (osNotificationId.present) {
      map['os_notification_id'] = Variable<int>(osNotificationId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScheduledNotificationsCompanion(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('kind: $kind, ')
          ..write('daysBefore: $daysBefore, ')
          ..write('triggerDate: $triggerDate, ')
          ..write('osNotificationId: $osNotificationId')
          ..write(')'))
        .toString();
  }
}

class $MetaTable extends Meta with TableInfo<$MetaTable, MetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetaData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $MetaTable createAlias(String alias) {
    return $MetaTable(attachedDatabase, alias);
  }
}

class MetaData extends DataClass implements Insertable<MetaData> {
  final String key;
  final String value;
  const MetaData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  MetaCompanion toCompanion(bool nullToAbsent) {
    return MetaCompanion(key: Value(key), value: Value(value));
  }

  factory MetaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  MetaData copyWith({String? key, String? value}) =>
      MetaData(key: key ?? this.key, value: value ?? this.value);
  MetaData copyWithCompanion(MetaCompanion data) {
    return MetaData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetaData && other.key == this.key && other.value == this.value);
}

class MetaCompanion extends UpdateCompanion<MetaData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const MetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<MetaData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return MetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BanksTable banks = $BanksTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $CardsTable cards = $CardsTable(this);
  late final $BeneficiariesTable beneficiaries = $BeneficiariesTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $CategoryBudgetsTable categoryBudgets = $CategoryBudgetsTable(
    this,
  );
  late final $NotificationPreferencesTable notificationPreferences =
      $NotificationPreferencesTable(this);
  late final $ScheduledNotificationsTable scheduledNotifications =
      $ScheduledNotificationsTable(this);
  late final $MetaTable meta = $MetaTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    banks,
    categories,
    cards,
    beneficiaries,
    transactions,
    categoryBudgets,
    notificationPreferences,
    scheduledNotifications,
    meta,
  ];
}

typedef $$BanksTableCreateCompanionBuilder =
    BanksCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> logoUri,
      Value<bool> isCustom,
    });
typedef $$BanksTableUpdateCompanionBuilder =
    BanksCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> logoUri,
      Value<bool> isCustom,
    });

final class $$BanksTableReferences
    extends BaseReferences<_$AppDatabase, $BanksTable, Bank> {
  $$BanksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CardsTable, List<Card>> _cardsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.cards,
    aliasName: 'banks__id__cards__bank_id',
  );

  $$CardsTableProcessedTableManager get cardsRefs {
    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.bankId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_cardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BanksTableFilterComposer extends Composer<_$AppDatabase, $BanksTable> {
  $$BanksTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get logoUri => $composableBuilder(
    column: $table.logoUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> cardsRefs(
    Expression<bool> Function($$CardsTableFilterComposer f) f,
  ) {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.bankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BanksTableOrderingComposer
    extends Composer<_$AppDatabase, $BanksTable> {
  $$BanksTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get logoUri => $composableBuilder(
    column: $table.logoUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BanksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BanksTable> {
  $$BanksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get logoUri =>
      $composableBuilder(column: $table.logoUri, builder: (column) => column);

  GeneratedColumn<bool> get isCustom =>
      $composableBuilder(column: $table.isCustom, builder: (column) => column);

  Expression<T> cardsRefs<T extends Object>(
    Expression<T> Function($$CardsTableAnnotationComposer a) f,
  ) {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.bankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BanksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BanksTable,
          Bank,
          $$BanksTableFilterComposer,
          $$BanksTableOrderingComposer,
          $$BanksTableAnnotationComposer,
          $$BanksTableCreateCompanionBuilder,
          $$BanksTableUpdateCompanionBuilder,
          (Bank, $$BanksTableReferences),
          Bank,
          PrefetchHooks Function({bool cardsRefs})
        > {
  $$BanksTableTableManager(_$AppDatabase db, $BanksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BanksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BanksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BanksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> logoUri = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
              }) => BanksCompanion(
                id: id,
                name: name,
                logoUri: logoUri,
                isCustom: isCustom,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> logoUri = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
              }) => BanksCompanion.insert(
                id: id,
                name: name,
                logoUri: logoUri,
                isCustom: isCustom,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BanksTable, Bank>(table),
                  $$BanksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cardsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (cardsRefs) db.cards],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (cardsRefs)
                    await $_getPrefetchedData<Bank, $BanksTable, Card>(
                      currentTable: table,
                      referencedTable: $$BanksTableReferences._cardsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$BanksTableReferences(db, table, p0).cardsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.bankId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$BanksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BanksTable,
      Bank,
      $$BanksTableFilterComposer,
      $$BanksTableOrderingComposer,
      $$BanksTableAnnotationComposer,
      $$BanksTableCreateCompanionBuilder,
      $$BanksTableUpdateCompanionBuilder,
      (Bank, $$BanksTableReferences),
      Bank,
      PrefetchHooks Function({bool cardsRefs})
    >;
typedef $$CategoriesTableCreateCompanionBuilder =
    CategoriesCompanion Function({
      Value<int> id,
      Value<int?> parentCategoryId,
      required String name,
      required String icon,
      required String color,
      required CategoryType type,
      Value<bool> isDefault,
    });
typedef $$CategoriesTableUpdateCompanionBuilder =
    CategoriesCompanion Function({
      Value<int> id,
      Value<int?> parentCategoryId,
      Value<String> name,
      Value<String> icon,
      Value<String> color,
      Value<CategoryType> type,
      Value<bool> isDefault,
    });

final class $$CategoriesTableReferences
    extends BaseReferences<_$AppDatabase, $CategoriesTable, Category> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _parentCategoryIdTable(_$AppDatabase db) => db
      .categories
      .createAlias('categories__parent_category_id__categories__id');

  $$CategoriesTableProcessedTableManager? get parentCategoryId {
    final $_column = $_itemColumn<int>('parent_category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentCategoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TransactionsTable, List<Transaction>>
  _transactionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: 'categories__id__transactions__category_id',
  );

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CategoryBudgetsTable, List<CategoryBudget>>
  _categoryBudgetsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.categoryBudgets,
    aliasName: 'categories__id__category_budgets__category_id',
  );

  $$CategoryBudgetsTableProcessedTableManager get categoryBudgetsRefs {
    final manager = $$CategoryBudgetsTableTableManager(
      $_db,
      $_db.categoryBudgets,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _categoryBudgetsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CategoryType, CategoryType, String> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get parentCategoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentCategoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> transactionsRefs(
    Expression<bool> Function($$TransactionsTableFilterComposer f) f,
  ) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> categoryBudgetsRefs(
    Expression<bool> Function($$CategoryBudgetsTableFilterComposer f) f,
  ) {
    final $$CategoryBudgetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.categoryBudgets,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryBudgetsTableFilterComposer(
            $db: $db,
            $table: $db.categoryBudgets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get parentCategoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentCategoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CategoryType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get parentCategoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentCategoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> transactionsRefs<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> categoryBudgetsRefs<T extends Object>(
    Expression<T> Function($$CategoryBudgetsTableAnnotationComposer a) f,
  ) {
    final $$CategoryBudgetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.categoryBudgets,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryBudgetsTableAnnotationComposer(
            $db: $db,
            $table: $db.categoryBudgets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, $$CategoriesTableReferences),
          Category,
          PrefetchHooks Function({
            bool parentCategoryId,
            bool transactionsRefs,
            bool categoryBudgetsRefs,
          })
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> parentCategoryId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<CategoryType> type = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                parentCategoryId: parentCategoryId,
                name: name,
                icon: icon,
                color: color,
                type: type,
                isDefault: isDefault,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> parentCategoryId = const Value.absent(),
                required String name,
                required String icon,
                required String color,
                required CategoryType type,
                Value<bool> isDefault = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                parentCategoryId: parentCategoryId,
                name: name,
                icon: icon,
                color: color,
                type: type,
                isDefault: isDefault,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoriesTable, Category>(table),
                  $$CategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                parentCategoryId = false,
                transactionsRefs = false,
                categoryBudgetsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (transactionsRefs) db.transactions,
                    if (categoryBudgetsRefs) db.categoryBudgets,
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
                        if (parentCategoryId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.parentCategoryId,
                                    referencedTable: $$CategoriesTableReferences
                                        ._parentCategoryIdTable(db),
                                    referencedColumn:
                                        $$CategoriesTableReferences
                                            ._parentCategoryIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (transactionsRefs)
                        await $_getPrefetchedData<
                          Category,
                          $CategoriesTable,
                          Transaction
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._transactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (categoryBudgetsRefs)
                        await $_getPrefetchedData<
                          Category,
                          $CategoriesTable,
                          CategoryBudget
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._categoryBudgetsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).categoryBudgetsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
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

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, $$CategoriesTableReferences),
      Category,
      PrefetchHooks Function({
        bool parentCategoryId,
        bool transactionsRefs,
        bool categoryBudgetsRefs,
      })
    >;
typedef $$CardsTableCreateCompanionBuilder =
    CardsCompanion Function({
      Value<int> id,
      required int bankId,
      required CardType cardType,
      required CardCategory cardCategory,
      required String nickname,
      required String last4Digits,
      Value<int?> dueDateDay,
      Value<int?> statementDateDay,
      Value<double?> creditLimit,
      required String color,
      Value<bool> isActive,
    });
typedef $$CardsTableUpdateCompanionBuilder =
    CardsCompanion Function({
      Value<int> id,
      Value<int> bankId,
      Value<CardType> cardType,
      Value<CardCategory> cardCategory,
      Value<String> nickname,
      Value<String> last4Digits,
      Value<int?> dueDateDay,
      Value<int?> statementDateDay,
      Value<double?> creditLimit,
      Value<String> color,
      Value<bool> isActive,
    });

final class $$CardsTableReferences
    extends BaseReferences<_$AppDatabase, $CardsTable, Card> {
  $$CardsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BanksTable _bankIdTable(_$AppDatabase db) =>
      db.banks.createAlias('cards__bank_id__banks__id');

  $$BanksTableProcessedTableManager get bankId {
    final $_column = $_itemColumn<int>('bank_id')!;

    final manager = $$BanksTableTableManager(
      $_db,
      $_db.banks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bankIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TransactionsTable, List<Transaction>>
  _transactionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: 'cards__id__transactions__card_id',
  );

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.cardId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ScheduledNotificationsTable,
    List<ScheduledNotification>
  >
  _scheduledNotificationsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.scheduledNotifications,
        aliasName: 'cards__id__scheduled_notifications__card_id',
      );

  $$ScheduledNotificationsTableProcessedTableManager
  get scheduledNotificationsRefs {
    final manager = $$ScheduledNotificationsTableTableManager(
      $_db,
      $_db.scheduledNotifications,
    ).filter((f) => f.cardId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _scheduledNotificationsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CardsTableFilterComposer extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableFilterComposer({
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

  ColumnWithTypeConverterFilters<CardType, CardType, String> get cardType =>
      $composableBuilder(
        column: $table.cardType,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<CardCategory, CardCategory, String>
  get cardCategory => $composableBuilder(
    column: $table.cardCategory,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get last4Digits => $composableBuilder(
    column: $table.last4Digits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueDateDay => $composableBuilder(
    column: $table.dueDateDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get statementDateDay => $composableBuilder(
    column: $table.statementDateDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get creditLimit => $composableBuilder(
    column: $table.creditLimit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  $$BanksTableFilterComposer get bankId {
    final $$BanksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bankId,
      referencedTable: $db.banks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BanksTableFilterComposer(
            $db: $db,
            $table: $db.banks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> transactionsRefs(
    Expression<bool> Function($$TransactionsTableFilterComposer f) f,
  ) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> scheduledNotificationsRefs(
    Expression<bool> Function($$ScheduledNotificationsTableFilterComposer f) f,
  ) {
    final $$ScheduledNotificationsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.scheduledNotifications,
          getReferencedColumn: (t) => t.cardId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledNotificationsTableFilterComposer(
                $db: $db,
                $table: $db.scheduledNotifications,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CardsTableOrderingComposer
    extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableOrderingComposer({
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

  ColumnOrderings<String> get cardType => $composableBuilder(
    column: $table.cardType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardCategory => $composableBuilder(
    column: $table.cardCategory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get last4Digits => $composableBuilder(
    column: $table.last4Digits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueDateDay => $composableBuilder(
    column: $table.dueDateDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get statementDateDay => $composableBuilder(
    column: $table.statementDateDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get creditLimit => $composableBuilder(
    column: $table.creditLimit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  $$BanksTableOrderingComposer get bankId {
    final $$BanksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bankId,
      referencedTable: $db.banks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BanksTableOrderingComposer(
            $db: $db,
            $table: $db.banks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CardType, String> get cardType =>
      $composableBuilder(column: $table.cardType, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CardCategory, String> get cardCategory =>
      $composableBuilder(
        column: $table.cardCategory,
        builder: (column) => column,
      );

  GeneratedColumn<String> get nickname =>
      $composableBuilder(column: $table.nickname, builder: (column) => column);

  GeneratedColumn<String> get last4Digits => $composableBuilder(
    column: $table.last4Digits,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dueDateDay => $composableBuilder(
    column: $table.dueDateDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get statementDateDay => $composableBuilder(
    column: $table.statementDateDay,
    builder: (column) => column,
  );

  GeneratedColumn<double> get creditLimit => $composableBuilder(
    column: $table.creditLimit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  $$BanksTableAnnotationComposer get bankId {
    final $$BanksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bankId,
      referencedTable: $db.banks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BanksTableAnnotationComposer(
            $db: $db,
            $table: $db.banks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> transactionsRefs<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> scheduledNotificationsRefs<T extends Object>(
    Expression<T> Function($$ScheduledNotificationsTableAnnotationComposer a) f,
  ) {
    final $$ScheduledNotificationsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.scheduledNotifications,
          getReferencedColumn: (t) => t.cardId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledNotificationsTableAnnotationComposer(
                $db: $db,
                $table: $db.scheduledNotifications,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CardsTable,
          Card,
          $$CardsTableFilterComposer,
          $$CardsTableOrderingComposer,
          $$CardsTableAnnotationComposer,
          $$CardsTableCreateCompanionBuilder,
          $$CardsTableUpdateCompanionBuilder,
          (Card, $$CardsTableReferences),
          Card,
          PrefetchHooks Function({
            bool bankId,
            bool transactionsRefs,
            bool scheduledNotificationsRefs,
          })
        > {
  $$CardsTableTableManager(_$AppDatabase db, $CardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> bankId = const Value.absent(),
                Value<CardType> cardType = const Value.absent(),
                Value<CardCategory> cardCategory = const Value.absent(),
                Value<String> nickname = const Value.absent(),
                Value<String> last4Digits = const Value.absent(),
                Value<int?> dueDateDay = const Value.absent(),
                Value<int?> statementDateDay = const Value.absent(),
                Value<double?> creditLimit = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
              }) => CardsCompanion(
                id: id,
                bankId: bankId,
                cardType: cardType,
                cardCategory: cardCategory,
                nickname: nickname,
                last4Digits: last4Digits,
                dueDateDay: dueDateDay,
                statementDateDay: statementDateDay,
                creditLimit: creditLimit,
                color: color,
                isActive: isActive,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int bankId,
                required CardType cardType,
                required CardCategory cardCategory,
                required String nickname,
                required String last4Digits,
                Value<int?> dueDateDay = const Value.absent(),
                Value<int?> statementDateDay = const Value.absent(),
                Value<double?> creditLimit = const Value.absent(),
                required String color,
                Value<bool> isActive = const Value.absent(),
              }) => CardsCompanion.insert(
                id: id,
                bankId: bankId,
                cardType: cardType,
                cardCategory: cardCategory,
                nickname: nickname,
                last4Digits: last4Digits,
                dueDateDay: dueDateDay,
                statementDateDay: statementDateDay,
                creditLimit: creditLimit,
                color: color,
                isActive: isActive,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CardsTable, Card>(table),
                  $$CardsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                bankId = false,
                transactionsRefs = false,
                scheduledNotificationsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (transactionsRefs) db.transactions,
                    if (scheduledNotificationsRefs) db.scheduledNotifications,
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
                        if (bankId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.bankId,
                                    referencedTable: $$CardsTableReferences
                                        ._bankIdTable(db),
                                    referencedColumn: $$CardsTableReferences
                                        ._bankIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (transactionsRefs)
                        await $_getPrefetchedData<
                          Card,
                          $CardsTable,
                          Transaction
                        >(
                          currentTable: table,
                          referencedTable: $$CardsTableReferences
                              ._transactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CardsTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.cardId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (scheduledNotificationsRefs)
                        await $_getPrefetchedData<
                          Card,
                          $CardsTable,
                          ScheduledNotification
                        >(
                          currentTable: table,
                          referencedTable: $$CardsTableReferences
                              ._scheduledNotificationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CardsTableReferences(
                                db,
                                table,
                                p0,
                              ).scheduledNotificationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.cardId == item.id,
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

typedef $$CardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CardsTable,
      Card,
      $$CardsTableFilterComposer,
      $$CardsTableOrderingComposer,
      $$CardsTableAnnotationComposer,
      $$CardsTableCreateCompanionBuilder,
      $$CardsTableUpdateCompanionBuilder,
      (Card, $$CardsTableReferences),
      Card,
      PrefetchHooks Function({
        bool bankId,
        bool transactionsRefs,
        bool scheduledNotificationsRefs,
      })
    >;
typedef $$BeneficiariesTableCreateCompanionBuilder =
    BeneficiariesCompanion Function({
      Value<int> id,
      required String name,
      required DateTime lastUsedAt,
    });
typedef $$BeneficiariesTableUpdateCompanionBuilder =
    BeneficiariesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<DateTime> lastUsedAt,
    });

class $$BeneficiariesTableFilterComposer
    extends Composer<_$AppDatabase, $BeneficiariesTable> {
  $$BeneficiariesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BeneficiariesTableOrderingComposer
    extends Composer<_$AppDatabase, $BeneficiariesTable> {
  $$BeneficiariesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BeneficiariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BeneficiariesTable> {
  $$BeneficiariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => column,
  );
}

class $$BeneficiariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BeneficiariesTable,
          Beneficiary,
          $$BeneficiariesTableFilterComposer,
          $$BeneficiariesTableOrderingComposer,
          $$BeneficiariesTableAnnotationComposer,
          $$BeneficiariesTableCreateCompanionBuilder,
          $$BeneficiariesTableUpdateCompanionBuilder,
          (
            Beneficiary,
            BaseReferences<_$AppDatabase, $BeneficiariesTable, Beneficiary>,
          ),
          Beneficiary,
          PrefetchHooks Function()
        > {
  $$BeneficiariesTableTableManager(_$AppDatabase db, $BeneficiariesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BeneficiariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BeneficiariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BeneficiariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> lastUsedAt = const Value.absent(),
              }) => BeneficiariesCompanion(
                id: id,
                name: name,
                lastUsedAt: lastUsedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required DateTime lastUsedAt,
              }) => BeneficiariesCompanion.insert(
                id: id,
                name: name,
                lastUsedAt: lastUsedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BeneficiariesTable, Beneficiary>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $BeneficiariesTable,
                    Beneficiary
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BeneficiariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BeneficiariesTable,
      Beneficiary,
      $$BeneficiariesTableFilterComposer,
      $$BeneficiariesTableOrderingComposer,
      $$BeneficiariesTableAnnotationComposer,
      $$BeneficiariesTableCreateCompanionBuilder,
      $$BeneficiariesTableUpdateCompanionBuilder,
      (
        Beneficiary,
        BaseReferences<_$AppDatabase, $BeneficiariesTable, Beneficiary>,
      ),
      Beneficiary,
      PrefetchHooks Function()
    >;
typedef $$TransactionsTableCreateCompanionBuilder =
    TransactionsCompanion Function({
      Value<int> id,
      required double amount,
      required TransactionType type,
      required int categoryId,
      required PaymentMethodType paymentMethodType,
      Value<int?> cardId,
      required DateTime date,
      Value<String?> note,
      Value<String?> attachmentUri,
      Value<String?> beneficiaryName,
      Value<DateTime> createdAt,
    });
typedef $$TransactionsTableUpdateCompanionBuilder =
    TransactionsCompanion Function({
      Value<int> id,
      Value<double> amount,
      Value<TransactionType> type,
      Value<int> categoryId,
      Value<PaymentMethodType> paymentMethodType,
      Value<int?> cardId,
      Value<DateTime> date,
      Value<String?> note,
      Value<String?> attachmentUri,
      Value<String?> beneficiaryName,
      Value<DateTime> createdAt,
    });

final class $$TransactionsTableReferences
    extends BaseReferences<_$AppDatabase, $TransactionsTable, Transaction> {
  $$TransactionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias('transactions__category_id__categories__id');

  $$CategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<int>('category_id')!;

    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CardsTable _cardIdTable(_$AppDatabase db) =>
      db.cards.createAlias('transactions__card_id__cards__id');

  $$CardsTableProcessedTableManager? get cardId {
    final $_column = $_itemColumn<int>('card_id');
    if ($_column == null) return null;
    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cardIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
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

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TransactionType, TransactionType, String>
  get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<PaymentMethodType, PaymentMethodType, String>
  get paymentMethodType => $composableBuilder(
    column: $table.paymentMethodType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentUri => $composableBuilder(
    column: $table.attachmentUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get beneficiaryName => $composableBuilder(
    column: $table.beneficiaryName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CardsTableFilterComposer get cardId {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
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

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentMethodType => $composableBuilder(
    column: $table.paymentMethodType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentUri => $composableBuilder(
    column: $table.attachmentUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get beneficiaryName => $composableBuilder(
    column: $table.beneficiaryName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CardsTableOrderingComposer get cardId {
    final $$CardsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableOrderingComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TransactionType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PaymentMethodType, String>
  get paymentMethodType => $composableBuilder(
    column: $table.paymentMethodType,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get attachmentUri => $composableBuilder(
    column: $table.attachmentUri,
    builder: (column) => column,
  );

  GeneratedColumn<String> get beneficiaryName => $composableBuilder(
    column: $table.beneficiaryName,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CardsTableAnnotationComposer get cardId {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionsTable,
          Transaction,
          $$TransactionsTableFilterComposer,
          $$TransactionsTableOrderingComposer,
          $$TransactionsTableAnnotationComposer,
          $$TransactionsTableCreateCompanionBuilder,
          $$TransactionsTableUpdateCompanionBuilder,
          (Transaction, $$TransactionsTableReferences),
          Transaction,
          PrefetchHooks Function({bool categoryId, bool cardId})
        > {
  $$TransactionsTableTableManager(_$AppDatabase db, $TransactionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<TransactionType> type = const Value.absent(),
                Value<int> categoryId = const Value.absent(),
                Value<PaymentMethodType> paymentMethodType =
                    const Value.absent(),
                Value<int?> cardId = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> attachmentUri = const Value.absent(),
                Value<String?> beneficiaryName = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TransactionsCompanion(
                id: id,
                amount: amount,
                type: type,
                categoryId: categoryId,
                paymentMethodType: paymentMethodType,
                cardId: cardId,
                date: date,
                note: note,
                attachmentUri: attachmentUri,
                beneficiaryName: beneficiaryName,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required double amount,
                required TransactionType type,
                required int categoryId,
                required PaymentMethodType paymentMethodType,
                Value<int?> cardId = const Value.absent(),
                required DateTime date,
                Value<String?> note = const Value.absent(),
                Value<String?> attachmentUri = const Value.absent(),
                Value<String?> beneficiaryName = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TransactionsCompanion.insert(
                id: id,
                amount: amount,
                type: type,
                categoryId: categoryId,
                paymentMethodType: paymentMethodType,
                cardId: cardId,
                date: date,
                note: note,
                attachmentUri: attachmentUri,
                beneficiaryName: beneficiaryName,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TransactionsTable, Transaction>(table),
                  $$TransactionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false, cardId = false}) {
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
                    if (categoryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.categoryId,
                                referencedTable: $$TransactionsTableReferences
                                    ._categoryIdTable(db),
                                referencedColumn: $$TransactionsTableReferences
                                    ._categoryIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (cardId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.cardId,
                                referencedTable: $$TransactionsTableReferences
                                    ._cardIdTable(db),
                                referencedColumn: $$TransactionsTableReferences
                                    ._cardIdTable(db)
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

typedef $$TransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionsTable,
      Transaction,
      $$TransactionsTableFilterComposer,
      $$TransactionsTableOrderingComposer,
      $$TransactionsTableAnnotationComposer,
      $$TransactionsTableCreateCompanionBuilder,
      $$TransactionsTableUpdateCompanionBuilder,
      (Transaction, $$TransactionsTableReferences),
      Transaction,
      PrefetchHooks Function({bool categoryId, bool cardId})
    >;
typedef $$CategoryBudgetsTableCreateCompanionBuilder =
    CategoryBudgetsCompanion Function({
      Value<int> id,
      required int categoryId,
      required double monthlyLimit,
      Value<bool> isEnabled,
    });
typedef $$CategoryBudgetsTableUpdateCompanionBuilder =
    CategoryBudgetsCompanion Function({
      Value<int> id,
      Value<int> categoryId,
      Value<double> monthlyLimit,
      Value<bool> isEnabled,
    });

final class $$CategoryBudgetsTableReferences
    extends
        BaseReferences<_$AppDatabase, $CategoryBudgetsTable, CategoryBudget> {
  $$CategoryBudgetsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) => db.categories
      .createAlias('category_budgets__category_id__categories__id');

  $$CategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<int>('category_id')!;

    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CategoryBudgetsTableFilterComposer
    extends Composer<_$AppDatabase, $CategoryBudgetsTable> {
  $$CategoryBudgetsTableFilterComposer({
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

  ColumnFilters<double> get monthlyLimit => $composableBuilder(
    column: $table.monthlyLimit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoryBudgetsTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoryBudgetsTable> {
  $$CategoryBudgetsTableOrderingComposer({
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

  ColumnOrderings<double> get monthlyLimit => $composableBuilder(
    column: $table.monthlyLimit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoryBudgetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoryBudgetsTable> {
  $$CategoryBudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get monthlyLimit => $composableBuilder(
    column: $table.monthlyLimit,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoryBudgetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoryBudgetsTable,
          CategoryBudget,
          $$CategoryBudgetsTableFilterComposer,
          $$CategoryBudgetsTableOrderingComposer,
          $$CategoryBudgetsTableAnnotationComposer,
          $$CategoryBudgetsTableCreateCompanionBuilder,
          $$CategoryBudgetsTableUpdateCompanionBuilder,
          (CategoryBudget, $$CategoryBudgetsTableReferences),
          CategoryBudget,
          PrefetchHooks Function({bool categoryId})
        > {
  $$CategoryBudgetsTableTableManager(
    _$AppDatabase db,
    $CategoryBudgetsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoryBudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoryBudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoryBudgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> categoryId = const Value.absent(),
                Value<double> monthlyLimit = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
              }) => CategoryBudgetsCompanion(
                id: id,
                categoryId: categoryId,
                monthlyLimit: monthlyLimit,
                isEnabled: isEnabled,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int categoryId,
                required double monthlyLimit,
                Value<bool> isEnabled = const Value.absent(),
              }) => CategoryBudgetsCompanion.insert(
                id: id,
                categoryId: categoryId,
                monthlyLimit: monthlyLimit,
                isEnabled: isEnabled,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoryBudgetsTable, CategoryBudget>(table),
                  $$CategoryBudgetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false}) {
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
                    if (categoryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.categoryId,
                                referencedTable:
                                    $$CategoryBudgetsTableReferences
                                        ._categoryIdTable(db),
                                referencedColumn:
                                    $$CategoryBudgetsTableReferences
                                        ._categoryIdTable(db)
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

typedef $$CategoryBudgetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoryBudgetsTable,
      CategoryBudget,
      $$CategoryBudgetsTableFilterComposer,
      $$CategoryBudgetsTableOrderingComposer,
      $$CategoryBudgetsTableAnnotationComposer,
      $$CategoryBudgetsTableCreateCompanionBuilder,
      $$CategoryBudgetsTableUpdateCompanionBuilder,
      (CategoryBudget, $$CategoryBudgetsTableReferences),
      CategoryBudget,
      PrefetchHooks Function({bool categoryId})
    >;
typedef $$NotificationPreferencesTableCreateCompanionBuilder =
    NotificationPreferencesCompanion Function({
      required String key,
      Value<bool> isEnabled,
      Value<String?> configJson,
      Value<int> rowid,
    });
typedef $$NotificationPreferencesTableUpdateCompanionBuilder =
    NotificationPreferencesCompanion Function({
      Value<String> key,
      Value<bool> isEnabled,
      Value<String?> configJson,
      Value<int> rowid,
    });

class $$NotificationPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $NotificationPreferencesTable> {
  $$NotificationPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotificationPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $NotificationPreferencesTable> {
  $$NotificationPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotificationPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotificationPreferencesTable> {
  $$NotificationPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => column,
  );
}

class $$NotificationPreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotificationPreferencesTable,
          NotificationPreference,
          $$NotificationPreferencesTableFilterComposer,
          $$NotificationPreferencesTableOrderingComposer,
          $$NotificationPreferencesTableAnnotationComposer,
          $$NotificationPreferencesTableCreateCompanionBuilder,
          $$NotificationPreferencesTableUpdateCompanionBuilder,
          (
            NotificationPreference,
            BaseReferences<
              _$AppDatabase,
              $NotificationPreferencesTable,
              NotificationPreference
            >,
          ),
          NotificationPreference,
          PrefetchHooks Function()
        > {
  $$NotificationPreferencesTableTableManager(
    _$AppDatabase db,
    $NotificationPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationPreferencesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$NotificationPreferencesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$NotificationPreferencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<String?> configJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotificationPreferencesCompanion(
                key: key,
                isEnabled: isEnabled,
                configJson: configJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                Value<bool> isEnabled = const Value.absent(),
                Value<String?> configJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotificationPreferencesCompanion.insert(
                key: key,
                isEnabled: isEnabled,
                configJson: configJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $NotificationPreferencesTable,
                    NotificationPreference
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $NotificationPreferencesTable,
                    NotificationPreference
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotificationPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotificationPreferencesTable,
      NotificationPreference,
      $$NotificationPreferencesTableFilterComposer,
      $$NotificationPreferencesTableOrderingComposer,
      $$NotificationPreferencesTableAnnotationComposer,
      $$NotificationPreferencesTableCreateCompanionBuilder,
      $$NotificationPreferencesTableUpdateCompanionBuilder,
      (
        NotificationPreference,
        BaseReferences<
          _$AppDatabase,
          $NotificationPreferencesTable,
          NotificationPreference
        >,
      ),
      NotificationPreference,
      PrefetchHooks Function()
    >;
typedef $$ScheduledNotificationsTableCreateCompanionBuilder =
    ScheduledNotificationsCompanion Function({
      Value<int> id,
      Value<int?> cardId,
      required NotificationKind kind,
      Value<int?> daysBefore,
      required DateTime triggerDate,
      required int osNotificationId,
    });
typedef $$ScheduledNotificationsTableUpdateCompanionBuilder =
    ScheduledNotificationsCompanion Function({
      Value<int> id,
      Value<int?> cardId,
      Value<NotificationKind> kind,
      Value<int?> daysBefore,
      Value<DateTime> triggerDate,
      Value<int> osNotificationId,
    });

final class $$ScheduledNotificationsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ScheduledNotificationsTable,
          ScheduledNotification
        > {
  $$ScheduledNotificationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CardsTable _cardIdTable(_$AppDatabase db) =>
      db.cards.createAlias('scheduled_notifications__card_id__cards__id');

  $$CardsTableProcessedTableManager? get cardId {
    final $_column = $_itemColumn<int>('card_id');
    if ($_column == null) return null;
    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cardIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ScheduledNotificationsTableFilterComposer
    extends Composer<_$AppDatabase, $ScheduledNotificationsTable> {
  $$ScheduledNotificationsTableFilterComposer({
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

  ColumnWithTypeConverterFilters<NotificationKind, NotificationKind, String>
  get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get daysBefore => $composableBuilder(
    column: $table.daysBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get triggerDate => $composableBuilder(
    column: $table.triggerDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get osNotificationId => $composableBuilder(
    column: $table.osNotificationId,
    builder: (column) => ColumnFilters(column),
  );

  $$CardsTableFilterComposer get cardId {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScheduledNotificationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ScheduledNotificationsTable> {
  $$ScheduledNotificationsTableOrderingComposer({
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

  ColumnOrderings<int> get daysBefore => $composableBuilder(
    column: $table.daysBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get triggerDate => $composableBuilder(
    column: $table.triggerDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get osNotificationId => $composableBuilder(
    column: $table.osNotificationId,
    builder: (column) => ColumnOrderings(column),
  );

  $$CardsTableOrderingComposer get cardId {
    final $$CardsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableOrderingComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScheduledNotificationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScheduledNotificationsTable> {
  $$ScheduledNotificationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<NotificationKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get daysBefore => $composableBuilder(
    column: $table.daysBefore,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get triggerDate => $composableBuilder(
    column: $table.triggerDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get osNotificationId => $composableBuilder(
    column: $table.osNotificationId,
    builder: (column) => column,
  );

  $$CardsTableAnnotationComposer get cardId {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScheduledNotificationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScheduledNotificationsTable,
          ScheduledNotification,
          $$ScheduledNotificationsTableFilterComposer,
          $$ScheduledNotificationsTableOrderingComposer,
          $$ScheduledNotificationsTableAnnotationComposer,
          $$ScheduledNotificationsTableCreateCompanionBuilder,
          $$ScheduledNotificationsTableUpdateCompanionBuilder,
          (ScheduledNotification, $$ScheduledNotificationsTableReferences),
          ScheduledNotification,
          PrefetchHooks Function({bool cardId})
        > {
  $$ScheduledNotificationsTableTableManager(
    _$AppDatabase db,
    $ScheduledNotificationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScheduledNotificationsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ScheduledNotificationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ScheduledNotificationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> cardId = const Value.absent(),
                Value<NotificationKind> kind = const Value.absent(),
                Value<int?> daysBefore = const Value.absent(),
                Value<DateTime> triggerDate = const Value.absent(),
                Value<int> osNotificationId = const Value.absent(),
              }) => ScheduledNotificationsCompanion(
                id: id,
                cardId: cardId,
                kind: kind,
                daysBefore: daysBefore,
                triggerDate: triggerDate,
                osNotificationId: osNotificationId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> cardId = const Value.absent(),
                required NotificationKind kind,
                Value<int?> daysBefore = const Value.absent(),
                required DateTime triggerDate,
                required int osNotificationId,
              }) => ScheduledNotificationsCompanion.insert(
                id: id,
                cardId: cardId,
                kind: kind,
                daysBefore: daysBefore,
                triggerDate: triggerDate,
                osNotificationId: osNotificationId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $ScheduledNotificationsTable,
                    ScheduledNotification
                  >(table),
                  $$ScheduledNotificationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cardId = false}) {
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
                    if (cardId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.cardId,
                                referencedTable:
                                    $$ScheduledNotificationsTableReferences
                                        ._cardIdTable(db),
                                referencedColumn:
                                    $$ScheduledNotificationsTableReferences
                                        ._cardIdTable(db)
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

typedef $$ScheduledNotificationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScheduledNotificationsTable,
      ScheduledNotification,
      $$ScheduledNotificationsTableFilterComposer,
      $$ScheduledNotificationsTableOrderingComposer,
      $$ScheduledNotificationsTableAnnotationComposer,
      $$ScheduledNotificationsTableCreateCompanionBuilder,
      $$ScheduledNotificationsTableUpdateCompanionBuilder,
      (ScheduledNotification, $$ScheduledNotificationsTableReferences),
      ScheduledNotification,
      PrefetchHooks Function({bool cardId})
    >;
typedef $$MetaTableCreateCompanionBuilder =
    MetaCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$MetaTableUpdateCompanionBuilder =
    MetaCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$MetaTableFilterComposer extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MetaTableOrderingComposer extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$MetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MetaTable,
          MetaData,
          $$MetaTableFilterComposer,
          $$MetaTableOrderingComposer,
          $$MetaTableAnnotationComposer,
          $$MetaTableCreateCompanionBuilder,
          $$MetaTableUpdateCompanionBuilder,
          (MetaData, BaseReferences<_$AppDatabase, $MetaTable, MetaData>),
          MetaData,
          PrefetchHooks Function()
        > {
  $$MetaTableTableManager(_$AppDatabase db, $MetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => MetaCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MetaTable, MetaData>(table),
                  BaseReferences<_$AppDatabase, $MetaTable, MetaData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MetaTable,
      MetaData,
      $$MetaTableFilterComposer,
      $$MetaTableOrderingComposer,
      $$MetaTableAnnotationComposer,
      $$MetaTableCreateCompanionBuilder,
      $$MetaTableUpdateCompanionBuilder,
      (MetaData, BaseReferences<_$AppDatabase, $MetaTable, MetaData>),
      MetaData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BanksTableTableManager get banks =>
      $$BanksTableTableManager(_db, _db.banks);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$CardsTableTableManager get cards =>
      $$CardsTableTableManager(_db, _db.cards);
  $$BeneficiariesTableTableManager get beneficiaries =>
      $$BeneficiariesTableTableManager(_db, _db.beneficiaries);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$CategoryBudgetsTableTableManager get categoryBudgets =>
      $$CategoryBudgetsTableTableManager(_db, _db.categoryBudgets);
  $$NotificationPreferencesTableTableManager get notificationPreferences =>
      $$NotificationPreferencesTableTableManager(
        _db,
        _db.notificationPreferences,
      );
  $$ScheduledNotificationsTableTableManager get scheduledNotifications =>
      $$ScheduledNotificationsTableTableManager(
        _db,
        _db.scheduledNotifications,
      );
  $$MetaTableTableManager get meta => $$MetaTableTableManager(_db, _db.meta);
}
