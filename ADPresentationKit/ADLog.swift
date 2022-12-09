//
//  ADLog.swift
//  ADPresentationKit
//
//  Created by Schwarze on 02.07.22.
//

import Foundation
import OSLog

let log_enabled = false

func ad_log(_ message: String) {
    guard log_enabled else { return }
    os_log("\(message)")
}
