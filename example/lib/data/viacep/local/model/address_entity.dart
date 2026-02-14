import 'package:example/data/viacep/repository/model/address.dart';
import 'package:flutter_core/datasources/local/entity.dart';

class AddressEntity extends Entity {
  final int? _id;
  final String? cep;
  final String? logradouro;
  final String? complemento;
  final String? unidade;
  final String? bairro;
  final String? localidade;
  final String? uf;
  final String? estado;
  final String? regiao;
  final String? ibge;
  final String? gia;
  final String? ddd;
  final String? siafi;

  AddressEntity({
    int? id,
    this.cep,
    this.logradouro,
    this.complemento,
    this.unidade,
    this.bairro,
    this.localidade,
    this.uf,
    this.estado,
    this.regiao,
    this.ibge,
    this.gia,
    this.ddd,
    this.siafi,
  }) : _id = id;

  @override
  String createTable() {
    return '''
      CREATE TABLE IF NOT EXISTS $table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cep TEXT,
        logradouro TEXT,
        complemento TEXT,
        unidade TEXT,
        bairro TEXT,
        localidade TEXT,
        uf TEXT,
        estado TEXT,
        regiao TEXT,
        ibge TEXT,
        gia TEXT,
        ddd TEXT,
        siafi TEXT
      )
    ''';
  }

  @override
  int? get id => _id;

  @override
  String get table => AddressEntity.tableName;
  static const String tableName = 'viacep_address';

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': _id,
      'cep': cep,
      'logradouro': logradouro,
      'complemento': complemento,
      'unidade': unidade,
      'bairro': bairro,
      'localidade': localidade,
      'uf': uf,
      'estado': estado,
      'regiao': regiao,
      'ibge': ibge,
      'gia': gia,
      'ddd': ddd,
      'siafi': siafi,
    };
  }

  factory AddressEntity.fromMap(Map<String, dynamic> map) {
    return AddressEntity(
      id: map['id'] as int?,
      cep: map['cep'] as String?,
      logradouro: map['logradouro'] as String?,
      complemento: map['complemento'] as String?,
      unidade: map['unidade'] as String?,
      bairro: map['bairro'] as String?,
      localidade: map['localidade'] as String?,
      uf: map['uf'] as String?,
      estado: map['estado'] as String?,
      regiao: map['regiao'] as String?,
      ibge: map['ibge'] as String?,
      gia: map['gia'] as String?,
      ddd: map['ddd'] as String?,
      siafi: map['siafi'] as String?,
    );
  } 
}

extension AddressEntityMapper on AddressEntity {
  Address toModel() {
    return Address(
      id: id,
      cep: cep,
      logradouro: logradouro,
      complemento: complemento,
      unidade: unidade,
      bairro: bairro,
      localidade: localidade,
      uf: uf,
      estado: estado,
      regiao: regiao,
      ibge: ibge,
      gia: gia,
      ddd: ddd,
      siafi: siafi,
    );
  }
}
