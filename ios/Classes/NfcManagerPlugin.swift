import CoreNFC
import Flutter

public class NfcManagerPlugin: NSObject, FlutterPlugin, PigeonHostApi {
  private let flutterApi: PigeonFlutterApi
  private var tagSession: NFCTagReaderSession? = nil
  private var vasSession: NFCVASReaderSession? = nil
  private var cachedTags: [String : NFCNDEFTag] = [:]
  private var shouldInvalidateSessionAfterFirstRead: Bool = true

  public static func register(with registrar: FlutterPluginRegistrar) {
    PigeonHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: NfcManagerPlugin(binaryMessenger: registrar.messenger()))
  }

  private init(binaryMessenger: FlutterBinaryMessenger) {
    flutterApi = PigeonFlutterApi(binaryMessenger: binaryMessenger)
  }

  func tagReaderSessionReadingAvailable() throws -> Bool {
    return NFCTagReaderSession.readingAvailable
  }

  func tagReaderSessionBegin(pollingOptions: [PigeonPollingOption], alertMessage: String?, invalidateAfterFirstRead: Bool) throws {
    if tagSession != nil || vasSession != nil { throw FlutterError(code: "session_already_exists", message: "Multiple sessions cannot be active at the same time.", details: nil) }
    tagSession = NFCTagReaderSession(pollingOption: convert(pollingOptions), delegate: self)
    if let alertMessage = alertMessage { tagSession?.alertMessage = alertMessage }
    shouldInvalidateSessionAfterFirstRead = invalidateAfterFirstRead
    tagSession?.begin()
  }

  func tagReaderSessionInvalidate(alertMessage: String?, errorMessage: String?) throws {
    guard let tagSession = tagSession else { throw FlutterError(code: "no_active_sessions", message: "Session is not active.", details: nil) }
    if let alertMessage = alertMessage { tagSession.alertMessage = alertMessage }
    if let errorMessage = errorMessage { tagSession.invalidate(errorMessage: errorMessage) } else { tagSession.invalidate() }
    self.tagSession = nil
    cachedTags.removeAll() // Consider when to remove the tag.
  }

  func tagReaderSessionRestartPolling() throws {
    guard let tagSession = tagSession else { throw FlutterError(code: "no_active_sessions", message: "Session is not active.", details: nil) }
    tagSession.restartPolling()
  }

  func tagReaderSessionSetAlertMessage(alertMessage: String) throws {
    guard let tagSession = tagSession else { throw FlutterError(code: "no_active_sessions", message: "Session is not active.", details: nil) }
    tagSession.alertMessage = alertMessage
  }

  func vasReaderSessionReadingAvailable() throws -> Bool {
    return NFCVASReaderSession.readingAvailable
  }

  func vasReaderSessionBegin(configurations: [PigeonNfcVasCommandConfiguration], alertMessage: String?) throws {
    if vasSession != nil || tagSession != nil { throw FlutterError(code: "session_already_exists", message: "Multiple sessions cannot be active at the same time.", details: nil) }
    vasSession = NFCVASReaderSession(vasCommandConfigurations: configurations.map { convert($0) }, delegate: self, queue: nil)
    if let alertMessage = alertMessage { vasSession?.alertMessage = alertMessage }
    vasSession?.begin()
  }

  func vasReaderSessionInvalidate(alertMessage: String?, errorMessage: String?) throws {
    guard let vasSession = vasSession else { throw FlutterError(code: "no_active_sessions", message: "Session is not active.", details: nil) }
    if let alertMessage = alertMessage { vasSession.alertMessage = alertMessage }
    if let errorMessage = errorMessage { vasSession.invalidate(errorMessage: errorMessage) } else { vasSession.invalidate() }
    self.vasSession = nil
  }

  func vasReaderSessionSetAlertMessage(alertMessage: String) throws {
    guard let vasSession = vasSession else { throw FlutterError(code: "no_active_sessions", message: "Session is not active.", details: nil) }
    vasSession.alertMessage = alertMessage
  }

  func ndefQueryNDEFStatus(handle: String, completion: @escaping (Result<PigeonNDEFQueryStatus, Error>) -> Void) {
    guard let tag = cachedTags[handle] else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.queryNDEFStatus { status, capacity, error in
      if let error = error { completion(.failure(error)); return }
    }
  }

  func ndefReadNDEF(handle: String, completion: @escaping (Result<PigeonNdefMessage?, Error>) -> Void) {
    guard let tag = cachedTags[handle] else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.readNDEF { message, error in
      if let error = error { completion(.failure(error)); return }
      guard let message = message else { completion(.success(nil)); return }
      completion(.success(convert(message)))
    }
  }

  func ndefWriteNDEF(handle: String, message: PigeonNdefMessage, completion: @escaping (Result<Void, Error>) -> Void) {
    guard let tag = cachedTags[handle] else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.writeNDEF(convert(message)) { error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(()))
    }
  }

  func ndefWriteLock(handle: String, completion: @escaping (Result<Void, Error>) -> Void) {
    guard let tag = cachedTags[handle] else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.writeLock { error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(()))
    }
  }

  func feliCaPolling(handle: String, systemCode: FlutterStandardTypedData, requestCode: PigeonFeliCaPollingRequestCode, timeSlot: PigeonFeliCaPollingTimeSlot, completion: @escaping (Result<PigeonFeliCaPollingResponse, Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCFeliCaTag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.polling(systemCode: systemCode.data, requestCode: convert(requestCode), timeSlot: convert(timeSlot)) { manufacturerParameter, requestData, error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(PigeonFeliCaPollingResponse(
        manufacturerParameter: FlutterStandardTypedData(bytes: manufacturerParameter),
        requestData: FlutterStandardTypedData(bytes: requestData)
      )))
    }
  }

  func feliCaRequestService(handle: String, nodeCodeList: [FlutterStandardTypedData], completion: @escaping (Result<[FlutterStandardTypedData], Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCFeliCaTag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.requestService(nodeCodeList: nodeCodeList.map { $0.data }) { nodeCodeList, error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(nodeCodeList.map { FlutterStandardTypedData(bytes: $0) }))
    }
  }

  func feliCaRequestResponse(handle: String, completion: @escaping (Result<Int64, Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCFeliCaTag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.requestResponse { mode, error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(Int64(mode)))
    }
  }

  func feliCaReadWithoutEncryption(handle: String, serviceCodeList: [FlutterStandardTypedData], blockList: [FlutterStandardTypedData], completion: @escaping (Result<PigeonFeliCaReadWithoutEncryptionResponse, Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCFeliCaTag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.readWithoutEncryption(serviceCodeList: serviceCodeList.map { $0.data }, blockList: blockList.map { $0.data }) { statusFlag1, statusFlag2, blockData, error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(PigeonFeliCaReadWithoutEncryptionResponse(
        statusFlag1: Int64(statusFlag1),
        statusFlag2: Int64(statusFlag2),
        blockData: blockData.map { FlutterStandardTypedData(bytes: $0) }
      )))
    }
  }

  func feliCaWriteWithoutEncryption(handle: String, serviceCodeList: [FlutterStandardTypedData], blockList: [FlutterStandardTypedData], blockData: [FlutterStandardTypedData], completion: @escaping (Result<PigeonFeliCaStatusFlag, Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCFeliCaTag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.writeWithoutEncryption(serviceCodeList: serviceCodeList.map { $0.data }, blockList: blockList.map { $0.data }, blockData: blockData.map { $0.data }) { statusFlag1, statusFlag2, error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(PigeonFeliCaStatusFlag(
        statusFlag1: Int64(statusFlag1),
        statusFlag2: Int64(statusFlag2)
      )))
    }
  }

  func feliCaRequestSystemCode(handle: String, completion: @escaping (Result<[FlutterStandardTypedData], Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCFeliCaTag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.requestSystemCode() { systemCodeList, error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(systemCodeList.map { FlutterStandardTypedData(bytes: $0) }))
    }
  }

  func feliCaRequestServiceV2(handle: String, nodeCodeList: [FlutterStandardTypedData], completion: @escaping (Result<PigeonFeliCaRequestServiceV2Response, Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCFeliCaTag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.requestServiceV2(nodeCodeList: nodeCodeList.map { $0.data }) { statusFlag1, statusFlag2, encryptionIdentifier, nodeKeyVersionListAes, nodeKeyVersionListDes, error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(PigeonFeliCaRequestServiceV2Response(
        statusFlag1: Int64(statusFlag1),
        statusFlag2: Int64(statusFlag2),
        encryptionIdentifier: Int64(encryptionIdentifier.rawValue),
        nodeKeyVersionListAES: nodeKeyVersionListAes.map { FlutterStandardTypedData(bytes: $0) },
        nodeKeyVersionListDES: nodeKeyVersionListDes.map { FlutterStandardTypedData(bytes: $0) }
      )))
    }
  }

  func feliCaRequestSpecificationVersion(handle: String, completion: @escaping (Result<PigeonFeliCaRequestSpecificationVersionResponse, Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCFeliCaTag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.requestSpecificationVersion() { statusFlag1, statusFlag2, basicVersion, optionVersion, error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(PigeonFeliCaRequestSpecificationVersionResponse(
        statusFlag1: Int64(statusFlag1),
        statusFlag2: Int64(statusFlag2),
        basicVersion: FlutterStandardTypedData(bytes: basicVersion),
        optionVersion: FlutterStandardTypedData(bytes: optionVersion)
      )))
    }
  }

  func feliCaResetMode(handle: String, completion: @escaping (Result<PigeonFeliCaStatusFlag, Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCFeliCaTag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.resetMode() { statusFlag1, statusFlag2, error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(PigeonFeliCaStatusFlag(
        statusFlag1: Int64(statusFlag1),
        statusFlag2: Int64(statusFlag2)
      )))
    }
  }

  func feliCaSendFeliCaCommand(handle: String, commandPacket: FlutterStandardTypedData, completion: @escaping (Result<FlutterStandardTypedData, Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCFeliCaTag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.sendFeliCaCommand(commandPacket: commandPacket.data) { data, error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(FlutterStandardTypedData(bytes: data)))
    }
  }

  func miFareSendMiFareCommand(handle: String, commandPacket: FlutterStandardTypedData, completion: @escaping (Result<FlutterStandardTypedData, Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCMiFareTag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.sendMiFareCommand(commandPacket: commandPacket.data) { data, error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(FlutterStandardTypedData(bytes: data)))
    }
  }

  func miFareSendMiFareISO7816Command(handle: String, apdu: PigeonISO7816APDU, completion: @escaping (Result<PigeonISO7816ResponseAPDU, Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCMiFareTag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.sendMiFareISO7816Command(convert(apdu)) { payload, statusWord1, statusWord2, error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(PigeonISO7816ResponseAPDU(
        payload: FlutterStandardTypedData(bytes: payload),
        statusWord1: Int64(statusWord1),
        statusWord2: Int64(statusWord2)
      )))
    }
  }

  func miFareSendMiFareISO7816CommandRaw(handle: String, data: FlutterStandardTypedData, completion: @escaping (Result<PigeonISO7816ResponseAPDU, Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCMiFareTag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.sendMiFareISO7816Command(NFCISO7816APDU(data: data.data)!) { payload, statusWord1, statusWord2, error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(PigeonISO7816ResponseAPDU(
        payload: FlutterStandardTypedData(bytes: payload),
        statusWord1: Int64(statusWord1),
        statusWord2: Int64(statusWord2)
      )))
    }
  }

  func iso7816SendCommand(handle: String, apdu: PigeonISO7816APDU, completion: @escaping (Result<PigeonISO7816ResponseAPDU, Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCISO7816Tag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.sendCommand(apdu: convert(apdu)) { payload, statusWord1, statusWord2, error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(PigeonISO7816ResponseAPDU(
        payload: FlutterStandardTypedData(bytes: payload),
        statusWord1: Int64(statusWord1),
        statusWord2: Int64(statusWord2)
      )))
    }
  }

  func iso7816SendCommandRaw(handle: String, data: FlutterStandardTypedData, completion: @escaping (Result<PigeonISO7816ResponseAPDU, Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCISO7816Tag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.sendCommand(apdu: NFCISO7816APDU(data: data.data)!) { payload, statusWord1, statusWord2, error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(PigeonISO7816ResponseAPDU(
        payload: FlutterStandardTypedData(bytes: payload),
        statusWord1: Int64(statusWord1),
        statusWord2: Int64(statusWord2)
      )))
    }
  }

  func iso15693StayQuiet(handle: String, completion: @escaping (Result<Void, Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCISO15693Tag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.stayQuiet() { error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(()))
    }
  }

  func iso15693ReadSingleBlock(handle: String, requestFlags: [PigeonISO15693RequestFlag], blockNumber: Int64, completion: @escaping (Result<FlutterStandardTypedData, Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCISO15693Tag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.readSingleBlock(requestFlags: convert(requestFlags), blockNumber: UInt8(blockNumber)) { dataBlock, error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(FlutterStandardTypedData(bytes: dataBlock)))
    }
  }

  func iso15693WriteSingleBlock(handle: String, requestFlags: [PigeonISO15693RequestFlag], blockNumber: Int64, dataBlock: FlutterStandardTypedData, completion: @escaping (Result<Void, Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCISO15693Tag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.writeSingleBlock(requestFlags: convert(requestFlags), blockNumber: UInt8(blockNumber), dataBlock: dataBlock.data) { error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(()))
    }
  }

  func iso15693LockBlock(handle: String, requestFlags: [PigeonISO15693RequestFlag], blockNumber: Int64, completion: @escaping (Result<Void, Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCISO15693Tag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.lockBlock(requestFlags: convert(requestFlags), blockNumber: UInt8(blockNumber)) { error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(()))
    }
  }

  func iso15693ReadMultipleBlocks(handle: String, requestFlags: [PigeonISO15693RequestFlag], blockNumber: Int64, numberOfBlocks: Int64, completion: @escaping (Result<[FlutterStandardTypedData], Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCISO15693Tag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.readMultipleBlocks(requestFlags: convert(requestFlags), blockRange: convert(blockNumber, numberOfBlocks)) { dataBlocks, error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(dataBlocks.map { FlutterStandardTypedData(bytes: $0) }))
    }
  }

  func iso15693WriteMultipleBlocks(handle: String, requestFlags: [PigeonISO15693RequestFlag], blockNumber: Int64, numberOfBlocks: Int64, dataBlocks: [FlutterStandardTypedData], completion: @escaping (Result<Void, Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCISO15693Tag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.writeMultipleBlocks(requestFlags: convert(requestFlags), blockRange: convert(blockNumber, numberOfBlocks), dataBlocks: dataBlocks.map { $0.data }) { error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(()))
    }
  }

  func iso15693Select(handle: String, requestFlags: [PigeonISO15693RequestFlag], completion: @escaping (Result<Void, Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCISO15693Tag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.select(requestFlags: convert(requestFlags)) { error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(()))
    }
  }

  func iso15693ResetToReady(handle: String, requestFlags: [PigeonISO15693RequestFlag], completion: @escaping (Result<Void, Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCISO15693Tag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.resetToReady(requestFlags: convert(requestFlags)) { error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(()))
    }
  }

  func iso15693WriteAfi(handle: String, requestFlags: [PigeonISO15693RequestFlag], afi: Int64, completion: @escaping (Result<Void, Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCISO15693Tag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.writeAFI(requestFlags: convert(requestFlags), afi: UInt8(afi)) { error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(()))
    }
  }

  func iso15693LockAfi(handle: String, requestFlags: [PigeonISO15693RequestFlag], completion: @escaping (Result<Void, Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCISO15693Tag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.lockAFI(requestFlags: convert(requestFlags)) { error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(()))
    }
  }

  func iso15693WriteDsfId(handle: String, requestFlags: [PigeonISO15693RequestFlag], dsfId: Int64, completion: @escaping (Result<Void, Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCISO15693Tag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.writeDSFID(requestFlags: convert(requestFlags), dsfid: UInt8(dsfId)) { error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(()))
    }
  }

  func iso15693LockDsfId(handle: String, requestFlags: [PigeonISO15693RequestFlag], completion: @escaping (Result<Void, Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCISO15693Tag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.lockDFSID(requestFlags: convert(requestFlags)) { error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(()))
    }
  }

  func iso15693GetSystemInfo(handle: String, requestFlags: [PigeonISO15693RequestFlag], completion: @escaping (Result<PigeonISO15693SystemInfo, Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCISO15693Tag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.getSystemInfo(requestFlags: convert(requestFlags)) { dataStorageFormatIdentifier, applicationFamilyIdentifier, blockSize, totalBlocks, icReference, error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(PigeonISO15693SystemInfo(
        dataStorageFormatIdentifier: Int64(dataStorageFormatIdentifier),
        applicationFamilyIdentifier: Int64(applicationFamilyIdentifier),
        blockSize: Int64(blockSize),
        totalBlocks: Int64(totalBlocks),
        icReference: Int64(icReference)
      )))
    }
  }

  func iso15693GetMultipleBlockSecurityStatus(handle: String, requestFlags: [PigeonISO15693RequestFlag], blockNumber: Int64, numberOfBlocks: Int64, completion: @escaping (Result<[Int64], Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCISO15693Tag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.getMultipleBlockSecurityStatus(requestFlags: convert(requestFlags), blockRange: convert(blockNumber, numberOfBlocks)) { status, error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(status.map { Int64(truncating: $0) }))
    }
  }

  func iso15693CustomCommand(handle: String, requestFlags: [PigeonISO15693RequestFlag], customCommandCode: Int64, customRequestParameters: FlutterStandardTypedData, completion: @escaping (Result<FlutterStandardTypedData, Error>) -> Void) {
    guard let tag = cachedTags[handle] as? NFCISO15693Tag else { completion(.failure(FlutterError(code: "tag_not_found", message: "You may have disable the session.", details: nil))); return }
    tag.customCommand(requestFlags: convert(requestFlags), customCommandCode: Int(customCommandCode), customRequestParameters: customRequestParameters.data) { data, error in
      if let error = error { completion(.failure(error)); return }
      completion(.success(FlutterStandardTypedData(bytes: data)))
    }
  }
}

extension NfcManagerPlugin: NFCTagReaderSessionDelegate {
  public func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
    flutterApi.tagReaderSessionDidBecomeActive { _ in /* no op */ }
  }

  public func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
    let pigeonError = PigeonNfcReaderSessionError(
      code: convert((error as! NFCReaderError).code),
      message: error.localizedDescription
    )
    flutterApi.tagReaderSessionDidInvalidateWithError(error: pigeonError) { _ in /* no op */ }
  }

  public func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
    session.connect(to: tags.first!) { error in
      if let error = error {
        // skip tag detection
        print(error)
        if !self.shouldInvalidateSessionAfterFirstRead { session.restartPolling() }
        return
      }
      convert(tags.first!) { tag, pigeon, error in
        if let error = error {
          // skip tag detection
          print(error)
          if !self.shouldInvalidateSessionAfterFirstRead { session.restartPolling() }
          return
        }
        guard let pigeon = pigeon else {
          // skip tag detection
          if !self.shouldInvalidateSessionAfterFirstRead { session.restartPolling() }
          return
        }
        self.cachedTags[pigeon.handle] = tag
        self.flutterApi.tagReaderSessionDidDetect(tag: pigeon) { _ in /* no op */ }
        if !self.shouldInvalidateSessionAfterFirstRead { session.restartPolling() }
      }
    }
  }
}

extension NfcManagerPlugin: NFCVASReaderSessionDelegate {
  public func readerSessionDidBecomeActive(_ session: NFCVASReaderSession) {
    flutterApi.vasReaderSessionDidBecomeActive { _ in /* no op */ }
  }

  public func readerSession(_ session: NFCVASReaderSession, didInvalidateWithError error: Error) {
    let pigeonError = PigeonNfcReaderSessionError(
      code: convert((error as! NFCReaderError).code),
      message: error.localizedDescription
    )
    flutterApi.vasReaderSessionDidInvalidateWithError(error: pigeonError) { _ in /* no op */ }
  }

  public func readerSession(_ session: NFCVASReaderSession, didReceive responses: [NFCVASResponse]) {
    flutterApi.vasReaderSessionDidReceive(responses: responses.map { convert($0) }) { _ in /* no op */ }
  }
}

private func convert(_ value: NFCTag, _ completionHandler: @escaping (NFCNDEFTag, PigeonTag?, Error?) -> Void) {
  switch (value) {
  case .feliCa(let tag): convert(tag) { pigeon, error in completionHandler(tag, pigeon, error) }
  case .iso15693(let tag): convert(tag) { pigeon, error in completionHandler(tag, pigeon, error) }
  case .iso7816(let tag): convert(tag) { pigeon, error in completionHandler(tag, pigeon, error) }
  case .miFare(let tag): convert(tag) { pigeon, error in completionHandler(tag, pigeon, error) }
  @unknown default: print("Unknown tag cannot be serialized")
  }
}

private func convert(_ value: NFCNDEFTag, _ completionHandler: @escaping (PigeonTag?, Error?) -> Void) {
  var pigeon = PigeonTag(handle: NSUUID().uuidString)

  if let value = value as? NFCFeliCaTag {
    pigeon.feliCa = PigeonFeliCa(
      currentSystemCode: FlutterStandardTypedData(bytes: value.currentSystemCode),
      currentIDm: FlutterStandardTypedData(bytes: value.currentIDm)
    )
  }
  else if let value = value as? NFCISO15693Tag {
    pigeon.iso15693 = PigeonISO15693(
      icManufacturerCode: Int64(value.icManufacturerCode),
      icSerialNumber: FlutterStandardTypedData(bytes: value.icSerialNumber),
      identifier: FlutterStandardTypedData(bytes: value.identifier)
    )
  }
  else if let value = value as? NFCISO7816Tag {
    pigeon.iso7816 = PigeonISO7816(
      initialSelectedAID: value.initialSelectedAID,
      identifier: FlutterStandardTypedData(bytes: value.identifier),
      historicalBytes: value.historicalBytes != nil ? FlutterStandardTypedData(bytes: value.historicalBytes!) : nil,
      applicationData: value.applicationData != nil ? FlutterStandardTypedData(bytes: value.applicationData!) : nil,
      proprietaryApplicationDataCoding: value.proprietaryApplicationDataCoding
    )
  }
  else if let value = value as? NFCMiFareTag {
    pigeon.miFare = PigeonMiFare(
      mifareFamily: convert(value.mifareFamily),
      identifier: FlutterStandardTypedData(bytes: value.identifier),
      historicalBytes: value.historicalBytes != nil ? FlutterStandardTypedData(bytes: value.historicalBytes!) : nil
    )
  }

  value.queryNDEFStatus { status, capacity, error in
    if let error = error {
      completionHandler(nil, error)
      return
    }
    pigeon.ndef = PigeonNdef(
      status: convert(status),
      capacity: Int64(capacity)
    )
    if status == .notSupported {
      completionHandler(pigeon, nil)
      return
    }
    value.readNDEF { message, error in
      if let error = error {
        completionHandler(nil, error)
        return
      }
      if let message = message {
        pigeon.ndef?.cachedNdefMessage = convert(message)
      }
      completionHandler(pigeon, nil)
    }
  }
}

private func convert(_ value: PigeonNdefMessage) -> NFCNDEFMessage {
  return NFCNDEFMessage(
    records: value.records.map { NFCNDEFPayload(
      format: convert($0!.typeNameFormat),
      type: $0!.type.data,
      identifier: $0!.identifier.data,
      payload: $0!.payload.data
    ) }
  )
}

private func convert(_ value: NFCNDEFMessage) -> PigeonNdefMessage {
  return PigeonNdefMessage(records: value.records.map { convert($0) })
}

private func convert(_ value: NFCNDEFPayload) -> PigeonNdefPayload {
  return PigeonNdefPayload(
    typeNameFormat: convert(value.typeNameFormat),
    type: FlutterStandardTypedData(bytes: value.type),
    identifier: FlutterStandardTypedData(bytes: value.identifier),
    payload: FlutterStandardTypedData(bytes: value.payload)
  )
}

private func convert(_ value: [PigeonPollingOption]) -> NFCTagReaderSession.PollingOption {
  var option = NFCTagReaderSession.PollingOption()
  value.forEach { option.insert(convert($0)) }
  return option
}

private func convert(_ value: PigeonPollingOption) -> NFCTagReaderSession.PollingOption {
  switch (value) {
  case .iso14443: return .iso14443
  case .iso15693: return .iso15693
  case .iso18092: return .iso18092
  }
}

private func convert(_ value: NFCNDEFStatus) -> PigeonNdefStatus {
  switch (value) {
  case .notSupported: return .notSupported
  case .readWrite: return .readWrite
  case .readOnly: return .readOnly
  default: fatalError()
  }
}

private func convert(_ value: PigeonFeliCaPollingRequestCode) -> PollingRequestCode {
  switch (value) {
  case .noRequest: return .noRequest
  case .systemCode: return .systemCode
  case .communicationPerformance: return .communicationPerformance
  }
}

private func convert(_ value: PigeonFeliCaPollingTimeSlot) -> PollingTimeSlot {
  switch (value) {
  case .max1: return .max1
  case .max2: return .max2
  case .max4: return .max4
  case .max8: return .max8
  case .max16: return .max16
  }
}

private func convert(_ value: PigeonISO7816APDU) -> NFCISO7816APDU {
  return NFCISO7816APDU(
    instructionClass: UInt8(value.instructionClass),
    instructionCode: UInt8(value.instructionCode),
    p1Parameter: UInt8(value.p1Parameter),
    p2Parameter: UInt8(value.p2Parameter),
    data: value.data.data,
    expectedResponseLength: Int(value.expectedResponseLength)
  )
}

private func convert(_ value: [PigeonISO15693RequestFlag]) -> RequestFlag {
  var flag = RequestFlag()
  value.forEach { flag.insert(convert($0)) }
  return flag
}

private func convert(_ value: PigeonNfcVasCommandConfiguration) -> NFCVASCommandConfiguration {
  return NFCVASCommandConfiguration(
    vasMode: convert(value.mode),
    passTypeIdentifier: value.passIdentifier,
    url: (value.url == nil) ? nil : URL(string: value.url!)
  )
}

private func convert(_ value: NFCVASResponse) -> PigeonNfcVasResponse {
  return PigeonNfcVasResponse(
    status: convert(value.status),
    vasData: FlutterStandardTypedData(bytes: value.vasData),
    mobileToken: FlutterStandardTypedData(bytes: value.mobileToken)
  )
}

private func convert(_ value: PigeonISO15693RequestFlag) -> RequestFlag {
  switch (value) {
  case .address: return .address
  case .dualSubCarriers: return .dualSubCarriers
  case .highDataRate: return .highDataRate
  case .option: return .option
  case .protocolExtension: return .protocolExtension
  case .select: return .select
  }
}

private func convert(_ value: NFCMiFareFamily) -> PigeonMiFareFamily {
  switch (value) {
  case .unknown: return .unknown
  case .ultralight: return .ultralight
  case .plus: return .plus
  case .desfire: return .desfire
  default: fatalError()
  }
}

private func convert(_ value: PigeonTypeNameFormat) -> NFCTypeNameFormat {
  switch (value) {
  case .empty: return .empty
  case .wellKnown: return .nfcWellKnown
  case .media: return .media
  case .absoluteUri: return .absoluteURI
  case .external: return .nfcExternal
  case .unknown: return .unknown
  case .unchanged: return .unchanged
  }
}

private func convert(_ value: NFCTypeNameFormat) -> PigeonTypeNameFormat {
  switch (value) {
  case .empty: return .empty
  case .nfcWellKnown: return .wellKnown
  case .media: return .media
  case .absoluteURI: return .absoluteUri
  case .nfcExternal: return .external
  case .unknown: return .unknown
  case .unchanged: return .unchanged
  default: fatalError()
  }
}

private func convert(_ value: PigeonNfcVasCommandConfigurationMode) -> NFCVASCommandConfiguration.Mode {
  switch value {
  case .normal: return .normal
  case .urlOnly: return .urlOnly
  }
}

private func convert(_ value: NFCReaderError.Code) -> PigeonNfcReaderErrorCode {
  switch value {
  case .readerSessionInvalidationErrorFirstNDEFTagRead: return .readerSessionInvalidationErrorFirstNDEFTagRead
  case .readerSessionInvalidationErrorSessionTerminatedUnexpectedly: return .readerSessionInvalidationErrorSessionTerminatedUnexpectedly
  case .readerSessionInvalidationErrorSessionTimeout: return .readerSessionInvalidationErrorSessionTimeout
  case .readerSessionInvalidationErrorSystemIsBusy: return .readerSessionInvalidationErrorSystemIsBusy
  case .readerSessionInvalidationErrorUserCanceled: return .readerSessionInvalidationErrorUserCanceled
  case .ndefReaderSessionErrorTagNotWritable: return .ndefReaderSessionErrorTagNotWritable
  case .ndefReaderSessionErrorTagSizeTooSmall: return .ndefReaderSessionErrorTagSizeTooSmall
  case .ndefReaderSessionErrorTagUpdateFailure: return .ndefReaderSessionErrorTagUpdateFailure
  case .ndefReaderSessionErrorZeroLengthMessage: return .ndefReaderSessionErrorZeroLengthMessage
  case .readerTransceiveErrorRetryExceeded: return .readerTransceiveErrorRetryExceeded
  case .readerTransceiveErrorTagConnectionLost: return .readerTransceiveErrorTagConnectionLost
  case .readerTransceiveErrorTagNotConnected: return .readerTransceiveErrorTagNotConnected
  case .readerTransceiveErrorTagResponseError: return .readerTransceiveErrorTagResponseError
  case .readerTransceiveErrorSessionInvalidated: return .readerTransceiveErrorSessionInvalidated
  case .readerTransceiveErrorPacketTooLong: return .readerTransceiveErrorPacketTooLong
  case .tagCommandConfigurationErrorInvalidParameters: return .tagCommandConfigurationErrorInvalidParameters
  case .readerErrorUnsupportedFeature: return .readerErrorUnsupportedFeature
  case .readerErrorInvalidParameter: return .readerErrorInvalidParameter
  case .readerErrorInvalidParameterLength: return .readerErrorInvalidParameterLength
  case .readerErrorParameterOutOfBound: return .readerErrorParameterOutOfBound
  case .readerErrorRadioDisabled: return .readerErrorRadioDisabled
  case .readerErrorSecurityViolation: return .readerErrorSecurityViolation
  default: fatalError()
  }
}

private func convert(_ value: NFCVASResponse.ErrorCode) -> PigeonNfcVasResponseErrorCode {
  switch (value) {
  case .success: return .success
  case .userIntervention: return .userIntervention
  case .dataNotActivated: return .dataNotActivated
  case .dataNotFound: return .dataNotFound
  case .incorrectData: return .incorrectData
  case .unsupportedApplicationVersion: return .unsupportedApplicationVersion
  case .wrongLCField: return .wrongLCField
  case .wrongParameters: return .wrongParameters
  default: fatalError()
  }
}

private func convert(_ value1: Int64, _ value2: Int64) -> NSRange {
  return NSRange(location: Int(value1), length: Int(value2))
}

extension FlutterError: Error {}
