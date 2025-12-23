// Copyright (c) 2024. Markdown generator for dartdoc.

import 'dart:io';

import 'package:dartdoc/src/model/model.dart';
import 'package:dartdoc/src/model_utils.dart';
import 'package:path/path.dart' as p;

/// Generates Markdown documentation from PackageGraph.
class MarkdownGenerator {
  final String outputDir;
  final bool verbose;

  MarkdownGenerator(this.outputDir, {this.verbose = false});

  void generate(PackageGraph packageGraph) {
    // 创建输出目录
    Directory(outputDir).createSync(recursive: true);

    // 生成包索引
    _generatePackageIndex(packageGraph);

    for (var package in packageGraph.localPackages) {
      _log('Generating docs for package: ${package.name}');

      for (var library in package.libraries.whereDocumented) {
        _generateLibrary(library);
      }
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

  /// 移除 HTML 标签
  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  void _writeFile(String relativePath, String content) {
    var file = File(p.join(outputDir, relativePath));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    _log('  Written: $relativePath');
  }
}
