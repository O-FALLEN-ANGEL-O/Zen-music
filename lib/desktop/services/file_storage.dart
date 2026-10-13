// ZenMusic Desktop — ported from Echo Music (GPL-3.0), services/file_storage.dart.
// Echo Music is Copyright (C) the Echo Music authors; this port and ZenMusic
// remain GPL-3.0 (https://github.com/vorlon-dev/Zen-music).
// PORT DEVIATIONS:
//  1. loadBackup() STUBBED for R8e — its only caller is the backup/restore
//     settings UI (not vendored yet), and file_picker 13 restructured its API
//     surface (unverified). The real implementation lands with R8e against
//     the package's actual source. All other FileStorage paths are verbatim.
//  2. Windows folder 'Echo' -> 'ZenMusic' (branding). The BACKUP FORMAT check
//     ('name' != 'Echo') stays verbatim — revisit at R8e with the backup UI.
//  3. Unused upstream imports (http, enhanced_image) kept verbatim — benign
//     info-level lints.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';

import '../utils/enhanced_image.dart';
import '../ytmusic/ytmusic.dart';
import 'library.dart';
import 'settings_manager.dart';

class FileStorage {
  static bool _initialised = false;
  static final String defaultPath = '/storage/emulated/0/Download/';
  static late StoragePaths _storagePaths;
  late StoragePaths storagePaths;
  FileStorage() {
    if (!_initialised) {
      throw 'file Storage is Not Initialised. try calling `await FileStorage.initialise()`';
    }
    storagePaths = _storagePaths;
  }

  static Future<void> initialise() async {
    Directory directory = Directory("dir");
    if (Platform.isAndroid) {
      directory = Directory(Hive.box('SETTINGS')
          .get('APP_FOLDER', defaultValue: FileStorage.defaultPath));
    } else if (Platform.isWindows) {
      directory = Directory(
          path.join((await getDownloadsDirectory())!.path, 'ZenMusic'));
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    _storagePaths = StoragePaths(
      basePath: directory.path,
      backupPath: path.join(directory.path, 'Back Up'),
      musicPath: path.join(directory.path, 'Music'),
    );
    await _getDirectory(_storagePaths.backupPath);
    await _getDirectory(_storagePaths.musicPath);
    _initialised = true;
  }

  Future<void> updateDirectories() async {
    Directory directory = Directory("dir");
    if (Platform.isAndroid) {
      directory = Directory(Hive.box('SETTINGS')
          .get('APP_FOLDER', defaultValue: FileStorage.defaultPath) +
          '/Echo');
    } else if (Platform.isWindows) {
      directory = Directory(
          path.join((await getDownloadsDirectory())!.path, 'ZenMusic'));
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
    storagePaths = StoragePaths(
      basePath: directory.path,
      backupPath: path.join(directory.path, 'Back Up'),
      musicPath: path.join(directory.path, 'Music'),
    );
    await _getDirectory(_storagePaths.backupPath);
    await _getDirectory(_storagePaths.musicPath);
    _initialised = true;
  }

  Future<String> saveBackUp(Map data) async {
    String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    String fileName = '${timestamp}_backup';
    if (!(await requestPermissions())) return "";
    Directory directory = await _getDirectory(storagePaths.backupPath);

    String filePath = path.join(directory.path, '$fileName.json');
    File file = File(filePath);
    try {
      if (await file.exists()) {
        await file.delete();
      }
      File result = await file.writeAsString(jsonEncode(data), flush: true);
      return result.path;
    } catch (e) {
      rethrow;
    }
  }

  Future<String> shareBackUp(Map data) async {
    String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    String fileName = '${timestamp}_backup.json';
    try {
      final params = ShareParams(files: [
        XFile.fromData(utf8.encode(jsonEncode(data)), mimeType: 'text/plain')
      ], fileNameOverrides: [
        fileName
      ]);
      ShareResult result = await SharePlus.instance.share(params);
      return result.raw;
    } catch (e) {
      rethrow;
    }
  }

  Future<File?> saveMusic(List<int> data, Map song, {extension = 'm4a'}) async {
    String fileName = song['title'];
    final RegExp avoid = RegExp(r'[\.\\\*\:\(\)\"\?#/;\|]');
    fileName = fileName.replaceAll(avoid, '').replaceAll("'", '');
    //fileName = Uri.decodeFull(fileName);
    if (!(await requestPermissions())) return null;
    Directory directory = await _getDirectory(storagePaths.musicPath);

    File file = File(path.join(directory.path, '$fileName.$extension'));
    int number = 1;
    while (file.existsSync()) {
      file = File((path.join(directory.path, '$fileName($number).$extension')));
      number++;
    }
    try {
      if (await file.exists()) {
        await file.delete();
      }
      await file.writeAsBytes(data, flush: true);

      await file.writeAsBytes(data, flush: true);
      return file;
    } catch (e) {
      return null;
    }
  }

  Future<bool> loadBackup() async {
    // R8e STUB (see header, deviation 1): caller is the R8e settings/backup UI.
    // file_picker 13's restructured API must be verified from package source
    // before this is implemented.
    throw UnimplementedError('loadBackup arrives with the R8e settings round');
  }

  static Future<Directory> _getDirectory(String pathString) async {
    Directory dir = Directory(pathString);
    if (!(await dir.exists())) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<bool> requestPermissions() async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      // Desktop platforms do not need permission
      return true;
    }

    if (Platform.isIOS) {
      // iOS app-specific storage doesn't require permission
      return true;
    }

    bool isGranted = false;

    if (Platform.isAndroid) {
      int sdkInt = (await _getAndroidSdkInt()) ?? 30;

      if (sdkInt >= 30) {
        // Android 11+ requires MANAGE_EXTERNAL_STORAGE for arbitrary access
        isGranted = await Permission.manageExternalStorage.isGranted;
        if (!isGranted) {
          await Permission.manageExternalStorage.request();
          isGranted = await Permission.manageExternalStorage.isGranted;
        }
      } else {
        // Android < 11 uses standard storage permission
        isGranted = await Permission.storage.isGranted;
        if (!isGranted) {
          await Permission.storage.request();
          isGranted = await Permission.storage.isGranted;
        }
      }

      if (!isGranted) {
        // Open settings if permission denied
        await openAppSettings();
      }
    }

    return isGranted;
  }

  // Helper function to get Android SDK version
  static Future<int?> _getAndroidSdkInt() async {
    try {
      final String? sdkString = await MethodChannel('flutter/platform')
          .invokeMethod<String>('SystemNavigator.getPlatformVersion');
      if (sdkString != null) {
        final match = RegExp(r'Android (\d+)').firstMatch(sdkString);
        if (match != null) return int.tryParse(match.group(1)!);
      }
    } catch (_) {}
    return null;
  }
}

class StoragePaths {
  String basePath;
  String backupPath;
  String musicPath;
  StoragePaths(
      {required this.basePath,
        required this.backupPath,
        required this.musicPath});
}