// Copyright (c) 2024. Markdown documentation generator.
//
// Usage:
//   dart run bin/dartdoc_md.dart [options]
//
// Options:
//   --input, -i     Input directory (default: current directory)
//   --output, -o    Output directory (default: doc/md)
//   --verbose, -v   Verbose output

import 'dart:io';

import 'package:args/args.dart';
import 'package:dartdoc/src/dartdoc_options.dart';
import 'package:dartdoc/src/markdown_generator.dart';
import 'package:dartdoc/src/model/model.dart';
import 'package:dartdoc/src/package_config_provider.dart';
import 'package:dartdoc/src/package_meta.dart';

void main(List<String> arguments) async {
  var parser = ArgParser()
    ..addOption('input', abbr: 'i', help: 'Input directory', defaultsTo: '.')
    ..addOption('output', abbr: 'o', help: 'Output directory', defaultsTo: 'doc/md')
    ..addFlag('verbose', abbr: 'v', help: 'Verbose output', defaultsTo: false)
    ..addFlag('simple', abbr: 's', help: 'Simple output (file path, variables, functions with line numbers)', defaultsTo: false)
    ..addFlag('help', abbr: 'h', help: 'Show help', negatable: false);

  ArgResults args;
  try {
    args = parser.parse(arguments);
  } catch (e) {
    print('Error: $e');
    print('Usage: dart run bin/dartdoc_md.dart [options]');
    print(parser.usage);
    exit(1);
  }

  if (args['help'] as bool) {
    print('Dartdoc Markdown Generator');
    print('');
    print('Usage: dart run bin/dartdoc_md.dart [options]');
    print('');
    print(parser.usage);
    exit(0);
  }

  var inputDir = args['input'] as String;
  var outputDir = args['output'] as String;
  var verbose = args['verbose'] as bool;
  var simple = args['simple'] as bool;

  print('Dartdoc Markdown Generator');
  print('Input: $inputDir');
  print('Output: $outputDir');
  print('');

  try {
    // 构建 PackageGraph
    print('Building package graph...');

    var config = parseOptions(pubPackageMetaProvider, [
      '--input', inputDir,
      '--output', outputDir,
    ]);

    if (config == null) {
      print('Error: Failed to parse options');
      exit(1);
    }

    var packageConfigProvider = PhysicalPackageConfigProvider();
    var packageBuilder = PubPackageBuilder(
      config,
      pubPackageMetaProvider,
      packageConfigProvider,
    );

    var packageGraph = await packageBuilder.buildPackageGraph();

    print('Found ${packageGraph.libraryCount} libraries');
    print('');

    // 生成 Markdown
    print('Generating Markdown documentation...');
    var absoluteInputDir = Directory(inputDir).absolute.path;
    var generator = MarkdownGenerator(outputDir, verbose: verbose, simple: simple, projectRoot: absoluteInputDir);
    generator.generate(packageGraph);

    print('');
    print('Done! Documentation generated in: $outputDir');

    // 清理
    packageGraph.dispose();
  } catch (e, stack) {
    print('Error: $e');
    if (verbose) {
      print(stack);
    }
    exit(1);
  }
}
