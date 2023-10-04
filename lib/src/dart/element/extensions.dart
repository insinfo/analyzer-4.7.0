// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/element/element.dart';
import 'package:analyzer/src/generated/utilities_dart.dart';
import 'package:meta/meta_meta.dart';

extension ElementAnnotationExtensions on ElementAnnotation {
  static final Map<String, TargetKind> _targetKindsByName = {
    for (final kind in TargetKind.values) kind.toString(): kind,
  };

  /// Return the target kinds defined for this [ElementAnnotation].
  Set<TargetKind> get targetKinds {
    final element = this.element;
    InterfaceElement? interfaceElement;
    if (element is PropertyAccessorElement) {
      if (element.isGetter) {
        var type = element.returnType;
        if (type is InterfaceType) {
          interfaceElement = type.element2;
        }
      }
    } else if (element is ConstructorElement) {
      interfaceElement = element.enclosingElement3;
    }
    if (interfaceElement == null) {
      return const <TargetKind>{};
    }
    for (var annotation in interfaceElement.metadata) {
      if (annotation.isTarget) {
        var value = annotation.computeConstantValue()!;
        var kinds = <TargetKind>{};

        for (var kindObject in value.getField('kinds')!.toSetValue()!) {
          // We can't directly translate the index from the analyzed TargetKind
          // constant to TargetKinds.values because the analyzer from the SDK
          // may have been compiled with a different version of pkg:meta.

          // TODO add this if for fix this bug https://github.com/dart-lang/sdk/issues/53681
          if (kindObject.getField('index') != null) {

            var index = kindObject.getField('index')!.toIntValue()!;
            var targetKindClass =
                (kindObject.type as InterfaceType).element2 as EnumElementImpl;
            // Instead, map constants to their TargetKind by comparing getter
            // names.
            var getter = targetKindClass.constants[index];
            var name = 'TargetKind.${getter.name}';

            var foundTargetKind = _targetKindsByName[name];
            if (foundTargetKind != null) {
              kinds.add(foundTargetKind);
            }

          }
        }
        return kinds;
      }
    }
    return const <TargetKind>{};
  }
}

extension ElementExtension on Element {
  /// Return `true` if this element, the enclosing class (if there is one), or
  /// the enclosing library, has been annotated with the `@doNotStore`
  /// annotation.
  bool get hasOrInheritsDoNotStore {
    if (hasDoNotStore) {
      return true;
    }

    var ancestor = enclosingElement3;
    if (ancestor is ClassElement) {
      if (ancestor.hasDoNotStore) {
        return true;
      }
      ancestor = ancestor.enclosingElement3;
    } else if (ancestor is ExtensionElement) {
      if (ancestor.hasDoNotStore) {
        return true;
      }
      ancestor = ancestor.enclosingElement3;
    }

    return ancestor is CompilationUnitElement &&
        ancestor.enclosingElement3.hasDoNotStore;
  }

  /// Return `true` if this element is an instance member of a class or mixin.
  ///
  /// Only [MethodElement]s and [PropertyAccessorElement]s are supported.
  /// We intentionally exclude [ConstructorElement]s - they can only be
  /// invoked in instance creation expressions, and [FieldElement]s - they
  /// cannot be invoked directly and are always accessed using corresponding
  /// [PropertyAccessorElement]s.
  bool get isInstanceMember {
    var this_ = this;
    var enclosing = this_.enclosingElement3;
    if (enclosing is ClassElement) {
      return this_ is MethodElement && !this_.isStatic ||
          this_ is PropertyAccessorElement && !this_.isStatic;
    }
    return false;
  }
}

extension ExecutableElementExtension on ExecutableElement {
  bool get isEnumConstructor {
    return this is ConstructorElement && enclosingElement3 is EnumElementImpl;
  }
}

extension ParameterElementExtensions on ParameterElement {
  /// Return [ParameterElement] with the specified properties replaced.
  ParameterElement copyWith({
    DartType? type,
    ParameterKind? kind,
    bool? isCovariant,
  }) {
    return ParameterElementImpl.synthetic(
      name,
      type ?? this.type,
      // ignore: deprecated_member_use_from_same_package
      kind ?? parameterKind,
    )..isExplicitlyCovariant = isCovariant ?? this.isCovariant;
  }
}

extension RecordTypeExtension on RecordType {
  /// A regular expression used to match positional field names.
  static final RegExp _positionalName = RegExp(r'^\$([0-9]+)$');

  /// The [name] is either an actual name like `foo` in `({int foo})`, or
  /// the name of a positional field like `$0` in `(int, String)`.
  RecordTypeField? fieldByName(String name) {
    return namedField(name) ?? positionalField(name);
  }

  RecordTypeNamedField? namedField(String name) {
    for (final field in namedFields) {
      if (field.name == name) {
        return field;
      }
    }
    return null;
  }

  RecordTypePositionalField? positionalField(String name) {
    final match = _positionalName.firstMatch(name);
    if (match != null) {
      final index = int.tryParse(match.group(1)!);
      if (index != null && index < positionalFields.length) {
        return positionalFields[index];
      }
    }
    return null;
  }
}
