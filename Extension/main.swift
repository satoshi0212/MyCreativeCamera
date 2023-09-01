//
//  main.swift
//  Extension
//
//  Created by 服部 智 on 2023/09/01.
//

import Foundation
import CoreMediaIO

let providerSource = ExtensionProviderSource(clientQueue: nil)
CMIOExtensionProvider.startService(provider: providerSource.provider)

CFRunLoopRun()
