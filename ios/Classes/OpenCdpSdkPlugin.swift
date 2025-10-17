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
            
            // Get app group if provided
            let appGroup = args["appGroup"] as? String
            
            if let appGroup = appGroup, !appGroup.isEmpty {
                if saveApiKeyToSharedStorage(apiKey: apiKey, appGroup: appGroup) {
                    print("✅ API Key saved successfully to shared storage.")
                    result(true)
                } else {
                    result(FlutterError(code: "SAVE_FAILED", message: "Invalid App Group ID", details: nil))
                }
            } else {
                // No app group provided - might be running on Android
                print("⚠️ No app group provided, cannot save API key on iOS.")
                result(false)
            }
            
        case "opencdpsdk_save_user_id":
            guard let args = call.arguments as? [String: Any],
                  let userId = args["userId"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing userId argument", details: nil))
                return
            }
            
            // Get app group if provided
            let appGroup = args["appGroup"] as? String
            
            if let appGroup = appGroup, !appGroup.isEmpty {
                if saveUserIdToSharedStorage(userId: userId, appGroup: appGroup) {
                    print("✅ User ID saved successfully to shared storage.")
                    result(true)
                } else {
                    result(FlutterError(code: "SAVE_FAILED", message: "Invalid App Group ID", details: nil))
                }
            } else {
                // No app group provided - might be running on Android
                print("⚠️ No app group provided, cannot save user ID on iOS.")
                result(false)
            }
            
        case "opencdpsdk_clear_api_key":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
                return
            }
            
            // Get app group if provided
            let appGroup = args["appGroup"] as? String
            
            if let appGroup = appGroup, !appGroup.isEmpty {
                if clearApiKeyFromSharedStorage(appGroup: appGroup) {
                    print("✅ API Key cleared successfully from shared storage.")
                    result(true)
                } else {
                    result(FlutterError(code: "CLEAR_FAILED", message: "Invalid App Group ID", details: nil))
                }
            } else {
                // No app group provided - might be running on Android
                print("⚠️ No app group provided, cannot clear API key on iOS.")
                result(false)
            }
            
        case "opencdpsdk_clear_user_id":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
                return
            }
            
            // Get app group if provided
            let appGroup = args["appGroup"] as? String
            
            if let appGroup = appGroup, !appGroup.isEmpty {
                if clearUserIdFromSharedStorage(appGroup: appGroup) {
                    print("✅ User ID cleared successfully from shared storage.")
                    result(true)
                } else {
                    result(FlutterError(code: "CLEAR_FAILED", message: "Invalid App Group ID", details: nil))
                }
            } else {
                // No app group provided - might be running on Android
                print("⚠️ No app group provided, cannot clear user ID on iOS.")
                result(false)
            }
            
        case "opencdpsdk_get_api_key":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
                return
            }
            
            // Get app group if provided
            let appGroup = args["appGroup"] as? String
            
            if let appGroup = appGroup, !appGroup.isEmpty {
                let apiKey = getApiKeyFromSharedStorage(appGroup: appGroup)
                result(apiKey)
            } else {
                // No app group provided - might be running on Android
                print("⚠️ No app group provided, cannot get API key on iOS.")
                result(nil)
            }
            
        case "opencdpsdk_get_user_id":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
                return
            }
            
            // Get app group if provided
            let appGroup = args["appGroup"] as? String
            
            if let appGroup = appGroup, !appGroup.isEmpty {
                let userId = getUserIdFromSharedStorage(appGroup: appGroup)
                result(userId)
            } else {
                // No app group provided - might be running on Android
                print("⚠️ No app group provided, cannot get user ID on iOS.")
                result(nil)
            }

        default:
            result(FlutterMethodNotImplemented)
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
    private func saveUserIdToSharedStorage(userId: String, appGroup: String) -> Bool {
        if let userDefaults = UserDefaults(suiteName: appGroup) {
            userDefaults.set(userId, forKey: "opencdpsdk_user_id")
            return true
        } else {
            print("❌ Could not save User ID: Invalid App Group ID provided.")
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
    
    @discardableResult
    private func clearUserIdFromSharedStorage(appGroup: String) -> Bool {
        if let userDefaults = UserDefaults(suiteName: appGroup) {
            userDefaults.removeObject(forKey: "opencdpsdk_user_id")
            return true
        } else {
            print("❌ Could not clear User ID: Invalid App Group ID provided.")
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
    
    private func getUserIdFromSharedStorage(appGroup: String) -> String? {
        if let userDefaults = UserDefaults(suiteName: appGroup) {
            return userDefaults.string(forKey: "opencdpsdk_user_id")
        } else {
            print("❌ Could not read User ID: Invalid App Group ID provided.")
            return nil
        }
    }
}
