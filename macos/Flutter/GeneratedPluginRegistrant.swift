//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import agora_rtc_engine
import file_picker
import file_selector_macos
import geolocator_apple
import iris_method_channel
import package_info_plus
import path_provider_foundation
import shared_preferences_foundation
import video_player_avfoundation

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  AgoraRtcNgPlugin.register(with: registry.registrar(forPlugin: "AgoraRtcNgPlugin"))
  FilePickerPlugin.register(with: registry.registrar(forPlugin: "FilePickerPlugin"))
  FileSelectorPlugin.register(with: registry.registrar(forPlugin: "FileSelectorPlugin"))
  GeolocatorPlugin.register(with: registry.registrar(forPlugin: "GeolocatorPlugin"))
  IrisMethodChannelPlugin.register(with: registry.registrar(forPlugin: "IrisMethodChannelPlugin"))
  FPPPackageInfoPlusPlugin.register(with: registry.registrar(forPlugin: "FPPPackageInfoPlusPlugin"))
  PathProviderPlugin.register(with: registry.registrar(forPlugin: "PathProviderPlugin"))
  SharedPreferencesPlugin.register(with: registry.registrar(forPlugin: "SharedPreferencesPlugin"))
  FVPVideoPlayerPlugin.register(with: registry.registrar(forPlugin: "FVPVideoPlayerPlugin"))
}
