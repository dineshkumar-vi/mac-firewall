//
//  main.swift
//  CLIFnmaFirewallX
//
//  Created by Dinesh Kumar on 4/2/22.
//  Copyright © 2022 Apple. All rights reserved.
//

import Foundation

 
func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
    return paths[0]
}

let url = getDocumentsDirectory().appendingPathComponent("com.fanniemae.fnamfirewall.txt")
let results = try String(contentsOf: url, encoding: .utf8)
print(results)
