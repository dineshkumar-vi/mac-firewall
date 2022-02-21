//
//  Ports.swift
//  FnmaFirewall
//
//  Created by Dinesh Kumar on 2/20/22.
//  Copyright © 2022 Apple. All rights reserved.
//

import Foundation

public struct Ports {
    public var IP: String
    public var privatePort: String
    public var publicPort: String
    public var type: String
}

extension Ports: Codable {}
