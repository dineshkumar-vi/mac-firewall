//
//  Container.swift
//  FnmaFirewall
//
//  Created by Dinesh Kumar on 2/20/22.
//  Copyright © 2022 Apple. All rights reserved.
//

import Foundation


public struct Container {
    public var createdAt: Date
    public var names: [String]
    public var state: String
    public var ports: Ports
    public var command: String
}

extension Container: Codable {}
