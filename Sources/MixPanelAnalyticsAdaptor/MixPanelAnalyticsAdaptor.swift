//  TAAppsFlyerAdaptor.swift
//  Created by Adi on 10/24/22.
//
//  Copyright (c) 2022 TA SRL (http://TA.com/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.


import Foundation
import OSLog
import TAAnalytics
import Mixpanel

public class MixPanelAnalyticsAdaptor: AnalyticsAdaptor {
    public typealias T = MixpanelInstance
    
    private var mixPanelInstance: MixpanelInstance?
    
    private let enabledInstallTypes: [TAAnalyticsConfig.InstallType]
    private let sdkKey: String
    
    public init(enabledInstallTypes: [TAAnalyticsConfig.InstallType] = TAAnalyticsConfig.InstallType.allCases, sdkKey: String) {
        self.enabledInstallTypes = enabledInstallTypes
        self.sdkKey = sdkKey
    }
    
    public func startFor(installType: TAAnalyticsConfig.InstallType, userDefaults: UserDefaults, taAnalytics: TAAnalytics) async throws {
        guard self.enabledInstallTypes.contains(installType) else {
            throw InstallTypeError.invalidInstallType
        }
        
        // Set the instance AFTER initialization
        mixPanelInstance = Mixpanel.initialize(token: sdkKey, trackAutomaticEvents: false)
        
        if let flushInterval = taAnalytics.config.flushIntervalForAdaptors {
            mixPanelInstance?.flushInterval = flushInterval
        }
    }

    public func track(trimmedEvent: EventAnalyticsModelTrimmed, params: [String: any AnalyticsBaseParameterValue]?) {
        let validParams = validEventParams(forEvent: trimmedEvent, params: params)
        mixPanelInstance?.track(event: trimmedEvent.rawValue, properties: validParams)
    }
    
    private func validEventParams(forEvent event: EventAnalyticsModelTrimmed, params: [String: any AnalyticsBaseParameterValue]?) -> [String: MixpanelType]? {
        guard let params = params else { return nil }
        
        var newParams = [String: MixpanelType]()
        
        for (key, value) in params {
            var trimmedKey = key
            if trimmedKey.count > 255 {
                trimmedKey = String(trimmedKey.prefix(255))
                TAAnalyticsLogger.log("Trimmed key for event \(event.rawValue) from \(key) to \(trimmedKey)", level: .error)
            }

            var convertedValue: MixpanelType

            if let str = value as? String {
                let trimmedStr = str.count > 100 ? String(str.prefix(100)) : str
                if trimmedStr != str {
                    TAAnalyticsLogger.log(
                        "Trimmed value for key '\(trimmedKey)' in event '\(event.rawValue)'",
                        level: .error
                    )
                }
                convertedValue = trimmedStr
            } else if let mixpanelValue = value as? MixpanelType {
                convertedValue = mixpanelValue
            } else {
                TAAnalyticsLogger.log(
                    "Unsupported parameter value for key '\(trimmedKey)' in event '\(event.rawValue)'. Skipping.",
                    level: .error
                )
                continue
            }

            newParams[trimmedKey] = convertedValue
        }
        return newParams
    }
    
    public var wrappedValue: MixpanelInstance {
        // Return the stored instance, or fallback to mainInstance() if available
        return mixPanelInstance ?? Mixpanel.mainInstance()
    }

    public func set(trimmedUserProperty: UserPropertyAnalyticsModelTrimmed, to value: String?) {
        guard let value = value else { return }
        mixPanelInstance?.people.set(property: trimmedUserProperty.rawValue, to: value)
    }

    public func trim(event: EventAnalyticsModel) -> EventAnalyticsModelTrimmed {
        EventAnalyticsModelTrimmed(event.rawValue.ta_trim(toLength: 40, debugType: "event"))
    }
    
    public func trim(userProperty: UserPropertyAnalyticsModel) -> UserPropertyAnalyticsModelTrimmed {
        UserPropertyAnalyticsModelTrimmed(userProperty.rawValue.ta_trim(toLength: 24, debugType: "user property"))
    }
}

extension MixPanelAnalyticsAdaptor: AnalyticsAdaptorWithWriteOnlyUserID {
    public func set(userID: String?) {
        guard let userID = userID else { return }
        mixPanelInstance?.identify(distinctId: userID)
    }
}
