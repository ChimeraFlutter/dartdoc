// Copyright (c) 2024. Markdown generator for dartdoc.

import 'dart:io';

import 'package:dartdoc/src/model/model.dart';
import 'package:dartdoc/src/model_utils.dart';
import 'package:path/path.dart' as p;

/// Generates Markdown documentation from PackageGraph.
class MarkdownGenerator {
  final String outputDir;
  final bool verbose;
  final bool simple;
  final String projectRoot;

  MarkdownGenerator(this.outputDir, {this.verbose = false, this.simple = false, this.projectRoot = ''});

  void generate(PackageGraph packageGraph) {
    // 创建输出目录
    Directory(outputDir).createSync(recursive: true);

    // 生成包索引 (非 simple 模式)
    if (!simple) {
      _generatePackageIndex(packageGraph);
    }

    // 只为默认包（项目自己的包）生成文档
    var defaultPackage = packageGraph.defaultPackage;
    _log('Generating docs for package: ${defaultPackage.name}');

    for (var library in defaultPackage.libraries.whereDocumented) {
      // 过滤掉 packages/ 目录下的库，只保留 lib/ 目录的库
      var sourcePath = library.element.firstFragment.source.fullName;
      if (sourcePath.contains('/packages/') || sourcePath.contains('\\packages\\')) {
        continue;
      }
      _generateLibrary(library);
    }

    _log('Markdown generation complete!');
  }

  void _log(String message) {
    if (verbose) print(message);
  }

  void _generatePackageIndex(PackageGraph packageGraph) {
    var md = StringBuffer();
    var package = packageGraph.defaultPackage;

    md.writeln('# ${package.name}');
    md.writeln();

    if (package.hasDocumentation) {
      md.writeln(package.documentation);
      md.writeln();
    }

    md.writeln('## Libraries');
    md.writeln();

    for (var lib in package.libraries.whereDocumented) {
      md.writeln('- [${lib.name}](${_sanitizeFileName(lib.name)}/README.md)');
    }

    _writeFile('README.md', md.toString());
  }

  void _generateLibrary(Library library) {
    if (simple) {
      _generateLibrarySimple(library, '');
      return;
    }

    var libDir = p.join(outputDir, _sanitizeFileName(library.name));
    Directory(libDir).createSync(recursive: true);

    var md = StringBuffer();

    md.writeln('# ${library.name} library');
    md.writeln();

    if (library.hasDocumentation) {
      md.writeln(library.documentation);
      md.writeln();
    }

    // Classes
    var classes = library.classes.whereDocumented.toList();
    if (classes.isNotEmpty) {
      md.writeln('## Classes');
      md.writeln();
      for (var class_ in classes) {
        md.writeln(
            '- [${class_.name}](${_sanitizeFileName(class_.name)}.md) - ${_firstLine(class_.oneLineDoc)}');
        _generateClass(class_, libDir);
      }
      md.writeln();
    }

    // Enums
    var enums = library.enums.whereDocumented.toList();
    if (enums.isNotEmpty) {
      md.writeln('## Enums');
      md.writeln();
      for (var enum_ in enums) {
        md.writeln(
            '- [${enum_.name}](${_sanitizeFileName(enum_.name)}.md) - ${_firstLine(enum_.oneLineDoc)}');
        _generateEnum(enum_, libDir);
      }
      md.writeln();
    }

    // Mixins
    var mixins = library.mixins.whereDocumented.toList();
    if (mixins.isNotEmpty) {
      md.writeln('## Mixins');
      md.writeln();
      for (var mixin in mixins) {
        md.writeln(
            '- [${mixin.name}](${_sanitizeFileName(mixin.name)}.md) - ${_firstLine(mixin.oneLineDoc)}');
        _generateMixin(mixin, libDir);
      }
      md.writeln();
    }

    // Extensions
    var extensions = library.extensions.whereDocumented.toList();
    if (extensions.isNotEmpty) {
      md.writeln('## Extensions');
      md.writeln();
      for (var ext in extensions) {
        md.writeln(
            '- [${ext.name}](${_sanitizeFileName(ext.name)}.md) - ${_firstLine(ext.oneLineDoc)}');
        _generateExtension(ext, libDir);
      }
      md.writeln();
    }

    // Top-level functions
    var functions = library.functions.whereDocumented.toList();
    if (functions.isNotEmpty) {
      md.writeln('## Functions');
      md.writeln();
      for (var func in functions) {
        md.writeln('### ${func.name}');
        md.writeln();
        md.writeln('```dart');
        md.writeln('${_stripHtml(func.modelType.returnType.linkedName)} ${func.name}(${_formatParameters(func.parameters)})');
        md.writeln('```');
        md.writeln();
        if (func.hasDocumentation) {
          md.writeln(func.documentation);
          md.writeln();
        }
      }
    }

    // Top-level variables/constants
    var constants = library.constants.whereDocumented.toList();
    if (constants.isNotEmpty) {
      md.writeln('## Constants');
      md.writeln();
      for (var constant in constants) {
        md.writeln('### ${constant.name}');
        md.writeln();
        md.writeln('```dart');
        md.writeln('const ${_stripHtml(constant.modelType.linkedName)} ${constant.name}');
        md.writeln('```');
        md.writeln();
        if (constant.hasDocumentation) {
          md.writeln(constant.documentation);
          md.writeln();
        }
      }
    }

    _writeFile(p.join(_sanitizeFileName(library.name), 'README.md'), md.toString());
  }

  void _generateClass(Class class_, String libDir) {
    var md = StringBuffer();

    md.writeln('# ${class_.name}');
    md.writeln();

    // 类签名
    md.writeln('```dart');
    var signature = StringBuffer();
    if (class_.isAbstract) signature.write('abstract ');
    signature.write('class ${class_.name}');
    if (class_.hasPublicSuperChainReversed) {
      var superTypes = class_.publicSuperChainReversed.map((e) => e.name).toList();
      if (superTypes.isNotEmpty) {
        signature.write(' extends ${superTypes.last}');
      }
    }
    md.writeln(signature.toString());
    md.writeln('```');
    md.writeln();

    // 文档
    if (class_.hasDocumentation) {
      md.writeln(class_.documentation);
      md.writeln();
    }

    // 构造函数
    var constructors = class_.constructors.whereDocumented.toList();
    if (constructors.isNotEmpty) {
      md.writeln('## Constructors');
      md.writeln();
      for (var ctor in constructors) {
        md.writeln('### ${ctor.name.isEmpty ? class_.name : ctor.name}');
        md.writeln();
        md.writeln('```dart');
        md.writeln('${class_.name}(${_formatParameters(ctor.parameters)})');
        md.writeln('```');
        md.writeln();
        if (ctor.hasDocumentation) {
          md.writeln(ctor.documentation);
          md.writeln();
        }
      }
    }

    // 属性
    var fields = class_.instanceFields.whereDocumented.toList();
    if (fields.isNotEmpty) {
      md.writeln('## Properties');
      md.writeln();
      for (var field in fields) {
        md.writeln('### ${field.name}');
        md.writeln();
        md.writeln('```dart');
        md.writeln('${_stripHtml(field.modelType.linkedName)} ${field.name}');
        md.writeln('```');
        md.writeln();
        if (field.hasDocumentation) {
          md.writeln(field.documentation);
          md.writeln();
        }
      }
    }

    // 方法
    var methods = class_.instanceMethods.whereDocumented.toList();
    if (methods.isNotEmpty) {
      md.writeln('## Methods');
      md.writeln();
      for (var method in methods) {
        md.writeln('### ${method.name}');
        md.writeln();
        md.writeln('```dart');
        md.writeln('${_stripHtml(method.modelType.returnType.linkedName)} ${method.name}(${_formatParameters(method.parameters)})');
        md.writeln('```');
        md.writeln();
        if (method.hasDocumentation) {
          md.writeln(method.documentation);
          md.writeln();
        }
      }
    }

    // 静态方法
    var staticMethods = class_.staticMethods.whereDocumented.toList();
    if (staticMethods.isNotEmpty) {
      md.writeln('## Static Methods');
      md.writeln();
      for (var method in staticMethods) {
        md.writeln('### ${method.name}');
        md.writeln();
        md.writeln('```dart');
        md.writeln('static ${_stripHtml(method.modelType.returnType.linkedName)} ${method.name}(${_formatParameters(method.parameters)})');
        md.writeln('```');
        md.writeln();
        if (method.hasDocumentation) {
          md.writeln(method.documentation);
          md.writeln();
        }
      }
    }

    // 操作符
    var operators = class_.instanceOperators.whereDocumented.toList();
    if (operators.isNotEmpty) {
      md.writeln('## Operators');
      md.writeln();
      for (var op in operators) {
        md.writeln('### operator ${op.name}');
        md.writeln();
        md.writeln('```dart');
        md.writeln('${_stripHtml(op.modelType.returnType.linkedName)} operator ${op.name}(${_formatParameters(op.parameters)})');
        md.writeln('```');
        md.writeln();
        if (op.hasDocumentation) {
          md.writeln(op.documentation);
          md.writeln();
        }
      }
    }

    File(p.join(libDir, '${_sanitizeFileName(class_.name)}.md'))
        .writeAsStringSync(md.toString());
  }

  void _generateEnum(Enum enum_, String libDir) {
    var md = StringBuffer();

    md.writeln('# ${enum_.name}');
    md.writeln();

    md.writeln('```dart');
    md.writeln('enum ${enum_.name}');
    md.writeln('```');
    md.writeln();

    if (enum_.hasDocumentation) {
      md.writeln(enum_.documentation);
      md.writeln();
    }

    // 枚举值
    var values = enum_.constantFields.toList();
    if (values.isNotEmpty) {
      md.writeln('## Values');
      md.writeln();
      for (var value in values) {
        md.writeln('### ${value.name}');
        md.writeln();
        if (value.hasDocumentation) {
          md.writeln(value.documentation);
          md.writeln();
        }
      }
    }

    File(p.join(libDir, '${_sanitizeFileName(enum_.name)}.md'))
        .writeAsStringSync(md.toString());
  }

  void _generateMixin(Mixin mixin, String libDir) {
    var md = StringBuffer();

    md.writeln('# ${mixin.name}');
    md.writeln();

    md.writeln('```dart');
    md.writeln('mixin ${mixin.name}');
    md.writeln('```');
    md.writeln();

    if (mixin.hasDocumentation) {
      md.writeln(mixin.documentation);
      md.writeln();
    }

    // 方法
    var methods = mixin.instanceMethods.whereDocumented.toList();
    if (methods.isNotEmpty) {
      md.writeln('## Methods');
      md.writeln();
      for (var method in methods) {
        md.writeln('### ${method.name}');
        md.writeln();
        md.writeln('```dart');
        md.writeln('${_stripHtml(method.modelType.returnType.linkedName)} ${method.name}(${_formatParameters(method.parameters)})');
        md.writeln('```');
        md.writeln();
        if (method.hasDocumentation) {
          md.writeln(method.documentation);
          md.writeln();
        }
      }
    }

    File(p.join(libDir, '${_sanitizeFileName(mixin.name)}.md'))
        .writeAsStringSync(md.toString());
  }

  void _generateExtension(Extension ext, String libDir) {
    var md = StringBuffer();

    md.writeln('# ${ext.name}');
    md.writeln();

    md.writeln('```dart');
    md.writeln('extension ${ext.name}');
    md.writeln('```');
    md.writeln();

    if (ext.hasDocumentation) {
      md.writeln(ext.documentation);
      md.writeln();
    }

    // 方法
    var methods = ext.instanceMethods.whereDocumented.toList();
    if (methods.isNotEmpty) {
      md.writeln('## Methods');
      md.writeln();
      for (var method in methods) {
        md.writeln('### ${method.name}');
        md.writeln();
        md.writeln('```dart');
        md.writeln('${_stripHtml(method.modelType.returnType.linkedName)} ${method.name}(${_formatParameters(method.parameters)})');
        md.writeln('```');
        md.writeln();
        if (method.hasDocumentation) {
          md.writeln(method.documentation);
          md.writeln();
        }
      }
    }

    File(p.join(libDir, '${_sanitizeFileName(ext.name)}.md'))
        .writeAsStringSync(md.toString());
  }

  String _formatParameters(List<Parameter> params) {
    if (params.isEmpty) return '';
    return params.map((p) {
      var result = '${_stripHtml(p.modelType.linkedName)} ${p.name}';
      if (p.hasDefaultValue) {
        result += ' = ${p.defaultValue}';
      }
      return result;
    }).join(', ');
  }

  String _firstLine(String text) {
    if (text.isEmpty) return '';
    var lines = text.split('\n');
    var first = lines.first.trim();
    if (first.length > 80) {
      return '${first.substring(0, 77)}...';
    }
    return first;
  }

  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }

  /// 移除 HTML 标签和实体
  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&');
  }

  void _writeFile(String relativePath, String content) {
    var file = File(p.join(outputDir, relativePath));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    _log('  Written: $relativePath');
  }

  // ========== Simple Mode ==========

  String _relativePath(String absolutePath) {
    if (projectRoot.isNotEmpty && absolutePath.startsWith(projectRoot)) {
      return absolutePath.substring(projectRoot.length).replaceFirst(RegExp(r'^[/\\]'), '');
    }
    return absolutePath;
  }

  void _generateLibrarySimple(Library library, String libDir) {
    // 按源文件分组
    var fileGroups = <String, List<dynamic>>{};

    for (var class_ in library.classes) {
      var file = class_.sourceFileName;
      fileGroups.putIfAbsent(file, () => []).add(class_);
    }
    for (var enum_ in library.enums) {
      var file = enum_.sourceFileName;
      fileGroups.putIfAbsent(file, () => []).add(enum_);
    }
    for (var mixin in library.mixins) {
      var file = mixin.sourceFileName;
      fileGroups.putIfAbsent(file, () => []).add(mixin);
    }
    for (var ext in library.extensions) {
      var file = ext.sourceFileName;
      fileGroups.putIfAbsent(file, () => []).add(ext);
    }
    for (var func in library.functions) {
      var file = func.sourceFileName;
      fileGroups.putIfAbsent(file, () => []).add(func);
    }
    for (var prop in [...library.constants, ...library.properties]) {
      var file = prop.sourceFileName;
      fileGroups.putIfAbsent(file, () => []).add(prop);
    }

    // 为每个源文件生成对应的 md 文件
    for (var entry in fileGroups.entries) {
      var sourceFile = entry.key;
      var elements = entry.value;
      var relativeSrc = _relativePath(sourceFile);

      var md = StringBuffer();
      md.writeln('# $relativeSrc');
      md.writeln();

      for (var element in elements) {
        if (element is Class) {
          _generateClassSimple(element, md, sourceFile);
        } else if (element is Enum) {
          _generateEnumSimple(element, md, sourceFile);
        } else if (element is Mixin) {
          _generateMixinSimple(element, md, sourceFile);
        } else if (element is Extension) {
          _generateExtensionSimple(element, md, sourceFile);
        } else if (element is ModelFunction) {
          var line = element.characterLocation?.lineNumber ?? 0;
          var returnType = _stripHtml(element.modelType.returnType.linkedName);
          var params = _formatParams(element.parameters);
          md.writeln('## Function: `$returnType ${element.name}($params)` (line $line)');
          md.writeln();
        } else if (element is TopLevelVariable) {
          var line = element.characterLocation?.lineNumber ?? 0;
          var mods = <String>[];
          if (element.isConst) mods.add('const');
          if (element.isFinal) mods.add('final');
          if (element.isLate) mods.add('late');
          var modPrefix = mods.isNotEmpty ? '[${mods.join(', ')}] ' : '';
          var type = _stripHtml(element.modelType.linkedName);
          md.writeln('## Variable: $modPrefix`$type ${element.name}` (line $line)');
          md.writeln();
        }
      }

      // 输出文件路径与源文件结构一致
      var mdFileName = relativeSrc.replaceAll('.dart', '.md');
      // 过滤掉 packages/ 目录下的文件
      if (mdFileName.startsWith('packages/') || mdFileName.startsWith('packages\\')) {
        continue;
      }
      _writeFile(mdFileName, md.toString());
    }
  }

  void _generateClassSimple(Class class_, StringBuffer md, String sourceFile) {
    var line = class_.characterLocation?.lineNumber ?? 0;

    // Class header with modifiers
    var modifiers = <String>[];
    if (class_.isAbstract) modifiers.add('abstract');
    var modStr = modifiers.isNotEmpty ? '${modifiers.join(' ')} ' : '';
    md.writeln('## ${modStr}class ${class_.name} (line $line)');

    // Inheritance chain
    var supertype = class_.supertype;
    if (supertype != null && supertype.modelElement.name != 'Object') {
      var chain = <String>[supertype.modelElement.name];
      var current = supertype.modelElement;
      while (current is Class && current.supertype != null && current.supertype!.modelElement.name != 'Object') {
        chain.add(current.supertype!.modelElement.name);
        current = current.supertype!.modelElement;
      }
      md.writeln('Extends: `${chain.join(' → ')}`');
    }

    // Mixins (with)
    if (class_.mixedInTypes.isNotEmpty) {
      var mixins = class_.mixedInTypes.map((m) => m.modelElement.name).join(', ');
      md.writeln('Mixins: `$mixins`');
    }

    // Interfaces (implements)
    if (class_.directInterfaces.isNotEmpty) {
      var interfaces = class_.directInterfaces.map((i) => i.modelElement.name).join(', ');
      md.writeln('Implements: `$interfaces`');
    }

    // Subclasses
    if (class_.publicImplementersSorted.isNotEmpty) {
      var subclasses = class_.publicImplementersSorted.map((s) => s.name).join(', ');
      md.writeln('Subclasses: `$subclasses`');
    }

    md.writeln();

    // Constructors
    var ctors = class_.constructors.where((c) => c.sourceFileName == sourceFile).toList();
    if (ctors.isNotEmpty) {
      md.writeln('### Constructors');
      for (var ctor in ctors) {
        var ctorLine = ctor.characterLocation?.lineNumber ?? 0;
        var name = ctor.name.isEmpty ? class_.name : '${class_.name}.${ctor.name}';
        var params = _formatParams(ctor.parameters);
        md.writeln('- `$name($params)` (line $ctorLine)');
      }
      md.writeln();
    }

    // Fields
    var fields = [...class_.instanceFields, ...class_.staticFields]
        .where((f) => f.sourceFileName == sourceFile)
        .toList();
    if (fields.isNotEmpty) {
      md.writeln('### Fields');
      for (var field in fields) {
        var fieldLine = field.characterLocation?.lineNumber ?? 0;
        var mods = <String>[];
        if (field.isStatic) mods.add('static');
        if (field.isConst) mods.add('const');
        if (field.isFinal) mods.add('final');
        if (field.isLate) mods.add('late');
        if (field.isOverride) mods.add('override');
        var modPrefix = mods.isNotEmpty ? '[${mods.join(', ')}] ' : '';
        var type = _stripHtml(field.modelType.linkedName);
        md.writeln('- $modPrefix`$type ${field.name}` (line $fieldLine)');
      }
      md.writeln();
    }

    // Getters
    var getters = class_.instanceFields.where((f) => f.sourceFileName == sourceFile && f.hasExplicitGetter && !f.hasExplicitSetter).toList();
    if (getters.isNotEmpty) {
      md.writeln('### Getters');
      for (var getter in getters) {
        var getterLine = getter.characterLocation?.lineNumber ?? 0;
        var type = _stripHtml(getter.modelType.linkedName);
        md.writeln('- `$type get ${getter.name}` (line $getterLine)');
      }
      md.writeln();
    }

    // Methods
    var methods = [...class_.instanceMethods, ...class_.staticMethods]
        .where((m) => m.sourceFileName == sourceFile)
        .toList();
    if (methods.isNotEmpty) {
      md.writeln('### Methods');
      for (var method in methods) {
        var methodLine = method.characterLocation?.lineNumber ?? 0;
        var mods = <String>[];
        if (method.isStatic) mods.add('static');
        if (method.element.isAbstract) mods.add('abstract');
        if (method.isOverride) mods.add('override');
        var modPrefix = mods.isNotEmpty ? '[${mods.join(', ')}] ' : '';
        var returnType = _stripHtml(method.modelType.returnType.linkedName);
        var params = _formatParams(method.parameters);
        md.writeln('- $modPrefix`$returnType ${method.name}($params)` (line $methodLine)');
      }
      md.writeln();
    }
  }

  String _formatParams(List<Parameter> params) {
    if (params.isEmpty) return '';
    return params.map((p) {
      var type = _stripHtml(p.modelType.linkedName);
      if (p.isNamed) {
        if (p.isRequiredNamed) {
          return 'required $type ${p.name}';
        }
        return '$type ${p.name}';
      }
      return '$type ${p.name}';
    }).join(', ');
  }

  void _generateEnumSimple(Enum enum_, StringBuffer md, String sourceFile) {
    var line = enum_.characterLocation?.lineNumber ?? 0;

    md.writeln('## enum ${enum_.name}');
    md.writeln('Line: $line');

    // Interfaces (implements)
    if (enum_.directInterfaces.isNotEmpty) {
      var interfaces = enum_.directInterfaces.map((i) => i.modelElement.name).join(', ');
      md.writeln('Implements: `$interfaces`');
    }

    // Mixins
    if (enum_.mixedInTypes.isNotEmpty) {
      var mixins = enum_.mixedInTypes.map((m) => m.modelElement.name).join(', ');
      md.writeln('Mixins: `$mixins`');
    }

    md.writeln();

    // Values
    var values = enum_.constantFields.where((v) => v.sourceFileName == sourceFile).toList();
    if (values.isNotEmpty) {
      md.writeln('### Values');
      for (var value in values) {
        var valueLine = value.characterLocation?.lineNumber ?? 0;
        md.writeln('- `${value.name}` (line $valueLine)');
      }
      md.writeln();
    }

    // Constructors
    var ctors = enum_.constructors.where((c) => c.sourceFileName == sourceFile).toList();
    if (ctors.isNotEmpty) {
      md.writeln('### Constructors');
      for (var ctor in ctors) {
        var ctorLine = ctor.characterLocation?.lineNumber ?? 0;
        var name = ctor.name.isEmpty ? enum_.name : '${enum_.name}.${ctor.name}';
        var params = _formatParams(ctor.parameters);
        md.writeln('- `$name($params)` (line $ctorLine)');
      }
      md.writeln();
    }

    // Fields
    var fields = enum_.instanceFields.where((f) => f.sourceFileName == sourceFile).toList();
    if (fields.isNotEmpty) {
      md.writeln('### Fields');
      for (var field in fields) {
        var fieldLine = field.characterLocation?.lineNumber ?? 0;
        var mods = <String>[];
        if (field.isFinal) mods.add('final');
        var modPrefix = mods.isNotEmpty ? '[${mods.join(', ')}] ' : '';
        var type = _stripHtml(field.modelType.linkedName);
        md.writeln('- $modPrefix`$type ${field.name}` (line $fieldLine)');
      }
      md.writeln();
    }

    // Methods
    var methods = enum_.instanceMethods.where((m) => m.sourceFileName == sourceFile).toList();
    if (methods.isNotEmpty) {
      md.writeln('### Methods');
      for (var method in methods) {
        var methodLine = method.characterLocation?.lineNumber ?? 0;
        var mods = <String>[];
        if (method.isOverride) mods.add('override');
        var modPrefix = mods.isNotEmpty ? '[${mods.join(', ')}] ' : '';
        var returnType = _stripHtml(method.modelType.returnType.linkedName);
        var params = _formatParams(method.parameters);
        md.writeln('- $modPrefix`$returnType ${method.name}($params)` (line $methodLine)');
      }
      md.writeln();
    }
  }

  void _generateMixinSimple(Mixin mixin, StringBuffer md, String sourceFile) {
    var line = mixin.characterLocation?.lineNumber ?? 0;

    md.writeln('## mixin ${mixin.name}');
    md.writeln('Line: $line');

    // Superclass constraint (on)
    if (mixin.superclassConstraints.isNotEmpty) {
      var constraints = mixin.superclassConstraints.map((c) => c.modelElement.name).join(', ');
      md.writeln('On: `$constraints`');
    }

    // Interfaces (implements)
    if (mixin.directInterfaces.isNotEmpty) {
      var interfaces = mixin.directInterfaces.map((i) => i.modelElement.name).join(', ');
      md.writeln('Implements: `$interfaces`');
    }

    md.writeln();

    // Fields
    var fields = [...mixin.instanceFields, ...mixin.staticFields]
        .where((f) => f.sourceFileName == sourceFile)
        .toList();
    if (fields.isNotEmpty) {
      md.writeln('### Fields');
      for (var field in fields) {
        var fieldLine = field.characterLocation?.lineNumber ?? 0;
        var mods = <String>[];
        if (field.isStatic) mods.add('static');
        if (field.isFinal) mods.add('final');
        if (field.isLate) mods.add('late');
        var modPrefix = mods.isNotEmpty ? '[${mods.join(', ')}] ' : '';
        var type = _stripHtml(field.modelType.linkedName);
        md.writeln('- $modPrefix`$type ${field.name}` (line $fieldLine)');
      }
      md.writeln();
    }

    // Methods
    var methods = [...mixin.instanceMethods, ...mixin.staticMethods]
        .where((m) => m.sourceFileName == sourceFile)
        .toList();
    if (methods.isNotEmpty) {
      md.writeln('### Methods');
      for (var method in methods) {
        var methodLine = method.characterLocation?.lineNumber ?? 0;
        var mods = <String>[];
        if (method.isStatic) mods.add('static');
        if (method.element.isAbstract) mods.add('abstract');
        if (method.isOverride) mods.add('override');
        var modPrefix = mods.isNotEmpty ? '[${mods.join(', ')}] ' : '';
        var returnType = _stripHtml(method.modelType.returnType.linkedName);
        var params = _formatParams(method.parameters);
        md.writeln('- $modPrefix`$returnType ${method.name}($params)` (line $methodLine)');
      }
      md.writeln();
    }
  }

  void _generateExtensionSimple(Extension ext, StringBuffer md, String sourceFile) {
    var line = ext.characterLocation?.lineNumber ?? 0;

    md.writeln('## extension ${ext.name}');
    md.writeln('Line: $line');

    // Target type (on)
    var extendedType = _stripHtml(ext.extendedElement.linkedName);
    md.writeln('On: `$extendedType`');

    md.writeln();

    // Fields
    var fields = ext.instanceFields.where((f) => f.sourceFileName == sourceFile).toList();
    if (fields.isNotEmpty) {
      md.writeln('### Fields');
      for (var field in fields) {
        var fieldLine = field.characterLocation?.lineNumber ?? 0;
        var type = _stripHtml(field.modelType.linkedName);
        md.writeln('- `$type ${field.name}` (line $fieldLine)');
      }
      md.writeln();
    }

    // Methods
    var methods = ext.instanceMethods.where((m) => m.sourceFileName == sourceFile).toList();
    if (methods.isNotEmpty) {
      md.writeln('### Methods');
      for (var method in methods) {
        var methodLine = method.characterLocation?.lineNumber ?? 0;
        var returnType = _stripHtml(method.modelType.returnType.linkedName);
        var params = _formatParams(method.parameters);
        md.writeln('- `$returnType ${method.name}($params)` (line $methodLine)');
      }
      md.writeln();
    }
  }
}
