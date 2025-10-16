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
                  let apiKey = args["apiKey"] as? String,
                  let appGroup = args["appGroup"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing or invalid arguments", details: nil))
                return
            }

            if saveApiKeyToSharedStorage(apiKey: apiKey, appGroup: appGroup) {
                print(" API Key saved successfully to shared storage.")
                result(true)
            } else {
                result(FlutterError(code: "SAVE_FAILED", message: "Invalid App Group ID", details: nil))
            }
            
        case "opencdpsdk_clear_api_key":
            guard let args = call.arguments as? [String: Any],
                  let appGroup = args["appGroup"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing appGroup argument", details: nil))
                return
            }
            
            if clearApiKeyFromSharedStorage(appGroup: appGroup) {
                print("API Key cleared successfully from shared storage.")
                result(true)
            } else {
                result(FlutterError(code: "CLEAR_FAILED", message: "Invalid App Group ID", details: nil))
            }
            
        case "opencdpsdk_get_api_key":
            guard let args = call.arguments as? [String: Any],
                  let appGroup = args["appGroup"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing appGroup argument", details: nil))
                return
            }
            
            let apiKey = getApiKeyFromSharedStorage(appGroup: appGroup)
            result(apiKey)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    @discardableResult
    private func saveApiKeyToSharedStorage(apiKey: String, appGroup: String) -> Bool {
        if let userDefaults = UserDefaults(suiteName: appGroup) {
            userDefaults.set(apiKey, forKey: "opencdpsdk_api_key")
            return true
        } else {
            print("❌ Could not save API Key: Invalid App Group ID provided.")
            return false
        }
    }
    
    @discardableResult
    private func clearApiKeyFromSharedStorage(appGroup: String) -> Bool {
        if let userDefaults = UserDefaults(suiteName: appGroup) {
            userDefaults.removeObject(forKey: "opencdpsdk_api_key")
            return true
        } else {
            print("❌ Could not clear API Key: Invalid App Group ID provided.")
            return false
        }
    }
    
    private func getApiKeyFromSharedStorage(appGroup: String) -> String? {
        if let userDefaults = UserDefaults(suiteName: appGroup) {
            return userDefaults.string(forKey: "opencdpsdk_api_key")
        } else {
            print("❌ Could not read API Key: Invalid App Group ID provided.")
            return nil
        }
    }
}
