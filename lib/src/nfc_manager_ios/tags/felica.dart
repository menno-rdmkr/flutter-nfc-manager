import 'package:flutter/foundation.dart';
import 'package:nfc_manager/src/nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/src/nfc_manager_ios/pigeon.dart';
import 'package:nfc_manager/src/nfc_manager_ios/pigeon.g.dart';

/// The class providing access to FeliCa operations for iOS.
///
/// Acquire an instance using [from(NfcTag)].
final class FeliCaIOS {
  const FeliCaIOS._(
    this._handle, {
    required this.currentSystemCode,
    required this.currentIDm,
  });

  final String _handle;

  // TODO: DOC
  final Uint8List currentSystemCode;

  // TODO: DOC
  final Uint8List currentIDm;

  /// Creates an instance of this class for the given tag.
  ///
  /// Returns null if the tag is not compatible.
  static FeliCaIOS? from(NfcTag tag) {
    // ignore: invalid_use_of_protected_member
    final data = tag.data as PigeonTag?;
    final tech = data?.feliCa;
    if (data == null || tech == null) return null;
    return FeliCaIOS._(
      data.handle,
      currentSystemCode: tech.currentSystemCode,
      currentIDm: tech.currentIDm,
    );
  }

  // TODO: DOC
  Future<FeliCaPollingResponseIOS> polling({
    required Uint8List systemCode,
    required FeliCaPollingRequestCodeIOS requestCode,
    required FeliCaPollingTimeSlotIOS timeSlot,
  }) {
    return hostApi
        .feliCaPolling(
          handle: _handle,
          systemCode: systemCode,
          requestCode: PigeonFeliCaPollingRequestCode.values.byName(
            requestCode.name,
          ),
          timeSlot: PigeonFeliCaPollingTimeSlot.values.byName(
            timeSlot.name,
          ),
        )
        .then((value) => FeliCaPollingResponseIOS(
              manufacturerParameter: value.manufacturerParameter,
              requestData: value.requestData,
            ));
  }

  // TODO: DOC
  Future<List<Uint8List>> requestService({
    required List<Uint8List> nodeCodeList,
  }) {
    return hostApi
        .feliCaRequestService(
          handle: _handle,
          nodeCodeList: nodeCodeList,
        )
        .then((value) => List.from(value));
  }

  // TODO: DOC
  Future<int> requestResponse() {
    return hostApi.feliCaRequestResponse(
      handle: _handle,
    );
  }

  // TODO: DOC
  Future<FeliCaReadWithoutEncryptionResponseIOS> readWithoutEncryption({
    required List<Uint8List> serviceCodeList,
    required List<Uint8List> blockList,
  }) {
    return hostApi
        .feliCaReadWithoutEncryption(
          handle: _handle,
          serviceCodeList: serviceCodeList,
          blockList: blockList,
        )
        .then((value) => FeliCaReadWithoutEncryptionResponseIOS(
              statusFlag1: value.statusFlag1,
              statusFlag2: value.statusFlag2,
              blockData: List.from(value.blockData),
            ));
  }

  // TODO: DOC
  Future<FeliCaStatusFlagIOS> writeWithoutEncryption({
    required List<Uint8List> serviceCodeList,
    required List<Uint8List> blockList,
    required List<Uint8List> blockData,
  }) {
    return hostApi
        .feliCaWriteWithoutEncryption(
          handle: _handle,
          serviceCodeList: serviceCodeList,
          blockList: blockList,
          blockData: blockData,
        )
        .then((value) => FeliCaStatusFlagIOS(
              statusFlag1: value.statusFlag1,
              statusFlag2: value.statusFlag2,
            ));
  }

  // TODO: DOC
  Future<List<Uint8List>> requestSystemCode() {
    return hostApi
        .feliCaRequestSystemCode(
          handle: _handle,
        )
        .then((value) => List.from(value));
  }

  // TODO: DOC
  Future<FeliCaRequestServiceV2ResponseIOS> requestServiceV2({
    required List<Uint8List> nodeCodeList,
  }) {
    return hostApi
        .feliCaRequestServiceV2(
          handle: _handle,
          nodeCodeList: nodeCodeList,
        )
        .then((value) => FeliCaRequestServiceV2ResponseIOS(
              statusFlag1: value.statusFlag1,
              statusFlag2: value.statusFlag2,
              encryptionIdentifier: value.encryptionIdentifier,
              nodeKeyVersionListAes: List.from(value.nodeKeyVersionListAES),
              nodeKeyVersionListDes: List.from(value.nodeKeyVersionListDES),
            ));
  }

  // TODO: DOC
  Future<FeliCaRequestSpecificationVersionResponseIOS>
      requestSpecificationVersion() {
    return hostApi
        .feliCaRequestSpecificationVersion(
          handle: _handle,
        )
        .then((value) => FeliCaRequestSpecificationVersionResponseIOS(
              statusFlag1: value.statusFlag1,
              statusFlag2: value.statusFlag2,
              basicVersion: value.basicVersion,
              optionVersion: value.optionVersion,
            ));
  }

  // TODO: DOC
  Future<FeliCaStatusFlagIOS> resetMode() {
    return hostApi
        .feliCaResetMode(
          handle: _handle,
        )
        .then((value) => FeliCaStatusFlagIOS(
              statusFlag1: value.statusFlag1,
              statusFlag2: value.statusFlag2,
            ));
  }

  // TODO: DOC
  Future<Uint8List> sendFeliCaCommand({
    required Uint8List commandPacket,
  }) {
    return hostApi.feliCaSendFeliCaCommand(
      handle: _handle,
      commandPacket: commandPacket,
    );
  }
}

// TODO: DOC
enum FeliCaPollingRequestCodeIOS {
  // TODO: DOC
  noRequest,

  // TODO: DOC
  systemCode,

  // TODO: DOC
  communicationPerformance,
}

// TODO: DOC
enum FeliCaPollingTimeSlotIOS {
  // TODO: DOC
  max1,

  // TODO: DOC
  max2,

  // TODO: DOC
  max4,

  // TODO: DOC
  max8,

  // TODO: DOC
  max16,
}

// TODO: DOC
final class FeliCaPollingResponseIOS {
  // TODO: DOC
  @visibleForTesting
  const FeliCaPollingResponseIOS({
    required this.manufacturerParameter,
    required this.requestData,
  });

  // TODO: DOC
  final Uint8List manufacturerParameter;

  // TODO: DOC
  final Uint8List requestData;
}

// TODO: DOC
final class FeliCaStatusFlagIOS {
  // TODO: DOC
  @visibleForTesting
  const FeliCaStatusFlagIOS({
    required this.statusFlag1,
    required this.statusFlag2,
  });

  // TODO: DOC
  final int statusFlag1;

  // TODO: DOC
  final int statusFlag2;
}

// TODO: DOC
final class FeliCaReadWithoutEncryptionResponseIOS {
  // TODO: DOC
  @visibleForTesting
  const FeliCaReadWithoutEncryptionResponseIOS({
    required this.statusFlag1,
    required this.statusFlag2,
    required this.blockData,
  });

  // TODO: DOC
  final int statusFlag1;

  // TODO: DOC
  final int statusFlag2;

  // TODO: DOC
  final List<Uint8List> blockData;
}

// TODO: DOC
final class FeliCaRequestServiceV2ResponseIOS {
  // TODO: DOC
  @visibleForTesting
  const FeliCaRequestServiceV2ResponseIOS({
    required this.statusFlag1,
    required this.statusFlag2,
    required this.encryptionIdentifier,
    required this.nodeKeyVersionListAes,
    required this.nodeKeyVersionListDes,
  });

  // TODO: DOC
  final int statusFlag1;

  // TODO: DOC
  final int statusFlag2;

  // TODO: DOC
  final int encryptionIdentifier;

  // TODO: DOC
  final List<Uint8List> nodeKeyVersionListAes;

  // TODO: DOC
  final List<Uint8List> nodeKeyVersionListDes;
}

// TODO: DOC
final class FeliCaRequestSpecificationVersionResponseIOS {
  // TODO: DOC
  @visibleForTesting
  const FeliCaRequestSpecificationVersionResponseIOS({
    required this.statusFlag1,
    required this.statusFlag2,
    required this.basicVersion,
    required this.optionVersion,
  });

  // TODO: DOC
  final int statusFlag1;

  // TODO: DOC
  final int statusFlag2;

  // TODO: DOC
  final Uint8List basicVersion;

  // TODO: DOC
  final Uint8List optionVersion;
}
