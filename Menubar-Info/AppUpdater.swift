//
//  AppUpdater.swift
//  Menubar-Info
//
//  Created by Pierre-Louis ML on 10/05/2025.
//

import Foundation
import AppKit

class AppUpdater {
    static let shared = AppUpdater()
    private let currentVersion: String
    private let repoURL = "https://api.github.com/repos/Thinkr1/Menubar-Info/releases/latest"
    private let skipVersionKey = "SkippedVersion"
    
    private init() {
        currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        print(currentVersion)
    }
    
    func checkForUpdates(force: Bool = false, completion: ((Bool) -> Void)? = nil) {
        guard let url = URL(string: repoURL) else {
            completion?(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Update check failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion?(false)
                }
                return
            }
            
            guard let data = data,
                  let release = try? JSONDecoder().decode(GitHubRelease.self, from: data) else {
                DispatchQueue.main.async {
                    completion?(false)
                }
                return
            }
            
            let skippedVersion = UserDefaults.standard.string(forKey: self.skipVersionKey)
            
            if self.isNewerVersion(release.tagName), (force || skippedVersion != release.tagName) {
                DispatchQueue.main.async {
                    self.showUpdateAlert(release: release)
                    completion?(true)
                }
            } else {
                DispatchQueue.main.async {
                    completion?(false)
                }
            }
        }
        
        task.resume()
    }
    
    private func isNewerVersion(_ version: String) -> Bool {
        let normalizedCurrent = currentVersion
            .replacingOccurrences(of: "^v", with: "", options: .regularExpression)
//            .replacingOccurrences(of: "\\.0+$", with: "", options: .regularExpression)
        
        let normalizedNew = version
            .replacingOccurrences(of: "^v", with: "", options: .regularExpression)
//            .replacingOccurrences(of: "\\.0+$", with: "", options: .regularExpression)
        
        if normalizedCurrent == normalizedNew {
            return false
        }
        
        let currentComponents = normalizedCurrent.components(separatedBy: ".")
        let newComponents = normalizedNew.components(separatedBy: ".")
        
        for i in 0..<max(currentComponents.count, newComponents.count) {
            let currentNum = i < currentComponents.count ? Int(currentComponents[i]) ?? 0 : 0
            let newNum = i < newComponents.count ? Int(newComponents[i]) ?? 0 : 0
            
            if newNum > currentNum {
                return true
            } else if newNum < currentNum {
                return false
            }
        }
        
        return false
    }
    
    private func showUpdateAlert(release: GitHubRelease) {
        let alert = NSAlert()
        alert.messageText = "New Version Available!"
        alert.informativeText = "Version \(release.tagName) is available. You're currently using \(currentVersion). Would you like to download and install it now?"
        
        alert.addButton(withTitle: "Download and Install")
        alert.addButton(withTitle: "Skip This Version")
        alert.addButton(withTitle: "Remind Me Later")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            downloadAndInstall(release: release)
        case .alertSecondButtonReturn:
            UserDefaults.standard.set(release.tagName, forKey: skipVersionKey)
        default:
            break
        }
    }
    
    private func downloadAndInstall(release: GitHubRelease) {
        guard let dmgAsset = release.assets.first(where: { $0.browserDownloadURL.hasSuffix(".dmg") }),
              let dmgURL = URL(string: dmgAsset.browserDownloadURL) else {
            showDownloadError()
            return
        }
        
        let downloadTask = URLSession.shared.downloadTask(with: dmgURL) { [weak self] tempURL, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Download failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.showDownloadError()
                }
                return
            }
            
            guard let tempURL = tempURL else {
                DispatchQueue.main.async {
                    self.showDownloadError()
                }
                return
            }
            
            do {
                let downloadsURL = try FileManager.default.url(
                    for: .downloadsDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
                
                let destinationURL = downloadsURL.appendingPathComponent(dmgAsset.name)
                
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                
                DispatchQueue.main.async {
                    self.installFromDMG(dmgURL: destinationURL)
                }
            } catch {
                print("File move failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.showDownloadError()
                }
            }
        }
        
        downloadTask.resume()
    }
    
    private func installFromDMG(dmgURL: URL) {
        let script = """
        do shell script "
            hdiutil attach '\(dmgURL.path)' -quiet &&
            VOLUME=$(hdiutil info | grep 'Menubar-Info' | awk -F'\\t' '{print $3}') &&
            if [ -n \"$VOLUME\" ]; then
                cp -R \"$VOLUME/Menubar-Info.app\" /Applications/ &&
                hdiutil detach \"$VOLUME\" -quiet &&
                open /Applications/Menubar-Info.app
            fi
        " with administrator privileges
        """
        
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            print("Installation failed: \(error)")
            showInstallError()
        }
    }
    
    private func showDownloadError() {
        let alert = NSAlert()
        alert.messageText = "Download Failed"
        alert.informativeText = "Could not download the update. Please try again later."
        alert.runModal()
    }
    
    private func showInstallError() {
        let alert = NSAlert()
        alert.messageText = "Installation Failed"
        alert.informativeText = "Could not install the update. Please try downloading it manually."
        alert.runModal()
    }
}

struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let body: String
    let assets: [Asset]
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case assets
    }
}

struct Asset: Codable {
    let name: String
    let browserDownloadURL: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}
