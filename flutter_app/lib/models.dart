/// Modelos de la API SIGFV (mismas respuestas que consume la APK Capacitor).
library;

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
  return <String, dynamic>{};
}

List<Map<String, dynamic>> asMapList(dynamic value) {
  if (value is List) {
    return value.whereType<Object?>().map(asMap).toList();
  }
  return <Map<String, dynamic>>[];
}

String? asString(dynamic value) {
  if (value == null) return null;
  final s = value.toString();
  return s.isEmpty ? null : s;
}

int? asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

bool asBool(dynamic value) {
  if (value == true) return true;
  if (value is num) return value != 0;
  final s = value?.toString().toLowerCase();
  return s == 'true' || s == '1' || s == 'si' || s == 'sí';
}

class CompanyRole {
  final int rolId;
  final String nombre;
  final String? descripcion;
  final String? icono;
  final String? color;
  final bool global;

  CompanyRole({
    required this.rolId,
    required this.nombre,
    this.descripcion,
    this.icono,
    this.color,
    this.global = false,
  });

  factory CompanyRole.fromJson(Map<String, dynamic> j) => CompanyRole(
        rolId: asInt(j['rolId']) ?? 0,
        nombre: asString(j['nombre']) ?? 'Rol',
        descripcion: asString(j['descripcion']),
        icono: asString(j['icono']),
        color: asString(j['color']),
        global: asBool(j['global']),
      );
}

class Company {
  final int id;
  final String razonSocial;
  final String ruc;
  final List<CompanyRole> roles;

  Company({
    required this.id,
    required this.razonSocial,
    required this.ruc,
    required this.roles,
  });

  factory Company.fromJson(Map<String, dynamic> j) => Company(
        id: asInt(j['id']) ?? 0,
        razonSocial: asString(j['razonSocial']) ?? 'Empresa',
        ruc: asString(j['ruc']) ?? '',
        roles: (j['roles'] is List)
            ? (j['roles'] as List)
                .map((e) => CompanyRole.fromJson(asMap(e)))
                .toList()
            : <CompanyRole>[],
      );
}

class FieldOption {
  final String value;
  final String label;
  FieldOption(this.value, this.label);
}

class FieldDef {
  final String name;
  final String label;
  final String type;
  final bool required;
  final String? catalog;
  final List<FieldOption> options;
  final bool virtual;

  FieldDef({
    required this.name,
    required this.label,
    required this.type,
    required this.required,
    this.catalog,
    this.options = const [],
    this.virtual = false,
  });

  factory FieldDef.fromJson(Map<String, dynamic> j) {
    final opts = <FieldOption>[];
    final raw = j['o'];
    if (raw is List) {
      for (final item in raw) {
        if (item is List && item.length >= 2) {
          opts.add(FieldOption(item[0].toString(), item[1].toString()));
        }
      }
    }
    return FieldDef(
      name: asString(j['n']) ?? '',
      label: asString(j['l']) ?? '',
      type: asString(j['t']) ?? 'text',
      required: asBool(j['req']),
      catalog: asString(j['cat']),
      options: opts,
      virtual: asBool(j['virtual']),
    );
  }
}

class ColumnDef {
  final String key;
  final String label;
  final String? kind;

  ColumnDef({required this.key, required this.label, this.kind});

  bool get isBadge => kind == 'badge';
}

class ResourceDef {
  final String key;
  final String label;
  final String group;
  final String mod;
  final String icon;
  final int order;
  final String? area;
  final String? responsable;
  final String? custom;
  final List<ColumnDef> cols;
  final List<FieldDef> fields;
  final bool crear;
  final bool editar;
  final bool eliminar;
  final bool exportar;

  ResourceDef({
    required this.key,
    required this.label,
    required this.group,
    required this.mod,
    required this.icon,
    required this.order,
    this.area,
    this.responsable,
    this.custom,
    required this.cols,
    required this.fields,
    required this.crear,
    required this.editar,
    required this.eliminar,
    required this.exportar,
  });

  factory ResourceDef.fromJson(String key, Map<String, dynamic> j) {
    final cols = <ColumnDef>[];
    final rawCols = j['cols'];
    if (rawCols is List) {
      for (final item in rawCols) {
        if (item is List && item.length >= 2) {
          cols.add(ColumnDef(
            key: item[0].toString(),
            label: item[1].toString(),
            kind: item.length > 2 && item[2] != null ? item[2].toString() : null,
          ));
        }
      }
    }
    final fields = <FieldDef>[];
    final rawFields = j['fields'];
    if (rawFields is List) {
      for (final item in rawFields) {
        fields.add(FieldDef.fromJson(asMap(item)));
      }
    }
    return ResourceDef(
      key: key,
      label: asString(j['label']) ?? key,
      group: asString(j['group']) ?? '',
      mod: asString(j['mod']) ?? '',
      icon: asString(j['icon']) ?? 'package',
      order: asInt(j['order']) ?? 999,
      area: asString(j['area']),
      responsable: asString(j['responsable']),
      custom: asString(j['custom']),
      cols: cols,
      fields: fields,
      crear: asBool(j['crear']),
      editar: asBool(j['editar']),
      eliminar: asBool(j['eliminar']),
      exportar: asBool(j['exportar']),
    );
  }
}

class OwnerArea {
  final String id;
  final String title;
  final String desc;
  final String responsable;

  OwnerArea({
    required this.id,
    required this.title,
    required this.desc,
    required this.responsable,
  });

  factory OwnerArea.fromJson(Map<String, dynamic> j) => OwnerArea(
        id: asString(j['id']) ?? '',
        title: asString(j['title']) ?? '',
        desc: asString(j['desc']) ?? '',
        responsable: asString(j['responsable']) ?? 'Administrador',
      );
}

class AuthMeta {
  final String user;
  final String empresa;
  final int? empresaId;
  final int? rolId;
  final List<String> roles;
  final bool dashboard;
  final bool notificaciones;
  final Map<String, ResourceDef> resources;
  final List<OwnerArea> owners;
  final List<String> permissions;
  final int solicitudesPendientes;

  AuthMeta({
    required this.user,
    required this.empresa,
    this.empresaId,
    this.rolId,
    required this.roles,
    required this.dashboard,
    required this.notificaciones,
    required this.resources,
    required this.owners,
    required this.permissions,
    this.solicitudesPendientes = 0,
  });

  factory AuthMeta.fromJson(Map<String, dynamic> j) {
    final resources = <String, ResourceDef>{};
    final raw = j['resources'];
    if (raw is Map) {
      raw.forEach((key, value) {
        resources[key.toString()] = ResourceDef.fromJson(key.toString(), asMap(value));
      });
    }
    final owners = <OwnerArea>[];
    final rawOwners = j['owners'];
    if (rawOwners is List) {
      for (final item in rawOwners) {
        owners.add(OwnerArea.fromJson(asMap(item)));
      }
    }
    final roles = <String>[];
    if (j['roles'] is List) {
      for (final item in (j['roles'] as List)) {
        roles.add(item.toString());
      }
    }
    final perms = <String>[];
    if (j['permissions'] is List) {
      for (final item in (j['permissions'] as List)) {
        perms.add(item.toString());
      }
    }
    return AuthMeta(
      user: asString(j['user']) ?? 'Usuario',
      empresa: asString(j['empresa']) ?? 'Todas las empresas',
      empresaId: asInt(j['empresaId']),
      rolId: asInt(j['rolId']),
      roles: roles,
      dashboard: asBool(j['dashboard']),
      notificaciones: asBool(j['notificaciones']),
      resources: resources,
      owners: owners,
      permissions: perms,
      solicitudesPendientes: asInt(j['solicitudesPendientes']) ?? 0,
    );
  }
}

class LoginResult {
  final String token;
  final String rol;
  final String empresa;
  final String operador;

  LoginResult({
    required this.token,
    required this.rol,
    required this.empresa,
    required this.operador,
  });

  factory LoginResult.fromJson(Map<String, dynamic> j) => LoginResult(
        token: asString(j['token']) ?? '',
        rol: asString(j['rol']) ?? '',
        empresa: asString(j['empresa']) ?? '',
        operador: asString(j['operador']) ?? '',
      );
}

class OutboxOp {
  final String opId;
  final String scope;
  final String method;
  final String resource;
  final int? id;
  final int? localId;
  Map<String, dynamic>? body;
  final int createdAt;
  int tries;
  String? error;

  OutboxOp({
    required this.opId,
    required this.scope,
    required this.method,
    required this.resource,
    this.id,
    this.localId,
    this.body,
    required this.createdAt,
    this.tries = 0,
    this.error,
  });

  factory OutboxOp.fromJson(Map<String, dynamic> j) => OutboxOp(
        opId: asString(j['opId']) ?? '',
        scope: asString(j['scope']) ?? '',
        method: asString(j['method']) ?? 'POST',
        resource: asString(j['resource']) ?? '',
        id: asInt(j['id']),
        localId: asInt(j['localId']),
        body: j['body'] == null ? null : asMap(j['body']),
        createdAt: asInt(j['createdAt']) ?? 0,
        tries: asInt(j['tries']) ?? 0,
        error: asString(j['error']),
      );

  Map<String, dynamic> toJson() => {
        'opId': opId,
        'scope': scope,
        'method': method,
        'resource': resource,
        'id': id,
        'localId': localId,
        'body': body,
        'createdAt': createdAt,
        'tries': tries,
        'error': error,
      };
}
