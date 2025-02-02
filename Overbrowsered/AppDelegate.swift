//
//  Created by https://keybase.io/bmisiak on 18.05.20.
//  Copyright © 2018 bmisiak. All rights reserved.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
	
	var menubarIcon: NSStatusItem?

	var mostRecentlyUsedBrowser: Bundle? {
		willSet(newAppBundle) {
			if mostRecentlyUsedBrowser != newAppBundle {
				if let bundle = newAppBundle {
					//the new value appears to be a valid app bundle, let's save it:
					UserDefaults.standard.set(bundle.bundleURL, forKey: "mostRecentBrowserBundleUrl")
				}
			}
		}
	}

	func applicationWillFinishLaunching(_ notification: Notification) {
		
		// Load the saved most recently used browser...
		let savedMostRecentBrowserBundleUrl = UserDefaults.standard.url(forKey: "mostRecentBrowserBundleUrl")
		
		if let url = savedMostRecentBrowserBundleUrl {
			self.mostRecentlyUsedBrowser = Bundle(url: url)
		}
		
		// It might be possible to use CF to fetch a list of apps which are already
		// running, sorted by the time of last use: https://gist.github.com/0xced/163918
		// The API is deprecated though.
		
		// If there's no valid saved browser, try using the one currently set as default:
		if self.mostRecentlyUsedBrowser == nil {
			if let defaultBrowserUrl = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!) {
				
				let defaultBrowserBundle = Bundle(url: defaultBrowserUrl)
				// But only if the default handler is not Overbrowsered.
				if defaultBrowserBundle != Bundle.main {
					self.mostRecentlyUsedBrowser = defaultBrowserBundle
				}
			}
		}
		
		// Let's let the OS know we want to handle http links. Note: this has to
		// happen before applicationDidFinishLaunching or a link clicked while the app
		// is closed won't be handled.
		
		//Registering the handler of http links, the official way:
		NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(self.handleHttpLink), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
		
		//Some apps use the alternative WWW!/OURL AppleEvent, so for compatibility:
		if let eventClass = AEEventClass("WWW!"), let eventId = AEEventID("OURL") {
			NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(self.handleHttpLink), forEventClass: eventClass, andEventID: eventId)
		}
	}
	
	func applicationDidFinishLaunching(_ aNotification: Notification) {
		
		self.menubarIcon = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
		self.menubarIcon?.button?.image = NSImage(named: "StatusBarButtonImage")
		
		let menu = NSMenu()
		menu.delegate = self
		self.menubarIcon?.menu = menu
		
		//Subscribing to app change events, to detect the most recently used browser:
		NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: nil, using: self.handleAppChangeNotification)
	}
	
	public func menuNeedsUpdate(_ menu: NSMenu) {
		menu.removeAllItems()
		
		menu.addItem(withTitle: "Overbrowsered by @bmisiak (modded by CC)", action: nil, keyEquivalent: "")
		menu.addItem(NSMenuItem.separator())
		
		menu.addItem(withTitle: "Most recently used browser: \(self.mostRecentlyUsedBrowser?.infoDictionary?["CFBundleName"] as? String ?? "Unknown (use any browser to detect)")", action: nil, keyEquivalent: "")
		
		//Detect the default handler status
		var defaultBrowserBundle: Bundle?
		if let url = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!) {
			defaultBrowserBundle = Bundle(url: url)
		}
		
		if defaultBrowserBundle == Bundle.main {
			menu.addItem(withTitle: "Default http handler: me 👌", action: nil, keyEquivalent: "")
		} else if defaultBrowserBundle?.bundleIdentifier == Bundle.main.bundleIdentifier {
			menu.addItem(withTitle: "Default http handler: Overbrowsered", action: nil, keyEquivalent: "")
		} else {
			let handlerName = defaultBrowserBundle?.infoDictionary?["CFBundleName"] as? String ?? defaultBrowserBundle?.bundleIdentifier
			
			menu.addItem(withTitle: "Default http handler: \(handlerName ?? "not me") ☹️", action: nil, keyEquivalent: "")
			menu.addItem(withTitle: "⚠️ For Overbrowsered to work, click here to set it as the default \"browser\".", action: #selector(self.menuBarSetDefault(_:)), keyEquivalent: "")
		}
		
		menu.addItem(NSMenuItem.separator())
		menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
	}
	
	// Try setting this app as the default handler for http(s), per user request:
	
	@objc func menuBarSetDefault(_ sender: Any?) {
		guard Bundle.main.bundlePath.starts(with: "/Applications/") else {
			let alert = NSAlert.init()
			alert.alertStyle = .informational
			alert.addButton(withTitle: "OK")
			alert.messageText = "Please move Overbrowsered to your Applications folder."
			alert.informativeText = "You will run into issues if you move Overbrowsered after setting it as the default browser. Please move it into Applications beforehand."
			alert.runModal()
			return
		}
		
		if let bundleId = Bundle.main.bundleIdentifier {
			LSSetDefaultHandlerForURLScheme("http" as CFString, bundleId as CFString)
			LSSetDefaultHandlerForURLScheme("https" as CFString, bundleId as CFString)
		}
	}
	
	// The user brought another app to the foreground, let's see if it's a browser:
	
	func handleAppChangeNotification(notification: Notification) {
		guard let appPassedInNotification = notification.userInfo?["NSWorkspaceApplicationKey"] as? NSRunningApplication else { return }
		guard let appBundleUrl = appPassedInNotification.bundleURL else { return }
		guard let appBundle = Bundle(url: appBundleUrl) else { return }
		
		if appBundle == Bundle.main {
			//Let's avoid detecting this app as a browser, which could cause an infinite loop of passing http links to itself
			return
		}
		
        
		let appIsABrowser =
			(appBundle.infoDictionary?["CFBundleURLTypes"] as? [[String:Any?]])?
			.map { urlType in urlType["CFBundleURLSchemes"] as? [String?] }
			.contains { schemes in
				schemes?.contains { scheme in scheme == "http" || scheme == "https" } ?? false
			}
			?? false

		let appName = "\(appBundle.infoDictionary?["CFBundleName"]! ?? "")".lowercased()




		if appIsABrowser
            && appName.compare("couch") != .orderedSame
            && appName.compare("couchdb") != .orderedSame
            && appName.compare("mattermost") != .orderedSame
            && appName.compare("iterm2") != .orderedSame
            && appName.compare("iterm") != .orderedSame
        {
			self.mostRecentlyUsedBrowser = appBundle
		}
	}
	
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
		if let browserBundleId = mostRecentlyUsedBrowser?.bundleIdentifier {
			NSWorkspace.shared.open(
				filenames.map { URL.init(fileURLWithPath: $0).standardized },
				withAppBundleIdentifier: browserBundleId,
				options: .default,
				additionalEventParamDescriptor: nil,
				launchIdentifiers: nil
			)
		}
	}
	
	@objc func handleHttpLink(getUrl: NSAppleEventDescriptor, withReplyEvent: NSAppleEventDescriptor) {
		
		guard let urlStr = getUrl.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else { return }
		guard let url = URL(string: urlStr) else { return }
		
		if let browserBundleId = mostRecentlyUsedBrowser?.bundleIdentifier {
			NSWorkspace.shared.open([url], withAppBundleIdentifier: browserBundleId, options: .default, additionalEventParamDescriptor: nil, launchIdentifiers: nil)
		} else {
			let alert = NSAlert.init()
			alert.alertStyle = .informational
			alert.addButton(withTitle: "OK")
			alert.messageText = "Overbrowsered has yet to see you use a browser."
			alert.informativeText = "Open a web browser and click its window, so I can know where to open this link:\n\n\(urlStr)"
			alert.runModal()
		}
	}

}
