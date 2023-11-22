<p align="center">
	<a href="http://tesseract.one/">
		<img alt="Tesseract" src ="./.github/logo.svg" height=256/>
	</a>
</p>

### **Polkadot Chat demo dApp** is a demonstration of how [Tesseract](https://github.com/tesseract-one/) provides wallet integration for dApps on mobile

<p align="center">
    <img src=".github/polkachat.png" alt="Polkadot chat dApp" width="30%"/>
    <img src=".github/ios-wallet-choosing.png" alt="Wallet choosing on iOS" width="30%"/>
    <img src=".github/ios-wallet-requested.png" alt="Wallet requested on iOS" width="30%"/>
</p>

## Demo

The demo is a chat, storing messages in a [Rococo](https://polkadot.network/blog/tag/rococo/) network smart contract. It shows how the dApps can perform readonly operations without ever connecting to the wallet and how to aquire public key and sign transactions using [Tesseract dApp/Wallet integration protocol](https://github.com/tesseract-one/). In the case of this demo, the transaction is created and submitted when the user wishes to send a message to the chat.

## Prerequisites

Install Xcode 14.2+ from the App Store

## Installation

1. Checkout [this repo](https://github.com/tesseract-one/polkachat.swift).
2. Open `PolkaChat.xcodeproj` in Xcode.
3. Run the **Polka Chat**.

## License

Tesseract.rs can be used, distributed and modified under [the Apache 2.0 license](LICENSE).
