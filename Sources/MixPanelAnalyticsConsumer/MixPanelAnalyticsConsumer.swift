//  TAAppsFlyerConsumer.swift
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

public class MixPanelAnalyticsConsumer: AnalyticsConsumer {
   
    public typealias T = MixPanelAnalyticsConsumer
    
    public var wrappedValue: Self {
        self
    }
    
    let mixPanelInstance: MixpanelInstance = Mixpanel.mainInstance()
    
    let sdkKey: String

    init(sdkKey: String) {
        self.sdkKey = sdkKey
    }
    
    public func startFor(installType: TAAnalyticsConfig.InstallType, userDefaults: UserDefaults, TAAnalytics: TAAnalytics) async throws {
        Mixpanel.initialize(token: sdkKey, trackAutomaticEvents: false)
    }

    public func track(trimmedEvent: EventAnalyticsModelTrimmed, params: [String: any AnalyticsBaseParameterValue]?) {
        
        let validParams = validEventParams(forEvent: trimmedEvent, params: params)
        
        mixPanelInstance.track(event: trimmedEvent.rawValue, properties: validParams)
    }
    
    private func validEventParams(forEvent event: EventAnalyticsModelTrimmed, params: [String: any AnalyticsBaseParameterValue]?) -> [String: MixpanelType]? {
        guard let params = params else { return nil }
        
        var newParams = [String: MixpanelType]()
        
        for (key, value) in params {
            var trimmedKey = key
            if trimmedKey.count > 40 {
                trimmedKey = String(trimmedKey.prefix(40))
                os_log(
                    "Trimmed key for event '%{public}@' from '%{public}@' to '%{public}@'",
                    log: TAAnalytics.logger,
                    type: .error,
                    event.rawValue,
                    key,
                    trimmedKey
                )
            }

            var convertedValue: MixpanelType

            if let str = value as? String {
                let trimmedStr = str.count > 100 ? String(str.prefix(100)) : str
                if trimmedStr != str {
                    os_log(
                        "Trimmed value for key '%{public}@' in event '%{public}@'",
                        log: TAAnalytics.logger,
                        type: .error,
                        trimmedKey,
                        event.rawValue
                    )
                }
                convertedValue = trimmedStr
            } else if let mixpanelValue = value as? MixpanelType {
                convertedValue = mixpanelValue
            } else {
                os_log(
                    "Unsupported parameter value for key '%{public}@' in event '%{public}@'. Skipping.",
                    log: TAAnalytics.logger,
                    type: .error,
                    trimmedKey
                )
                continue
            }

            newParams[trimmedKey] = convertedValue
        }
        return newParams
    }
    
    private func convert(parameter: any AnalyticsBaseParameterValue) -> MixpanelType {
        guard let parameter = parameter as? MixpanelType else {
            fatalError("Unsupported base parameter type \(parameter)")
        }
        return parameter
    }

    public func set(trimmedUserProperty: UserPropertyAnalyticsModelTrimmed, to value: String?) {
        guard let value = value else { return }
        mixPanelInstance.people.set(property: trimmedUserProperty.rawValue, to: value)
    }

    public func trim(event: EventAnalyticsModel) -> EventAnalyticsModelTrimmed {
        EventAnalyticsModelTrimmed(event.rawValue.ta_trim(toLength: 40, debugType: "event"))
    }
    
    public func trim(userProperty: UserPropertyAnalyticsModel) -> UserPropertyAnalyticsModelTrimmed {
        UserPropertyAnalyticsModelTrimmed(userProperty.rawValue.ta_trim(toLength: 24, debugType: "user property"))
    }
}

extension MixPanelAnalyticsConsumer: AnalyticsConsumerWithWriteOnlyUserID {
    
    public func set(userID: String?) {
        guard let userID = userID else { return }
        Mixpanel.mainInstance().identify(distinctId: userID)
    }
}
