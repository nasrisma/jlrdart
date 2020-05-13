# jlrdart
Jaguar Land Rover car API (Dart implementation)

Based on this REPO: https://github.com/ardevd/jlrpy

# How to use

Create a futurebuilder and load this via future:

```dart
Future<List<Vehicle>> connectAndGet(Connection conn) async {
  String email = 'demo';
  String password = 'demo';
  conn.setCredentials(email, password);

  List<Vehicle> list = await conn.connect();
  await list[0].getAttributes();
  await list[0].getStatus();
  return list;
}
```
