class Department {
  final String name;
  final int port;
  final String baseUrl;
  final String token;

  const Department({
    required this.name,
    required this.port,
    required this.baseUrl,
    required this.token,
  });

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Department &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          port == other.port &&
          baseUrl == other.baseUrl &&
          token == other.token;

  @override
  int get hashCode => name.hashCode ^ port.hashCode ^ baseUrl.hashCode ^ token.hashCode;
}

const List<Department> availableDepartments = [
  Department(
    name: 'Hanvin',
    port: 8092,
    baseUrl: 'http://100.110.197.61:8092',
    token: '', // No token required for Hanvin server
  ),
  Department(
    name: 'Human Resources',
    port: 8091,
    baseUrl: 'http://100.110.197.61:8091',
    token: 'rTilKSsclzuQW8WfQWK1ba8wrD_LetNn', // Token required for HR server
  ),
  Department(
    name: 'Vertex',
    port: 8090,
    baseUrl: 'http://100.110.197.61:8090',
    token: '', // No token required for Vertix server
  ),
];
