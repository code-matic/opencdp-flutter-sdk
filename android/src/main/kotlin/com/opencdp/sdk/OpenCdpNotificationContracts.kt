package com.opencdp.sdk

internal object OpenCdpNotificationContracts {
    const val PREFS_NAME = "open_cdp_sdk_prefs"
    const val API_KEY_KEY = "opencdpsdk_api_key"
    const val USER_ID_KEY = "opencdpsdk_user_id"
    const val BASE_URL_KEY = "opencdpsdk_base_url"

    const val DEFAULT_BASE_URL = "https://api.opencdp.io/gateway/data-gateway"
    const val DELIVERY_PATH = "/v1/message/delivery/push"

    const val ACTION_OPEN = "com.opencdp.sdk.ACTION_OPEN_NOTIFICATION"
    const val ACTION_CLICK = "com.opencdp.sdk.ACTION_CLICK_NOTIFICATION"

    const val EXTRA_PAYLOAD_JSON = "opencdp_payload_json"
    const val EXTRA_ACTION_ID = "opencdp_action_id"
    const val EXTRA_ACTION_LINK = "opencdp_action_link"
    const val EXTRA_NOTIFICATION_ID = "opencdp_notification_id"
}

