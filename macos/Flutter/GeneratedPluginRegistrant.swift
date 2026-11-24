//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import audio_session
import cryptography_flutter
import file_selector_macos
import flutter_secure_storage_darwin
import just_audio
import record_darwin
import sqflite_darwin
import sqflite_sqlcipher
import video_player_avfoundation

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  AudioSessionPlugin.register(with: registry.registrar(forPlugin: "AudioSessionPlugin"))
  CryptographyFlutterPlugin.register(with: registry.registrar(forPlugin: "CryptographyFlutterPlugin"))
  FileSelectorPlugin.register(with: registry.registrar(forPlugin: "FileSelectorPlugin"))
  FlutterSecureStorageDarwinPlugin.register(with: registry.registrar(forPlugin: "FlutterSecureStorageDarwinPlugin"))
  JustAudioPlugin.register(with: registry.registrar(forPlugin: "JustAudioPlugin"))
  RecordDarwinPlugin.register(with: registry.registrar(forPlugin: "RecordDarwinPlugin"))
  SqflitePlugin.register(with: registry.registrar(forPlugin: "SqflitePlugin"))
  SqfliteSqlCipherPlugin.register(with: registry.registrar(forPlugin: "SqfliteSqlCipherPlugin"))
  VideoPlayerPlugin.register(with: registry.registrar(forPlugin: "VideoPlayerPlugin"))
}
