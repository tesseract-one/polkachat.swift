//
//  TesseractSigner.swift
//  PolkaChat
//
//  Created by Yehor Popovych on 21/11/2023.
//

import Foundation
import TesseractClient
import Substrate

extension SignerError {
    init(tesseract: TesseractError) {
        switch tesseract {
        case .cancelled: self = .cancelledByUser
        default: self = .other(error: "\(tesseract)")
        }
    }
}

actor TesseractSigner: Signer {
    private let service: SubstrateService
    private var accountPath: [Data: String]
    
    init(service: SubstrateService) {
        self.service = service
        self.accountPath = [:]
    }
    
    func account(type: KeyTypeId, algos: [CryptoTypeId]) async -> Result<any PublicKey, SignerError> {
        guard type == .account else {
            return .failure(.noAccounts(for: type, and: algos))
        }
        let accType: SubstrateAccountType
        if algos.contains(.sr25519) {
            accType = .sr25519
        } else if algos.contains(.ed25519) {
            accType = .ed25519
        } else if algos.contains(.ecdsa) {
            accType = .ecdsa
        } else {
            return .failure(.noAccounts(for: type, and: algos))
        }
        return await service.getAccountRes(type: accType)
            .mapError { SignerError(tesseract: $0) }
            .flatMap{ res in
                self.accountPath[res.pubKey] = res.path
                return Result {
                    let pubKey: any PublicKey
                    switch accType {
                    case .sr25519: pubKey = try Sr25519PublicKey(res.pubKey)
                    case .ed25519: pubKey = try Ed25519PublicKey(res.pubKey)
                    case .ecdsa: pubKey = try EcdsaPublicKey(res.pubKey)
                    }
                    return pubKey
                }.mapError { .other(error: $0.localizedDescription) }
            }
    }
    
    func sign<RC: Config, C: Call>(
        payload: ST<RC>.SigningPayload<C>,
        with account: any PublicKey,
        runtime: ExtendedRuntime<RC>
    ) async -> Result<ST<RC>.Signature, SignerError> {
        guard let path = accountPath[account.raw] else {
            return .failure(.accountNotFound(account))
        }
        let accType: SubstrateAccountType
        switch account.algorithm {
        case .sr25519: accType = .sr25519
        case .ed25519: accType = .ed25519
        case .ecdsa: accType = .ecdsa
        }
        
        return await Result(catching: {
            var extEncoder = runtime.encoder()
            try runtime.extrinsicManager.encode(payload: payload,
                                                in: &extEncoder,
                                                runtime: runtime)
            
            var registry = Dictionary<NetworkType.Id, NetworkType>()
            var reversed = Dictionary<ObjectIdentifier, NetworkType.Id>()
            let call = NetworkType.Info.from(definition: runtime.types.call,
                                             types: &registry, reversed: &reversed)
            
            let extExt = runtime.metadata.extrinsic.extensions.map { ext in
                let type = NetworkType.Info.from(definition: ext.type,
                                                 types: &registry, reversed: &reversed)
                let addType = NetworkType.Info.from(definition: ext.additionalSigned,
                                                    types: &registry, reversed: &reversed)
                return MetadataV14.Network.ExtrinsicSignedExtension(
                    identifier: ext.identifier, type: type.id, additionalSigned: addType.id
                )
            }
            
            var typesEncoder = runtime.encoder()
            try typesEncoder.encode(registry.map { $0.key.i($0.value) })
            
            let metadata = MetadataV14.Network.Extrinsic(type: call.id,
                                                         version: runtime.extrinsicManager.version,
                                                         extensions: extExt)
            var metaEncoder = runtime.encoder()
            try metaEncoder.encode(metadata)
            
            return (extEncoder.output, metaEncoder.output, typesEncoder.output)
        }).mapError { .other(error: $0.localizedDescription) }.asyncFlatMap { data in
            await service.signTransactionRes(
                type: accType, path: path, extrinsic: data.0, metadata: data.1, types: data.2
            ).mapError { SignerError(tesseract: $0) }.flatMap { sig in
                Result(catching: {
                    try runtime.create(signature: ST<RC>.Signature.self, raw: sig,
                                       algorithm: account.algorithm)
                }).mapError { .other(error: $0.localizedDescription) }
            }
        }
    }
}
