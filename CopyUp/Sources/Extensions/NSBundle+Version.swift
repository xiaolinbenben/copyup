//
//  NSBundle+Version.swift
//
//  CopyUp
//  GitHub: https://github.com/xiaolinbenben/copyup
//  HP: https://copyup.beisi.tech
//
//  Created by Econa77 on 2016/03/29.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation

extension Bundle {
    var appVersion: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
}
