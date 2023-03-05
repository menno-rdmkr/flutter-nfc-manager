import 'package:flutter/foundation.dart';
import 'package:nfc_manager/src/nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/src/nfc_manager_ios/pigeon.dart';
import 'package:nfc_manager/src/nfc_manager_ios/pigeon.g.dart';

// TODO: DOC
final class NfcManagerIOS {
  NfcManagerIOS._() {
    _NfcManagerIOSFlutterApi(this);
  }

  // TODO: DOC
  static NfcManagerIOS get instance => _instance ??= NfcManagerIOS._();
  static NfcManagerIOS? _instance;

  void Function(NfcTag)? _tagReaderSessionDidDetectTag;
  void Function()? _tagReaderSessionDidBecomeActive;
  void Function(NfcReaderSessionErrorIOS)?
      _tagReaderSessionDidInvalidateWithError;
  void Function(List<NfcVasResponseIOS>)? _vasReaderSessionDidReceive;
  void Function()? _vasReaderSessionDidBecomeActive;
  void Function(NfcReaderSessionErrorIOS)?
      _vasReaderSessionDidInvalidateWithError;

  // TODO: DOC
  Future<bool> tagReaderSessionReadingAvailable() {
    return hostApi.tagReaderSessionReadingAvailable();
  }

  // TODO: DOC
  Future<void> tagReaderSessionBegin({
    required Set<NfcPollingOption> pollingOptions,
    required void Function(NfcTag)? didDetectTag,
    void Function()? didBecomeActive,
    void Function(NfcReaderSessionErrorIOS)? didInvalidateWithError,
    String? alertMessage,
    bool invalidateAfterFirstRead = true,
  }) {
    _tagReaderSessionDidDetectTag = didDetectTag;
    _tagReaderSessionDidBecomeActive = didBecomeActive;
    _tagReaderSessionDidInvalidateWithError = didInvalidateWithError;
    return hostApi.tagReaderSessionBegin(
      pollingOptions: pollingOptions.map((e) => PigeonPollingOption.values.byName(e.name)).toList(),
      alertMessage: alertMessage,
      invalidateAfterFirstRead: invalidateAfterFirstRead,
    );
  }

  // TODO: DOC
  Future<void> tagReaderSessionInvalidate({
    String? alertMessage,
    String? errorMessage,
  }) {
    _tagReaderSessionDidDetectTag = null;
    _tagReaderSessionDidBecomeActive = null;
    _tagReaderSessionDidInvalidateWithError = null;
    return hostApi.tagReaderSessionInvalidate(
      alertMessage: alertMessage,
      errorMessage: errorMessage,
    );
  }

  // TODO: DOC
  Future<void> tagReaderSessionSetAlertMessage({required String alertMessage}) {
    return hostApi.tagReaderSessionSetAlertMessage(
      alertMessage: alertMessage,
    );
  }

  // TODO: DOC
  Future<void> tagReaderSessionRestartPolling() {
    return hostApi.tagReaderSessionRestartPolling();
  }

  // TODO: DOC
  Future<void> vasReaderSessionBegin({
    required List<NfcVasCommandConfigurationIOS> configurations,
    required void Function(List<NfcVasResponseIOS> configurations) didReceive,
    void Function()? didBecomeActive,
    void Function(NfcReaderSessionErrorIOS error)? didInvalidateWithError,
    String? alertMessage,
  }) {
    _vasReaderSessionDidBecomeActive = didBecomeActive;
    _vasReaderSessionDidInvalidateWithError = didInvalidateWithError;
    _vasReaderSessionDidReceive = didReceive;
    return hostApi.vasReaderSessionBegin(
      configurations: configurations
          .map((e) => PigeonNfcVasCommandConfiguration(
                mode: PigeonNfcVasCommandConfigurationMode.values.byName(
                  e.mode.name,
                ),
                passIdentifier: e.passIdentifier,
                url: e.url?.toString(),
              ))
          .toList(),
      alertMessage: alertMessage,
    );
  }

  // TODO: DOC
  Future<void> vasReaderSessionInvalidate({
    String? alertMessage,
    String? errorMessage,
  }) {
    _vasReaderSessionDidBecomeActive = null;
    _vasReaderSessionDidInvalidateWithError = null;
    _vasReaderSessionDidReceive = null;
    return hostApi.vasReaderSessionInvalidate(
      alertMessage: alertMessage,
      errorMessage: errorMessage,
    );
  }

  // TODO: DOC
  Future<void> vasReaderSessionSetAlertMessage({required String alertMessage}) {
    return hostApi.vasReaderSessionSetAlertMessage(
      alertMessage: alertMessage,
    );
  }
}

class _NfcManagerIOSFlutterApi implements PigeonFlutterApi {
  _NfcManagerIOSFlutterApi(this._instance) {
    PigeonFlutterApi.setUp(this);
  }

  final NfcManagerIOS _instance;

  @override
  void tagReaderSessionDidBecomeActive() {
    _instance._tagReaderSessionDidBecomeActive?.call();
  }

  @override
  void tagReaderSessionDidInvalidateWithError(
    PigeonNfcReaderSessionError error,
  ) {
    _instance._tagReaderSessionDidInvalidateWithError?.call(
      NfcReaderSessionErrorIOS(
        code: NfcReaderErrorCodeIOS.values.byName(error.code.name),
        message: error.message,
      ),
    );
  }

  @override
  void tagReaderSessionDidDetect(PigeonTag tag) {
    _instance._tagReaderSessionDidDetectTag?.call(
      // ignore: invalid_use_of_visible_for_testing_member
      NfcTag(data: tag),
    );
  }

  @override
  void vasReaderSessionDidBecomeActive() {
    _instance._vasReaderSessionDidBecomeActive?.call();
  }

  @override
  void vasReaderSessionDidInvalidateWithError(
    PigeonNfcReaderSessionError error,
  ) {
    _instance._vasReaderSessionDidInvalidateWithError?.call(
      NfcReaderSessionErrorIOS(
        code: NfcReaderErrorCodeIOS.values.byName(error.code.name),
        message: error.message,
      ),
    );
  }

  @override
  void vasReaderSessionDidReceive(List<PigeonNfcVasResponse?> responses) {
    _instance._vasReaderSessionDidReceive?.call(responses
        .map((e) => NfcVasResponseIOS(
              status: NfcVasResponseErrorCodeIOS.values.byName(e!.status.name),
              vasData: e.vasData,
              mobileToken: e.mobileToken,
            ))
        .toList());
  }
}

// TODO: DOC
final class NfcVasCommandConfigurationIOS {
  // TODO: DOC
  @visibleForTesting
  const NfcVasCommandConfigurationIOS({
    required this.mode,
    required this.passIdentifier,
    this.url,
  });

  // TODO: DOC
  final NfcVasCommandConfigurationModeIOS mode;

  // TODO: DOC
  final String passIdentifier;

  // TODO: DOC
  final Uri? url;
}

// TODO: DOC
final class NfcVasResponseIOS {
  // TODO: DOC
  @visibleForTesting
  const NfcVasResponseIOS({
    required this.status,
    required this.vasData,
    required this.mobileToken,
  });

  // TODO: DOC
  final NfcVasResponseErrorCodeIOS status;

  // TODO: DOC
  final Uint8List vasData;

  // TODO: DOC
  final Uint8List mobileToken;
}

// TODO: DOC
final class NfcReaderSessionErrorIOS {
  // TODO: DOC
  @visibleForTesting
  const NfcReaderSessionErrorIOS({
    required this.code,
    required this.message,
  });

  // TODO: DOC
  final NfcReaderErrorCodeIOS code;

  // TODO: DOC
  final String message;
}

// TODO: DOC
enum NfcVasCommandConfigurationModeIOS {
  // TODO: DOC
  normal,

  // TODO: DOC
  urlOnly,
}

// TODO: DOC
enum NfcReaderErrorCodeIOS {
  // TODO: DOC
  readerSessionInvalidationErrorFirstNDEFTagRead,

  // TODO: DOC
  readerSessionInvalidationErrorSessionTerminatedUnexpectedly,

  // TODO: DOC
  readerSessionInvalidationErrorSessionTimeout,

  // TODO: DOC
  readerSessionInvalidationErrorSystemIsBusy,

  // TODO: DOC
  readerSessionInvalidationErrorUserCanceled,

  // TODO: DOC
  ndefReaderSessionErrorTagNotWritable,

  // TODO: DOC
  ndefReaderSessionErrorTagSizeTooSmall,

  // TODO: DOC
  ndefReaderSessionErrorTagUpdateFailure,

  // TODO: DOC
  ndefReaderSessionErrorZeroLengthMessage,

  // TODO: DOC
  readerTransceiveErrorRetryExceeded,

  // TODO: DOC
  readerTransceiveErrorTagConnectionLost,

  // TODO: DOC
  readerTransceiveErrorTagNotConnected,

  // TODO: DOC
  readerTransceiveErrorTagResponseError,

  // TODO: DOC
  readerTransceiveErrorSessionInvalidated,

  // TODO: DOC
  readerTransceiveErrorPacketTooLong,

  // TODO: DOC
  tagCommandConfigurationErrorInvalidParameters,

  // TODO: DOC
  readerErrorUnsupportedFeature,

  // TODO: DOC
  readerErrorInvalidParameter,

  // TODO: DOC
  readerErrorInvalidParameterLength,

  // TODO: DOC
  readerErrorParameterOutOfBound,

  // TODO: DOC
  readerErrorRadioDisabled,

  // TODO: DOC
  readerErrorSecurityViolation,
}

// TODO: DOC
enum NfcVasResponseErrorCodeIOS {
  // TODO: DOC
  success,

  // TODO: DOC
  userIntervention,

  // TODO: DOC
  dataNotActivated,

  // TODO: DOC
  dataNotFound,

  // TODO: DOC
  incorrectData,

  // TODO: DOC
  unsupportedApplicationVersion,

  // TODO: DOC
  wrongLCField,

  // TODO: DOC
  wrongParameters,
}
