import 'dart:mirrors';
import 'package:p2plib/p2plib.dart' as p2p;

void main() {
  print('Inspecting p2p.RouterL2 class...');

  final mirror = reflectClass(p2p.RouterL2);

  print('Constructors:');
  for (var key in mirror.declarations.keys) {
    var decl = mirror.declarations[key];
    if (decl is MethodMirror && decl.isConstructor) {
      print('- ${MirrorSystem.getName(decl.simpleName)}');
      print('  Parameters: ${decl.parameters.length}');
      for (var p in decl.parameters) {
        print(
            '    - ${MirrorSystem.getName(p.simpleName)}: ${MirrorSystem.getName(p.type.simpleName)}');
      }
    }
  }

  print('\nStatic Methods:');
  for (var key in mirror.declarations.keys) {
    var decl = mirror.declarations[key];
    if (decl is MethodMirror && decl.isStatic) {
      print('- ${MirrorSystem.getName(decl.simpleName)}');
      print('  Parameters: ${decl.parameters.length}');
      for (var p in decl.parameters) {
        print(
            '    - ${MirrorSystem.getName(p.simpleName)}: ${MirrorSystem.getName(p.type.simpleName)}');
      }
    }
  }

  print('\nInstance Members:');
  for (var key in mirror.declarations.keys) {
    var decl = mirror.declarations[key];
    if (decl is VariableMirror) {
      // Fields
      print(
          '- Field: ${MirrorSystem.getName(decl.simpleName)} (Type: ${decl.type.simpleName})');
    }
  }
}
