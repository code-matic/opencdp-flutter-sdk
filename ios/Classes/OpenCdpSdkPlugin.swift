import Flutter
import UIKit

public class OpenCdpSdkPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "open_cdp_sdk",
                                           binaryMessenger: registrar.messenger())
        let instance = OpenCdpSdkPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "opencdpsdk_save_api_key":
            guard let args = call.arguments as? [String: Any],
                  let apiKey = args["apiKey"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing apiKey argument", details: nil))
                return
            }
            let appGroup = args["appGroup"] as? String
            if let appGroup = appGroup, !appGroup.isEmpty {
                result(saveApiKeyToSharedStorage(apiKey: apiKey, appGroup: appGroup))
            } else {
                result(false)
            }

        case "opencdpsdk_save_user_id":
            guard let args = call.arguments as? [String: Any],
                  let userId = args["userId"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing userId argument", details: nil))
                return
            }
            let appGroup = args["appGroup"] as? String
            if let appGroup = appGroup, !appGroup.isEmpty {
                result(saveUserIdToSharedStorage(userId: userId, appGroup: appGroup))
            } else {
                result(false)
            }

        case "opencdpsdk_clear_api_key":
            guard let args = call.arguments as? [String: Any],
                  let appGroup = args["appGroup"] as? String else {
                result(false)
                return
            }
            result(clearApiKeyFromSharedStorage(appGroup: appGroup))

        case "opencdpsdk_clear_user_id":
            guard let args = call.arguments as? [String: Any],
                  let appGroup = args["appGroup"] as? String else {
                result(false)
                return
            }
            result(clearUserIdFromSharedStorage(appGroup: appGroup))

        case "opencdpsdk_get_api_key":
            guard let args = call.arguments as? [String: Any],
                  let appGroup = args["appGroup"] as? String else {
                result(nil)
                return
            }
            result(getApiKeyFromSharedStorage(appGroup: appGroup))

        case "opencdpsdk_get_user_id":
            guard let args = call.arguments as? [String: Any],
                  let appGroup = args["appGroup"] as? String else {
                result(nil)
                return
            }
            result(getUserIdFromSharedStorage(appGroup: appGroup))

        case "opencdpsdk_save_base_url":
            guard let args = call.arguments as? [String: Any],
                  let baseUrl = args["baseUrl"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing baseUrl argument", details: nil))
                return
            }
            let appGroup = args["appGroup"] as? String
            if let appGroup = appGroup, !appGroup.isEmpty {
                result(saveBaseUrlToSharedStorage(baseUrl: baseUrl, appGroup: appGroup))
            } else {
                result(false)
            }

        case "opencdpsdk_get_base_url":
            guard let args = call.arguments as? [String: Any],
                  let appGroup = args["appGroup"] as? String else {
                result(nil)
                return
            }
            result(getBaseUrlFromSharedStorage(appGroup: appGroup))

        case "opencdpsdk_clear_base_url":
            guard let args = call.arguments as? [String: Any],
                  let appGroup = args["appGroup"] as? String else {
                result(false)
                return
            }
            result(clearBaseUrlFromSharedStorage(appGroup: appGroup))

        default:
            result(FlutterMethodNotImplemented)
        }
    }  //  CLOSE handle()

    // MARK: - Shared Storage Helpers

    @discardableResult
    private func saveApiKeyToSharedStorage(apiKey: String, appGroup: String) -> Bool {
        if let userDefaults = UserDefaults(suiteName: appGroup) {
            userDefaults.set(apiKey, forKey: "opencdpsdk_api_key")
            return true
        }
        return false
    }

    @discardableResult
    private func saveUserIdToSharedStorage(userId: String, appGroup: String) -> Bool {
        if let userDefaults = UserDefaults(suiteName: appGroup) {
            userDefaults.set(userId, forKey: "opencdpsdk_user_id")
            return true
        }
        return false
    }

    @discardableResult
    private func clearApiKeyFromSharedStorage(appGroup: String) -> Bool {
        if let userDefaults = UserDefaults(suiteName: appGroup) {
            userDefaults.removeObject(forKey: "opencdpsdk_api_key")
            return true
        }
        return false
    }

    @discardableResult
    private func clearUserIdFromSharedStorage(appGroup: String) -> Bool {
        if let userDefaults = UserDefaults(suiteName: appGroup) {
            userDefaults.removeObject(forKey: "opencdpsdk_user_id")
            return true
        }
        return false
    }

    private func getApiKeyFromSharedStorage(appGroup: String) -> String? {
        if let userDefaults = UserDefaults(suiteName: appGroup) {
            return userDefaults.string(forKey: "opencdpsdk_api_key")
        }
        return nil
    }

    private func getUserIdFromSharedStorage(appGroup: String) -> String? {
        if let userDefaults = UserDefaults(suiteName: appGroup) {
            return userDefaults.string(forKey: "opencdpsdk_user_id")
        }
        return nil
    }

    @discardableResult
    private func saveBaseUrlToSharedStorage(baseUrl: String, appGroup: String) -> Bool {
        if let userDefaults = UserDefaults(suiteName: appGroup) {
            userDefaults.set(baseUrl, forKey: "opencdpsdk_base_url")
            return true
        }
        return false
    }

    @discardableResult
    private func clearBaseUrlFromSharedStorage(appGroup: String) -> Bool {
        if let userDefaults = UserDefaults(suiteName: appGroup) {
            userDefaults.removeObject(forKey: "opencdpsdk_base_url")
            return true
        }
        return false
    }

    private func getBaseUrlFromSharedStorage(appGroup: String) -> String? {
        if let userDefaults = UserDefaults(suiteName: appGroup) {
            return userDefaults.string(forKey: "opencdpsdk_base_url")
        }
        return nil
    }
} // CLOSE CLASS
