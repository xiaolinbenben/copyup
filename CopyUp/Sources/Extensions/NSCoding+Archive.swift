//
//  NSCoding+Archive.swift
//
//  CopyUp
//  GitHub: https://github.com/xiaolinbenben/copyup
//  HP: https://copyup.beisi.tech
//
//  Created by Econa77 on 2016/11/19.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation

extension NSCoding {
    func archive() -> Data {
        return NSKeyedArchiver.archivedData(withRootObject: self)
    }
}

extension Array where Element: NSCoding {
    func archive() -> Data {
        return NSKeyedArchiver.archivedData(withRootObject: self)
    }
}
