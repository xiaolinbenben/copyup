//
//  NSLock+CopyUp.swift
//
//  CopyUp
//  GitHub: https://github.com/xiaolinbenben/copyup
//  HP: https://copyup.beisi.tech
//
//  Created by Econa77 on 2016/01/20.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation

extension NSRecursiveLock {
    convenience init(name: String) {
        self.init()
        self.name = name
    }
}
