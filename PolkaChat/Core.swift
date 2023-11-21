//
//  Core.swift
//  PolkaChat
//
//  Created by Daniel Leping on 03/03/2023.
//

import Foundation
import Substrate
import SubstrateRPC
import ScaleCodec
import TesseractClient

actor Core {
    private static let API_URL = URL(string: "wss://rococo-contracts-rpc.polkadot.io:443")!
    
    struct CoreError: Error, RuntimeDecodable {
        let description: String
        init(_ desc: String) { description = desc }
        init<D: ScaleCodec.Decoder>(from decoder: inout D, runtime: Runtime) throws {
            self.description = "Node Error: \(try decoder.read(count: decoder.length).hex())"
        }
    }
    
    typealias Config = Configs.Dynamic<AccountId32, HBlake2b256>
    typealias Contract = PolkaChat.Contract<AccountId32>
    
    private let api: Task<Api<Config, RpcClient<Config, JsonRpcSubscribableClient>>, Error>
    private var account: (key: any PublicKey, ss58: String)?
    
    public init(errors: ErrorModel) throws {
        let service = try Tesseract
            .default(delegate: TransportSelector(errors: errors))
            .service(SubstrateService.self)
        let signer = TesseractSigner(service: service)
        let client = JsonRpcClient(.ws(url: Self.API_URL, maximumMessageSize: 16*1024*1024))
        api = Task { try await Api(rpc: client, config: .dynamicBlake2, signer: signer) }
    }
    
    public func account() async throws -> String {
        try await _account().ss58
    }
    
    public func len() async throws -> UInt32 {
        try await _executeContractQuery(input: Contract.LEN)
    }
    
    public func messages(from index: UInt32) async throws -> [String] {
        let len = try await len()
        if index >= len { return [] }
        let chunkSize: UInt32 = 30
        var messages: [Contract.Message] = []
        messages.reserveCapacity(Int(len - index))
        for from in stride(from: index, to: len, by: Int(chunkSize)) {
            let params = try ScaleCodec.encode(from) + ScaleCodec.encode(min(from+chunkSize, len))
            let chunk: [Contract.Message] = try await _executeContractQuery(input: Contract.GET + params)
            messages.append(contentsOf: chunk)
        }
        return messages.map { $0.text }
    }
    
    public func send(message: String) async throws -> Contract.Message {
        let api = try await self.api.value
        let contract = try Contract.accountId(in: api.runtime)
        let account = try await _account()
        
        let contractAddr = try api.runtime.address(account: contract)
        
        let call = AnyCall(
            name: "call", pallet: "Contracts", params: [
                "dest": contractAddr,
                "value": 0,
                "gas_limit": ["ref_time": 9375000000, "proof_size": 524288],
                "storage_deposit_limit": ["None": []],
                "data": try Contract.ADD + ScaleCodec.encode(message)
            ]
        )
        let emitted = try await api.tx.new(call)
            .signSendAndWatch(account: account.key)
            .waitForFinalized()
            .success()
            .first(event: "ContractEmitted", pallet: "Contracts")
        guard let emitted = emitted else {
            throw CoreError("Contract isn't emitted event")
        }
        guard let data = emitted.params["data"]?.bytes else {
            throw CoreError("Bad event emitted: \(emitted)")
        }
        
        switch try api.runtime.decode(from: data, Contract.Events.self) {
        case .messageAdded(let message): return message
        }
    }
    
    private func _account() async throws -> (key: any PublicKey, ss58: String) {
        if let account = self.account {
            return account
        } else {
            let api = try await self.api.value
            let pubKey = try await api.tx.account()
            let str = try pubKey.ss58(format: api.runtime.addressFormat)
            account = (pubKey, str)
            return account!
        }
    }
    
    private func _executeContractQuery<R: RuntimeDecodable>(
        input: Data
    ) async throws -> R {
        let api = try await self.api.value
        let contract = try Contract.accountId(in: api.runtime)
        
        let call = AnyValueRuntimeCall(
            api: "ContractsApi", method: "call", params: [
                "origin": contract,
                "dest": contract,
                "value": 0,
                "gas_limit": ["None": []],
                "storage_deposit_limit": ["None": []],
                "input_data": input
        ])
        let response = try await api.call.execute(call: call)
        
        guard let map = response.map, let result = map["result"]?.variant else {
            throw CoreError("query response is malformed: \(response)")
        }
        guard result.name == "Ok" else {
            throw CoreError("query response is not ok: \(result)")
        }
        guard let data = result.values.first?["data"]?.bytes else {
            throw CoreError("query response is not bytes: \(result)")
        }
        return try api.runtime.decode(from: data, Result<R, CoreError>.self).get()
    }
}

struct Contract<A: AccountId> {
    static var ADDRESS: String { "5GZRb5XZVCTsH6VSxT3e8tE3qQmaiq4hJhxgdoFg8iijP3S9" }
    static var ADD: Data { Data([0x4b, 0x05, 0x0e, 0xa9]) }
    static var GET: Data { Data([0x2f, 0x86, 0x5b, 0xd9]) }
    static var LEN: Data { Data([0x83, 0x9b, 0x35, 0x48]) }
    
    static func accountId(in runtime: Runtime) throws -> A {
        try runtime.create(account: A.self, from: ADDRESS)
    }
    
    struct Message: RuntimeDecodable {
        let id: UInt32
        let sender: A
        let text: String
        
        init<D: ScaleCodec.Decoder>(from decoder: inout D, runtime: Runtime) throws {
            id = try decoder.decode()
            sender = try runtime.decode(account: A.self, from: &decoder)
            text = try decoder.decode()
        }
    }
    
    enum Events: RuntimeDecodable {
        case messageAdded(Message)
        
        init<D: ScaleCodec.Decoder>(from decoder: inout D, runtime: Runtime) throws {
            let caseId = try decoder.decode(.enumCaseId)
            switch caseId {
            case 0: self = try .messageAdded(runtime.decode(from: &decoder))
            default: throw decoder.enumCaseError(for: caseId)
            }
        }
    }
}
