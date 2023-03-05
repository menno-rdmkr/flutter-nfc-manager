import 'dart:async';

import 'package:nfc_manager/src/nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/src/nfc_manager_android/pigeon.dart';
import 'package:nfc_manager/src/nfc_manager_android/pigeon.g.dart';

// TODO: DOC
class NfcManagerAndroid {
  NfcManagerAndroid._() {
    _NfcManagerAndroidFlutterApi(this);
  }

  // TODO: DOC
  static NfcManagerAndroid get instance => _instance ??= NfcManagerAndroid._();
  static NfcManagerAndroid? _instance;

  // TODO: DOC
  final StreamController<int> _onStateChanged = StreamController.broadcast();
  Stream<int> get onStateChanged => _onStateChanged.stream;

  void Function(NfcTag)? _onTagDiscovered;

  // TODO: DOC
  Future<bool> isEnabled() {
    return hostApi.nfcAdapterIsEnabled();
  }

  // TODO: DOC
  Future<bool> isSecureNfcEnabled() {
    return hostApi.nfcAdapterIsSecureNfcEnabled();
  }

  // TODO: DOC
  Future<bool> isSecureNfcSupported() {
    return hostApi.nfcAdapterIsSecureNfcSupported();
  }

  // TODO: DOC
  Future<void> enableReaderMode({
    required Set<NfcReaderFlagAndroid> flags,
    required void Function(NfcTag) onTagDiscovered,
  }) {
    _onTagDiscovered = onTagDiscovered;
    return hostApi.nfcAdapterEnableReaderMode(
      flags: flags.map((e) => PigeonReaderFlag.values.byName(e.name)).toList(),
    );
  }

  // TODO: DOC
  Future<void> disableReaderMode() {
    _onTagDiscovered = null;
    return hostApi.nfcAdapterDisableReaderMode();
  }

  // TODO: DOC
  Future<void> enableForegroundDispatch() {
    return hostApi.nfcAdapterEnableForegroundDispatch();
  }

  // TODO: DOC
  Future<void> disableForegroundDispatch() {
    return hostApi.nfcAdapterDisableForegroundDispatch();
  }
}

class _NfcManagerAndroidFlutterApi implements PigeonFlutterApi {
  _NfcManagerAndroidFlutterApi(this._instance) {
    PigeonFlutterApi.setUp(this);
  }

  final NfcManagerAndroid _instance;

  @override
  void onAdapterStateChanged(int state) {
    _instance._onStateChanged.sink.add(state);
  }

  @override
  void onTagDiscovered(PigeonTag tag) {
    _instance._onTagDiscovered?.call(
      // ignore: invalid_use_of_visible_for_testing_member
      NfcTag(data: tag),
    );
  }
}

// TODO: DOC
enum NfcReaderFlagAndroid {
  // TODO: DOC
  nfcA,

  // TODO: DOC
  nfcB,

  // TODO: DOC
  nfcBarcode,

  // TODO: DOC
  nfcF,

  // TODO: DOC
  nfcV,

  // TODO: DOC
  noPlatformSounds,

  // TODO: DOC
  skipNdefCheck,
}
